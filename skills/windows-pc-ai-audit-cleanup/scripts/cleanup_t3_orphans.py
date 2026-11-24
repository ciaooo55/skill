"""Reusable offline cleanup for Codex, AGY (T3-hosted), and orphaned T3 subagents
left behind after deleting conversations in T3 Code.

Safety guarantees:
1. Default mode is DRY-RUN (zero mutations). Requires explicit --execute to write.
2. Refuses to write if T3 Code, Codex, or AGY processes are running.
3. Dynamically reads T3's statev2.sqlite structural tables to classify active vs
   deleted threads (never matches free-text message bodies!).
4. Preserves all active T3 threads, active Codex/AGY sessions, native AGY
   subagents of active threads, standalone Codex/AGY sessions, and any unmatched
   non-empty AGY conversations (e.g. historical handoff segments).
5. Enforces SQLite PRAGMA foreign_keys=ON, defer_foreign_keys=ON,
   foreign_key_check, quick_check, wal_checkpoint(TRUNCATE), and atomic writes.
"""
from __future__ import annotations

import argparse
import contextlib
import csv
import io
import json
import os
from pathlib import Path
import re
import shutil
import sqlite3
import subprocess
import sys
import uuid


HOME = Path.home().resolve()
CODEX_ROOT = HOME / ".codex"
T3_ROOT = HOME / ".t3"
T3_UD = T3_ROOT / "userdata"
T3_DB = T3_UD / "statev2.sqlite"
AGY_T3_ROOTS = sorted((T3_UD / "providers" / "antigravity").glob("*/antigravity-acp"))

UUID_RE = re.compile(r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}", re.I)


def quote(name: str) -> str:
    return '"' + name.replace('"', '""') + '"'


def strip_win_prefix(path_str: str) -> str:
    if path_str.startswith("\\\\?\\UNC\\"):
        return "\\\\" + path_str[8:]
    if path_str.startswith("\\\\?\\"):
        return path_str[4:]
    return path_str


def safe_path(root: Path, target: Path | str) -> Path:
    root_r = Path(strip_win_prefix(str(root))).resolve()
    target_r = Path(strip_win_prefix(str(target))).resolve()
    if not target_r.is_relative_to(root_r):
        raise ValueError(f"Path escapes root: {target_r} not in {root_r}")
    return target_r


def is_link(path: Path) -> bool:
    return path.is_symlink() or (hasattr(path, "is_junction") and path.is_junction())


def dir_size_mb(p: Path) -> float:
    if not p.exists():
        return 0.0
    if p.is_file():
        return p.stat().st_size / (1024 * 1024)
    total = 0
    for r, _, files in os.walk(p):
        for f in files:
            try:
                total += (Path(r) / f).stat().st_size
            except OSError:
                pass
    return total / (1024 * 1024)


def atomic_write(file: Path, data: bytes | str) -> None:
    tmp = file.with_name(file.name + "." + uuid.uuid4().hex + ".tmp")
    try:
        tmp.write_bytes(data.encode("utf-8") if isinstance(data, str) else data)
        os.replace(tmp, file)
    finally:
        tmp.unlink(missing_ok=True)


def protobuf_fields(data: bytes):
    fields = []
    index = 0

    def varint() -> int:
        nonlocal index
        number = shift = 0
        while index < len(data) and shift < 70:
            byte = data[index]
            index += 1
            number |= (byte & 127) << shift
            if not byte & 128:
                return number
            shift += 7
        raise ValueError("Invalid protobuf varint")

    while index < len(data):
        start = index
        tag = varint()
        field, wire = tag >> 3, tag & 7
        if not field:
            raise ValueError("Invalid protobuf field")
        if wire == 0:
            value = varint()
        elif wire in (1, 5):
            size = 8 if wire == 1 else 4
            value = data[index : index + size]
            index += size
        elif wire == 2:
            size = varint()
            value = data[index : index + size]
            index += size
            if len(value) != size:
                raise ValueError("Truncated protobuf bytes")
        else:
            raise ValueError(f"Unknown wire type {wire}")
        fields.append((field, value, data[start:index]))
    return fields


def pb_field_value(data: bytes, number: int, default: bytes = b"") -> bytes:
    return next((v for f, v, _ in protobuf_fields(data) if f == number), default)


