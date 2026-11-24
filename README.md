# skill

面向多平台 AI Coding Agent 的个人/通用 **Skills 集合仓库**（标准 `skills/<skill-name>/SKILL.md` 结构）。

一次维护，多端共用：通过目录联接（Windows Junction）或软链接（macOS / Linux Symlink），即可同时接入 **Codex、Antigravity (AGY)、T3 Code、Claude Code、DeepSeek Harness、Cursor、Windsurf** 等主流 AI 工具，拉取更新即全端同步生效。

---

## Skills 目录

| # | Skill 名称 | 简介与适用场景 | 入口文档 |
|---|---|---|---|
| 1 | [`windows-pc-ai-audit-cleanup`](./skills/windows-pc-ai-audit-cleanup/) | **通用 Windows 电脑整理 & AI（MCP / Skills）单套共用治理**。支持**整套清理**，也支持**单独只整理 MCP 工具和 Skills**（只留一套本体，通过目录联接或复制同步让本机全部 AI 软件共用，并支持多台电脑复用，不写死任何路径）。 | [SKILL.md](./skills/windows-pc-ai-audit-cleanup/SKILL.md) |
| 2 | *（后续扩展占位）* | 新增 Skill 直接放入 `skills/<new-skill-name>/SKILL.md` 并在本表补充说明即可，一键安装脚本会自动识别。 | — |

---

## Skill 详解

### 1. [`windows-pc-ai-audit-cleanup`](./skills/windows-pc-ai-audit-cleanup/SKILL.md)

**做什么的**：一套灵活、强健、安全的通用 Windows 整理与 AI 治理工作流，**不死板、不写死盘符或路径**，既能**单独使用**也能**整套使用**：
- **模式一（单独使用：只整理 MCP + Skills）**：跳过系统清理，专攻把散落各处的 MCP 工具和 Skills 收拢成**唯一一套本体**，按用户自选位置与方式（目录联接“快捷方式”或纯实体复制）同步给电脑上所有已装的 AI 软件共用，也方便多台电脑拉取复用。
- **模式二（整套使用：全机体检 + 清理 + 环境 + AI）**：覆盖 C 盘瘦身、僵尸服务/注册表/搜索索引/虚拟内存/电源与 Wi-Fi、多语言开发环境与本地 AI 模型权重、深层绿色软件与重复项三分法治理、未知软件零瞎猜确认、重启后真实环境验收。
- **模式三（其它按需单项）**：只救 C 盘空间 / 只理开发环境 / 只清 T3↔Codex↔AGY 离线对话残留。

**核心特性**：
- **7 条安全铁律**：先只读体检后动手；绝不私自改动 Defender/防火墙/虚拟化/浏览器登录态/聊天记录；绝不打印原始密钥与 Token；绝不在线修改运行中的 SQLite/缓存；创建任何链接前先用大白话说明利弊由用户选择；绝不凭猜测删除陌生软件或私有隔离运行时。
- **内置可复用资源**：
  - 分阶段手册：[`references/`](./skills/windows-pc-ai-audit-cleanup/references/)（共 5 份，按需渐进加载，不浪费上下文）
  - 只读高速体检脚本：[`scripts/audit_pc_readonly.ps1`](./skills/windows-pc-ai-audit-cleanup/scripts/audit_pc_readonly.ps1)（兼容 Windows PowerShell 5.1 与 PowerShell 7，支持 `-Mode Full | AiOnly | DiskOnly` 按需快扫，防卡死）
  - 可选离线清理脚本：[`scripts/cleanup_t3_orphans.py`](./skills/windows-pc-ai-audit-cleanup/scripts/cleanup_t3_orphans.py)（默认 `--dry-run`，带进程锁与 SQLite 完整性校验；未装 T3 Code 自动跳过）

---

## 快速安装与软链接（推荐单一真相源）

推荐将本仓库克隆到一个固定目录，再通过**软链接 / 目录联接**挂到各个 AI 客户端的全局 Skills 目录。以后只需在仓库目录执行 `git pull`，所有客户端自动同步最新版，无需重复拷贝。

### 方式一：Windows 一键自动建目录联接（推荐，无需管理员权限）

