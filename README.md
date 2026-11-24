# skill

面向多平台 AI Coding Agent 的个人/通用 **Skills 集合仓库**（标准 `skills/<skill-name>/SKILL.md` 结构）。

一次维护，多端共用：通过目录联接（Windows Junction）或软链接（macOS / Linux Symlink），即可同时接入 **Codex、Antigravity (AGY)、T3 Code、Claude Code、DeepSeek Harness、Cursor、Windsurf** 等主流 AI 工具，拉取更新即全端同步生效。

---

## Skills 目录

| # | Skill 名称 | 简介与适用场景 | 入口文档 |
|---|---|---|---|
| 1 | [`windows-pc-ai-audit-cleanup`](./skills/windows-pc-ai-audit-cleanup/) | **通用 Windows 电脑体检、清理、开发环境与 AI/MCP/Skills 治理**。适用于任意 Windows 10/11 电脑（单盘/多盘、SSD/HDD、台式/笔记本），支持深层绿色软件发现、重复环境三分法去重、陌生软件零瞎猜安全确认、MCP 独立隔离、跨端 Skills 统一与重启后真实环境验收。 | [SKILL.md](./skills/windows-pc-ai-audit-cleanup/SKILL.md) |
| 2 | *（后续扩展占位）* | 新增 Skill 直接放入 `skills/<new-skill-name>/SKILL.md` 并在本表补充说明即可，一键安装脚本会自动识别。 | — |

---

## Skill 详解

### 1. [`windows-pc-ai-audit-cleanup`](./skills/windows-pc-ai-audit-cleanup/SKILL.md)

**做什么的**：一套完整、强健、安全的交互式 Windows 电脑深度体检与整理工作流，解决「C 盘爆红、环境乱、依赖乱、AI/MCP/Skills 乱、软件装得深且重复」等问题。

**核心特性**：
- **7 条安全铁律**：先只读体检后动手；绝不私自改动 Defender/防火墙/虚拟化/浏览器登录态/聊天记录；绝不打印原始密钥与 Token；绝不在线修改运行中的 SQLite/缓存；绝不凭猜测删除陌生软件或私有隔离运行时。
- **6 阶段门禁流程**：
  1. `Phase 0` 只读深度扫描（自动识别单/多盘、SSD/HDD、Top 空间大户、开机报错、开发工具链、全部 AI 客户端/MCP/Skills、深层快捷方式与便携进程、重复项与未归类点目录）；
  2. `Phase 1` 交互式选型对话（逐项确认清理范围、不碰红线、DevEnv 放哪里、要不要软链接、AI MCP 放哪里与按客户端接入、Skills 放哪里、重复/陌生项目取舍）；
  3. `Phase 2` Windows 系统/磁盘/服务/注册表/搜索索引/虚拟内存/电源与 Wi-Fi 调优；
  4. `Phase 3` 多语言开发环境与本地 AI 模型权重整理（Rust/Go/Node/pnpm/Python/Conda/Java/.NET/Android/Flutter/Ollama/HuggingFace）；
  5. `Phase 4` AI 软件盘点、MCP 独立隔离与冒烟测试、跨端 Skills 统一治理、可选 T3 Code↔Codex↔AGY 离线对话残留清理；
  6. `Phase 5` 重启后真实环境变量验收。
- **内置可复用资源**：
  - 分阶段手册：[`references/`](./skills/windows-pc-ai-audit-cleanup/references/)（共 5 份，按需渐进加载，不浪费上下文）
  - 只读高速体检脚本：[`scripts/audit_pc_readonly.ps1`](./skills/windows-pc-ai-audit-cleanup/scripts/audit_pc_readonly.ps1)（兼容 Windows PowerShell 5.1 与 PowerShell 7，内置 C# 高速统计与单目录超时保护，防卡死）
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