def running_blocking_processes() -> list[tuple[str, str]]:
    result = subprocess.run(
        ["tasklist", "/FO", "CSV", "/NH"],
        capture_output=True,
        text=True,
        timeout=15,
        errors="replace",
    )
    if result.returncode != 0:
        raise RuntimeError("Unable to inspect running processes via tasklist.")
    blocked = []
    for row in csv.reader(io.StringIO(result.stdout)):
        if len(row) < 2:
            continue
        name, pid = row[0], row[1]
        low = name.lower()
        if (
            low.startswith("t3 code")
            or low in (
                "t3.exe",
                "t3-resource-monitor.exe",
                "codex.exe",
                "codex-code-mode-host.exe",
                "agy.exe",
                "antigravity.exe",
            )
        ):
            blocked.append((name, pid))
    return blocked


@contextlib.contextmanager
def open_db(file: Path, writable: bool):
    conn = sqlite3.connect(
        str(file) if writable else file.resolve().as_uri() + "?mode=ro",
        uri=not writable,
        timeout=10,
    )
    conn.row_factory = sqlite3.Row
    try:
        yield conn
    finally:
        conn.close()


def get_schema(db: sqlite3.Connection) -> dict[str, list[str]]:
    tables = [
        r[0]
        for r in db.execute(
            "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'"
        )
    ]
    return {t: [c[1] for c in db.execute(f"PRAGMA table_info({quote(t)})")] for t in tables}