```powershell
git clone https://github.com/ciaooo55/skill.git D:\skill
cd D:\skill

# 默认链接到 ~/.agents/skills (Codex / DeepSeek Harness) 与 ~/.gemini/config/skills (Antigravity / T3 AGY)
.\install-windows.ps1

# 如同时使用 Claude Code 或 Cursor，可指定目标客户端：
.\install-windows.ps1 -Targets agents,gemini,claude,cursor

# 如只安装某一个 Skill：
.\install-windows.ps1 -Skills windows-pc-ai-audit-cleanup

# 卸载所有由本仓库创建的联接（不会删除仓库源文件）：
.\install-windows.ps1 -Uninstall
```

### 方式二：手动创建软链接 / 目录联接

#### Windows（CMD，目录联接 Junction，无需管理员权限）
将 `<REPO_DIR>` 替换为你克隆本仓库的路径（例如 `D:\skill`）：

```cmd
:: 1. 通用标准目录（Codex / DeepSeek Harness 自动发现）
mkdir "%USERPROFILE%\.agents\skills" 2>nul
mklink /J "%USERPROFILE%\.agents\skills\windows-pc-ai-audit-cleanup" "<REPO_DIR>\skills\windows-pc-ai-audit-cleanup"

:: 2. Antigravity (AGY) / T3 Code 内置 AGY
mkdir "%USERPROFILE%\.gemini\config\skills" 2>nul
mklink /J "%USERPROFILE%\.gemini\config\skills\windows-pc-ai-audit-cleanup" "<REPO_DIR>\skills\windows-pc-ai-audit-cleanup"

:: 3. Claude Code（按需）
mkdir "%USERPROFILE%\.claude\skills" 2>nul
mklink /J "%USERPROFILE%\.claude\skills\windows-pc-ai-audit-cleanup" "<REPO_DIR>\skills\windows-pc-ai-audit-cleanup"

:: 4. Cursor（按需）
mkdir "%USERPROFILE%\.cursor\skills" 2>nul
mklink /J "%USERPROFILE%\.cursor\skills\windows-pc-ai-audit-cleanup" "<REPO_DIR>\skills\windows-pc-ai-audit-cleanup"
```

> 提示：Windows 删除目录联接时请使用 `rmdir "<联接路径>"`，不要直接递归删除目标内容。

#### Windows（PowerShell）
```powershell
$repo = "D:\skill"
$skill = "windows-pc-ai-audit-cleanup"
New-Item -ItemType Directory -Force "$env:USERPROFILE\.agents\skills" | Out-Null
New-Item -ItemType Junction -Path "$env:USERPROFILE\.agents\skills\$skill" -Target "$repo\skills\$skill"
```

#### macOS / Linux（标准软链接 `ln -s`）
```bash
git clone https://github.com/ciaooo55/skill.git ~/skill
mkdir -p ~/.agents/skills ~/.gemini/config/skills ~/.claude/skills
ln -s ~/skill/skills/windows-pc-ai-audit-cleanup ~/.agents/skills/windows-pc-ai-audit-cleanup
ln -s ~/skill/skills/windows-pc-ai-audit-cleanup ~/.gemini/config/skills/windows-pc-ai-audit-cleanup
```

### 方式三：使用 Skills CLI 直接安装

```bash
npx skills add ciaooo55/skill
```

---

## 各 AI 客户端全局 Skills 路径对照

| AI 客户端 | 全局 Skills 目录 |
|---|---|
| **Codex** / **DeepSeek Harness** / Open Agents 标准 | `~/.agents/skills/<skill-name>/SKILL.md` |
| **Antigravity (AGY)** / **T3 Code (AGY ACP)** | `~/.gemini/config/skills/<skill-name>/SKILL.md` |
| **Claude Code** | `~/.claude/skills/<skill-name>/SKILL.md` |
| **Cursor** | `~/.cursor/skills/<skill-name>/SKILL.md` |

---

## 如何新增第 2、第 3 个 Skill

1. 在 `skills/` 下新建小写连字符目录，例如 `skills/my-next-skill/`：
   ```text
   skills/my-next-skill/
   ├── SKILL.md          # 必需：包含 name / description YAML frontmatter 与精简流程
   ├── agents/
   │   └── openai.yaml   # 可选：Codex / UI 展示元数据
   ├── references/       # 可选：按需读取的详细手册
   └── scripts/          # 可选：确定性辅助脚本
   ```
2. 在本 `README.md` 顶部的 **Skills 目录** 表格与 **Skill 详解** 中补充一行说明。
3. 运行 `.\install-windows.ps1` 即可自动把新 Skill 联接到所有已选客户端。

---

## 许可协议

本项目采用 [MIT License](./LICENSE) 开源。