def discover_targets() -> dict:
    """Inspect T3 statev2.sqlite + Codex + T3-hosted AGY to compute exact safe cleanup targets."""
    if not T3_DB.exists():
        raise FileNotFoundError(f"T3 database not found: {T3_DB}")

    threads: dict[str, dict] = {}
    parent_of: dict[str, str] = {}
    native_map: dict[str, list[tuple[str, str, str]]] = {}
    active_cwds: set[str] = set()
    deleted_cwds: set[str] = set()

    with open_db(T3_DB, writable=False) as db:
        for r in db.execute('SELECT * FROM "orchestration_v2_projection_threads"'):
            d = dict(r)
            pj = json.loads(d["payload_json"]) if d.get("payload_json") else {}
            d["_pj"] = pj
            tid = d["thread_id"]
            threads[tid] = d
            par = pj.get("parentThreadId") or pj.get("parent_thread_id")
            if par:
                parent_of[tid] = par

        for r in db.execute('SELECT * FROM "orchestration_v2_projection_subagents"'):
            d = dict(r)
            ch = d.get("child_thread_id") or d.get("subagent_thread_id")
            par = d.get("parent_thread_id") or d.get("thread_id")
            if ch and par:
                parent_of[ch] = par

        def root_status(tid: str) -> str:
            cur, seen = tid, set()
            while cur and cur not in seen:
                seen.add(cur)
                t = threads.get(cur)
                if not t:
                    return "ORPHAN"
                if t.get("deleted_at"):
                    return "DELETED"
                par = parent_of.get(cur)
                if not par:
                    return "ACTIVE"
                cur = par
            return "ACTIVE"

        active_tids: set[str] = set()
        orphan_active_subagents: list[tuple[str, str]] = []
        for tid, d in threads.items():
            st = root_status(tid)
            d["_eff"] = st
            if st == "ACTIVE":
                active_tids.add(tid)
            elif not d.get("deleted_at"):
                orphan_active_subagents.append((tid, d.get("title") or ""))

        def record(val, tid: str):
            if not val or not tid:
                return
            st = threads[tid]["_eff"] if tid in threads else "DELETED"
            title = threads[tid].get("title") or "" if tid in threads else ""
            for u in UUID_RE.findall(str(val)):
                ul = u.lower()
                if ul == tid.lower():
                    continue
                native_map.setdefault(ul, []).append((tid, st, title))

        for tbl in ("orchestration_v2_projection_provider_threads", "orchestration_v2_projection_provider_sessions"):
            for r in db.execute(f'SELECT * FROM "{tbl}"'):
                d = dict(r)
                tid = d["thread_id"]
                record(d.get("provider_thread_id"), tid)
                record(d.get("provider_session_id"), tid)
                if d.get("payload_json"):
                    pj = json.loads(d["payload_json"])
                    cwd = pj.get("cwd")
                    if isinstance(cwd, str) and cwd:
                        if tid in active_tids:
                            active_cwds.add(cwd.lower())
                        else:
                            deleted_cwds.add(cwd.lower())

                    def pull(o):
                        if isinstance(o, dict):
                            for k, v in o.items():
                                if any(w in k.lower() for w in ("thread", "session", "conversation", "cursor", "native", "external", "remote", "cascade", "id")):
                                    if isinstance(v, str):
                                        record(v, tid)
                                    elif isinstance(v, dict):
                                        pull(v)
                                elif isinstance(v, (dict, list)):
                                    pull(v)
                        elif isinstance(o, list):
                            for x in o:
                                pull(x)

                    pull(pj)

        ev_types = [
            r[0]
            for r in db.execute("SELECT DISTINCT event_type FROM orchestration_events")
            if any(w in r[0].lower() for w in ("session", "provider", "runtime", "handoff"))
        ]
        if ev_types:
            q = f'SELECT stream_id, payload_json FROM orchestration_events WHERE event_type IN ({",".join("?" for _ in ev_types)})'
            for r in db.execute(q, ev_types):
                tid, raw = r[0], r[1]
                if not raw:
                    continue
                try:
                    pj = json.loads(raw)
                except Exception:
                    continue

                def pull_ev(o):
                    if isinstance(o, dict):
                        for k, v in o.items():
                            kl = k.lower()
                            if kl in ("text", "message", "content", "prompt", "summary", "body", "markdown", "delta", "output", "stderr", "stdout"):
                                continue
                            if any(w in kl for w in ("conversation", "session", "cursor", "native", "providerthread", "codex", "remote", "cascade")):
                                if isinstance(v, str):
                                    record(v, tid)
                                elif isinstance(v, dict):
                                    pull_ev(v)
                            elif isinstance(v, (dict, list)):
                                pull_ev(v)
                    elif isinstance(o, list):
                        for x in o[:30]:
                            if isinstance(x, dict):
                                pull_ev(x)

                pull_ev(pj)

    codex_targets: list[tuple[str, str, float]] = []
    codex_keep_count = 0
    state_files = sorted(CODEX_ROOT.glob("state_*.sqlite"))
    if state_files:
        with open_db(state_files[-1], writable=False) as cdb:
            for r in cdb.execute("SELECT id, title, rollout_path FROM threads"):
                cid = r["id"].lower()
                title = (r["title"] or "").replace("\n", " ")[:60]
                rp = r["rollout_path"] or ""
                sz = dir_size_mb(Path(strip_win_prefix(rp))) if rp else 0.0
                refs = native_map.get(cid, [])
                m = re.search(r'T3 thread "([^"]+)"', r["title"] or "")
                t3_tid = m.group(1) if m else None
                is_active = any(x[1] == "ACTIVE" for x in refs) or (t3_tid in active_tids if t3_tid else False)
                is_deleted = (any(x[1] != "ACTIVE" for x in refs) or (t3_tid is not None and t3_tid not in active_tids)) and not is_active
                if is_deleted:
                    codex_targets.append((cid, title, sz))
                else:
                    codex_keep_count += 1

    agy_plan: dict[Path, dict] = {}
    for agy_root in AGY_T3_ROOTS:
        sdb = agy_root / "conversation_summaries.db"
        rows: dict[str, dict] = {}
        par_map: dict[str, str] = {}
        if sdb.exists():
            with open_db(sdb, writable=False) as db:
                for r in db.execute("SELECT * FROM conversation_summaries"):
                    d = dict(r)
                    cid = d["conversation_id"].lower()
                    rows[cid] = d
                    if d.get("parent_conversation_id"):
                        par_map[cid] = d["parent_conversation_id"].lower()

        all_ids = set(rows.keys())
        if (agy_root / "conversations").is_dir():
            for f in (agy_root / "conversations").glob("*.db"):
                all_ids.add(f.stem.lower())
        for sub in ("brain", "annotations", "attachments"):
            if (agy_root / sub).is_dir():
                for f in (agy_root / sub).iterdir():
                    nm = (f.stem if f.is_file() else f.name).lower()
                    if UUID_RE.fullmatch(nm):
                        all_ids.add(nm)

        act_direct = {
            cid for cid in all_ids
            if any(x[1] == "ACTIVE" for x in native_map.get(cid, []))
        }
        del_direct = {
            cid for cid in all_ids
            if cid not in act_direct and any(x[1] != "ACTIVE" for x in native_map.get(cid, []))
        }

        def root_of(cid: str) -> str:
            cur, seen = cid, set()
            while cur in par_map and par_map[cur] and cur not in seen:
                seen.add(cur)
                cur = par_map[cur]
            return cur

        del_targets: list[tuple[str, str, str, float]] = []
        keep_count = 0
        for cid in sorted(all_ids):
            root = root_of(cid)
            r = rows.get(cid, {})
            steps = r.get("step_count")
            title = (r.get("title") or "").replace("\n", " ")[:55]
            sz = (
                dir_size_mb(agy_root / "conversations" / f"{cid}.db")
                + dir_size_mb(agy_root / "conversations" / f"{cid}.db-wal")
                + dir_size_mb(agy_root / "brain" / cid)
                + dir_size_mb(agy_root / "annotations" / cid)
                + dir_size_mb(agy_root / "attachments" / cid)
            )
            if cid in act_direct or root in act_direct:
                keep_count += 1
            elif cid in del_direct or root in del_direct:
                del_targets.append((cid, "DELETED_T3", title, sz))
            elif steps == 0 and not title:
                del_targets.append((cid, "EMPTY_STUB", (r.get("workspace_uris") or "")[:55], sz))
            else:
                # Conservatively preserve unmatched non-empty sessions (e.g., historical handoffs)
                keep_count += 1

        agy_plan[agy_root] = {"keep_count": keep_count, "targets": del_targets}

    dead_scratches: list[Path] = []
    if (T3_ROOT / "scratch").is_dir():
        for d in sorted((T3_ROOT / "scratch").iterdir()):
            if not d.is_dir():
                continue
            dl = str(d).lower()
            if dl in deleted_cwds and dl not in active_cwds:
                dead_scratches.append(d)

    return {
        "codex_keep_count": codex_keep_count,
        "codex_targets": codex_targets,
        "agy_plan": agy_plan,
        "t3_orphan_subagents": orphan_active_subagents,
        "dead_scratches": dead_scratches,
    }


def delete_from_sqlite(file: Path, ids: list[str], kind: str, dry_run: bool) -> dict[str, int]:
    if not file.exists() or not ids:
        return {}
    counts: dict[str, int] = {}
    with open_db(file, writable=not dry_run) as db:
        tables = get_schema(db)
        if not dry_run:
            db.executescript("PRAGMA foreign_keys=ON; PRAGMA defer_foreign_keys=ON; PRAGMA secure_delete=ON; BEGIN IMMEDIATE;")
        try:
            for table, cols in tables.items():
                if "message_search" in table or table.startswith("conversations_fts_"):
                    continue
                if kind == "agy":
                    targets = [c for c in ("conversation_id",) if c in cols]
                    if table == "conversation_parents":
                        targets = [c for c in ("conversation_id", "parent_id") if c in cols]
                else:
                    targets = [c for c in ("thread_id", "source_thread_id", "target_thread_id", "child_thread_id") if c in cols]
                    if table == "threads" and "id" in cols:
                        targets = ["id"]
                    elif table == "orchestration_events" and "stream_id" in cols:
                        targets = ["stream_id"]
                    elif table == "orchestration_command_receipts" and "aggregate_id" in cols:
                        targets = ["aggregate_id"]
                    elif table == "thread_spawn_edges":
                        targets = [c for c in ("parent_thread_id", "child_thread_id") if c in cols]
                    elif table == "session_model_ids" and "session_id" in cols:
                        targets = ["session_id"]
                if not targets:
                    continue
                placeholders = ",".join("?" for _ in ids)
                where = " OR ".join(f"{quote(c)} IN ({placeholders})" for c in targets)
                params = ids * len(targets)
                if kind == "t3" and table == "orchestration_v2_projection_provider_sessions" and "orchestration_v2_projection_provider_threads" in tables:
                    where = (
                        f"({where}) AND NOT EXISTS ("
                        f"SELECT 1 FROM orchestration_v2_projection_provider_threads p "
                        f"WHERE p.provider_session_id = orchestration_v2_projection_provider_sessions.provider_session_id "
                        f"AND p.thread_id NOT IN ({placeholders}))"
                    )
                    params = params + ids
                cnt = db.execute(f"SELECT count(*) FROM {quote(table)} WHERE {where}", params).fetchone()[0]
                if cnt:
                    counts[table] = cnt
                    if not dry_run:
                        db.execute(f"DELETE FROM {quote(table)} WHERE {where}", params)
            if not dry_run:
                db.commit()
                fk = db.execute("PRAGMA foreign_key_check").fetchall()
                if fk:
                    raise RuntimeError(f"Foreign key check failed on {file}: {fk[:5]}")
                qc = db.execute("PRAGMA quick_check").fetchone()[0]
                if qc != "ok":
                    raise RuntimeError(f"Quick check failed on {file}: {qc}")
                db.execute("PRAGMA wal_checkpoint(TRUNCATE)")
        except Exception:
            if not dry_run:
                db.rollback()
            raise
    return counts


def patch_jsonl(file: Path, ids: set[str], dry_run: bool) -> int:
    if not file.exists():
        return 0
    raw = file.read_text(encoding="utf-8")
    lines = raw.split("\n")
    kept = []
    removed = 0
    for line in lines:
        try:
            obj = json.loads(line) if line.strip() else {}
        except ValueError:
            obj = {}
        if isinstance(obj, dict) and any((obj.get(k) or "").lower() in ids for k in ("id", "session_id", "thread_id")):
            removed += 1
        else:
            kept.append(line)
    if removed and not dry_run:
        atomic_write(file, "\n".join(kept))
    return removed


def patch_pb_summaries(file: Path, ids: set[str], dry_run: bool) -> int:
    if not file.exists():
        return 0
    before = file.read_bytes()
    kept_chunks = []
    removed = 0
    for field, value, raw in protobuf_fields(before):
        if field == 1 and isinstance(value, bytes):
            cid = pb_field_value(value, 1).decode("utf-8", errors="replace").lower()
            if cid in ids:
                removed += 1
                continue
        kept_chunks.append(raw)
    if removed and not dry_run:
        atomic_write(file, b"".join(kept_chunks))
    return removed


def remove_path(root: Path, target: Path, dry_run: bool) -> bool:
    if not target.exists() and not target.is_symlink():
        return False
    safe = safe_path(root, target)
    if is_link(safe):
        raise ValueError(f"Refusing to remove symlink/junction: {safe}")
    if not dry_run:
        if safe.is_dir():
            shutil.rmtree(safe)
        else:
            safe.unlink()
    return True


def clean_codex(ids: list[str], dry_run: bool) -> None:
    print(f"\n=== 1. Codex ({CODEX_ROOT}) ===")
    if not ids:
        print("  Nothing to clean.")
        return
    id_set = {x.lower() for x in ids}
    rollouts: list[Path] = []
    state_files = sorted(CODEX_ROOT.glob("state_*.sqlite"))
    if state_files:
        with open_db(state_files[-1], writable=False) as db:
            owners: dict[Path, set[str]] = {}
            for tid, rp in db.execute("SELECT id, rollout_path FROM threads WHERE rollout_path IS NOT NULL AND rollout_path != ''"):
                p = Path(strip_win_prefix(rp)).resolve()
                owners.setdefault(p, set()).add(tid.lower())
            for tid in id_set:
                row = db.execute("SELECT rollout_path FROM threads WHERE lower(id)=?", (tid,)).fetchone()
                if row and row[0]:
                    p = safe_path(CODEX_ROOT, row[0])
                    if not any(p.is_relative_to((CODEX_ROOT / f).resolve()) for f in ("sessions", "archived_sessions")):
                        raise ValueError(f"Unexpected rollout path: {p}")
                    if owners.get(p, set()) - id_set:
                        raise ValueError(f"Rollout shared with kept thread: {p}")
                    if p.exists() and p not in rollouts:
                        rollouts.append(p)
    for folder in ("sessions", "archived_sessions"):
        if (CODEX_ROOT / folder).is_dir():
            for f in (CODEX_ROOT / folder).rglob("*.jsonl"):
                if any(f.name.lower().endswith(cid + ".jsonl") for cid in id_set):
                    rf = f.resolve()
                    if rf not in rollouts:
                        rollouts.append(rf)

    for sq in sorted(CODEX_ROOT.glob("*.sqlite")):
        counts = delete_from_sqlite(sq, ids, "codex", dry_run)
        if counts:
            print(f"  DB {sq.name}: {counts}")
    for name in ("session_index.jsonl", "history.jsonl"):
        removed = patch_jsonl(CODEX_ROOT / name, id_set, dry_run)
        if removed:
            print(f"  JSONL {name}: removed {removed} line(s)")
    extra_markers = 0
    for sub in ("tui-thread-reference-capabilities", "thread-writer-locks"):
        p = CODEX_ROOT / sub
        if p.is_dir():
            for f in p.iterdir():
                if f.stem.lower() in id_set and remove_path(CODEX_ROOT, f, dry_run):
                    extra_markers += 1
    removed_files = sum(1 for r in rollouts if remove_path(CODEX_ROOT, r, dry_run))
    print(f"  Rollout files: {removed_files} | Marker/lock files: {extra_markers}")


def clean_agy(agy_root: Path, ids: list[str], dry_run: bool) -> None:
    print(f"\n=== 2. AGY ({agy_root}) ===")
    if not ids:
        print("  Nothing to clean.")
        return
    id_set = {x.lower() for x in ids}
    counts = delete_from_sqlite(agy_root / "conversation_summaries.db", ids, "agy", dry_run)
    if counts:
        print(f"  DB conversation_summaries.db: {counts}")
    for pb_name in ("jetbox_summaries_proto.pb", "agyhub_summaries_proto.pb"):
        removed = patch_pb_summaries(agy_root / pb_name, id_set, dry_run)
        if removed:
            print(f"  Cache {pb_name}: removed {removed} entry(ies)")
    file_count = 0
    for cid in ids:
        for suf in ("", "-wal", "-shm"):
            if remove_path(agy_root, agy_root / "conversations" / f"{cid}.db{suf}", dry_run):
                file_count += 1
        for folder in ("brain", "annotations", "attachments"):
            if remove_path(agy_root, agy_root / folder / cid, dry_run):
                file_count += 1
        if remove_path(agy_root, agy_root / "annotations" / f"{cid}.pbtxt", dry_run):
            file_count += 1
    print(f"  Files/dirs removed: {file_count}")


def clean_t3_orphans(ids: list[str], dead_scratches: list[Path], dry_run: bool) -> None:
    print(f"\n=== 3. T3 Orphaned Subagents & Dead Scratch ({T3_UD}) ===")
    if ids:
        counts = delete_from_sqlite(T3_DB, ids, "t3", dry_run)
        print(f"  DB statev2.sqlite: {counts or 'nothing to remove'}")
    else:
        print("  DB statev2.sqlite: 0 orphaned subagents")
    removed_sc = sum(1 for d in dead_scratches if remove_path(T3_ROOT / "scratch", d, dry_run))
    print(f"  Dead scratch dirs removed: {removed_sc}")


def main() -> int:
    parser = argparse.ArgumentParser(description="Safely clean orphaned Codex/AGY/T3 records for deleted T3 threads.")
    parser.add_argument("--execute", action="store_true", help="Actually perform deletion (default is dry-run).")
    args = parser.parse_args()
    dry_run = not args.execute

    if not T3_DB.exists():
        print(f"T3 Code database not found ({T3_DB}). T3 Code is not installed or has no data on this PC — nothing to do.")
        return 0

    print("Mode:", "DRY-RUN (preview only, nothing modified)" if dry_run else "EXECUTE (cleaning orphaned records)")
    if not dry_run:
        blocked = running_blocking_processes()
        if blocked:
            print("\n[BLOCKED] Blocking processes are still running. Exit T3 Code / Codex / AGY completely first:")
            for name, pid in blocked:
                print(f"  - {name} (PID {pid})")
            return 2

    plan = discover_targets()
    print("\nPlan summary:")
    print(f"  Codex: keep={plan['codex_keep_count']}, clean={len(plan['codex_targets'])} ({sum(x[2] for x in plan['codex_targets']):.2f} MB)")
    for cid, title, sz in plan["codex_targets"]:
        print(f"    - [Codex] {cid} | {sz:.2f} MB | {title}")

    for agy_root, info in plan["agy_plan"].items():
        targets = info["targets"]
        print(f"  AGY ({agy_root.parent.name[:12]}...): keep={info['keep_count']}, clean={len(targets)} ({sum(x[3] for x in targets):.2f} MB)")
        for cid, kind, title, sz in targets:
            print(f"    - [AGY:{kind}] {cid} | {sz:.2f} MB | {title}")

    print(f"  T3 orphan subagents: {len(plan['t3_orphan_subagents'])}")
    for tid, title in plan["t3_orphan_subagents"]:
        print(f"    - [T3-ORPHAN] {tid[:48]}... | {title}")

    print(f"  T3 dead scratch folders: {len(plan['dead_scratches'])}")
    for d in plan["dead_scratches"]:
        print(f"    - [SCRATCH] {d.name}")

    clean_codex([x[0] for x in plan["codex_targets"]], dry_run)
    for agy_root, info in plan["agy_plan"].items():
        clean_agy(agy_root, [x[0] for x in info["targets"]], dry_run)
    clean_t3_orphans([x[0] for x in plan["t3_orphan_subagents"]], plan["dead_scratches"], dry_run)

    print("\n" + ("Dry-run complete! Exit T3 Code and re-run with --execute." if dry_run else "Cleanup complete and SQLite integrity verified!"))
    return 0


if __name__ == "__main__":
    if sys.stdout:
        sys.stdout.reconfigure(encoding="utf-8")
    raise SystemExit(main())
