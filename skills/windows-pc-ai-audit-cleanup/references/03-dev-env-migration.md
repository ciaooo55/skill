# Phase 3: Universal Dev Environment & AI Model Storage Organization

Machine-agnostic rules for cleaning, deduplicating, and optionally relocating dev toolchains, package caches, and local AI model weights on **any** Windows PC.

## 1. Pre-Flight Rules (Before Touching Any Toolchain)
1. **Only Touch What Is Installed**: Never install missing languages or pre-create empty folders for ecosystems the user doesn't use.
2. **Check Active Build Processes**: Verify no `rustc`, `cargo`, `go`, `node`, `pnpm`, `npm`, `yarn`, `bun`, `python`, `pip`, `uv`, `conda`, `java`, `gradle`, `mvn`, `dotnet`, `ollama`, or `docker` processes are actively writing before moving their folders.
3. **Adapt to Single-Drive vs Multi-Drive**:
   - **Multi-drive**: Move/redirect selected caches & toolchains to `<TargetRoot>` (e.g. `D:\DevEnv\` or `E:\DevEnv\`) chosen by the user in Phase 1.
   - **Single-drive (`C:` only)**: Focus on **deduplication & pruning** (remove old unused Rust toolchains, prune pnpm/npm/pip/uv/conda/nuget/gradle caches, remove duplicate Node/Python/Git installs, compact WSL/Docker VHDX) rather than pointless same-drive moves—unless the user explicitly wants a clean centralized `C:\DevEnv\` layout.
4. **Respect Symlink Policy**: Prefer native persistent User environment variables (`[Environment]::SetEnvironmentVariable(k, v, 'User')`) and native config files over directory junctions.
5. **Write a Directory Manifest**: If creating a consolidated `<TargetRoot>`, write `<TargetRoot>\目录说明.txt` (or `README.txt`) mapping each folder to its env var so the user and future agents stay aligned.

## 2. Universal Ecosystem Reference (Pick Only Installed Ecosystems)

| Ecosystem | Common C: Bloat Locations | Env Vars / Native Config (`<ROOT>` = user-chosen root) | Key Safety Traps |
|---|---|---|---|
| **Rust** | `~/.rustup`, `~/.cargo` | `RUSTUP_HOME=<ROOT>\Rust\rustup`<br>`CARGO_HOME=<ROOT>\Rust\cargo`<br>User PATH: `<ROOT>\Rust\cargo\bin` | Check `rustup toolchain list` and uninstall obsolete toolchains first. Merge cleanly after all `cargo`/`rustc` processes exit. Update Rustup Uninstall registry path if present. |
| **Go** | `~/go`, `%LOCALAPPDATA%\go-build` | `GOPATH=<ROOT>\Go\gopath`<br>`GOMODCACHE=<ROOT>\Go\gopath\pkg\mod`<br>`GOCACHE=<ROOT>\Go\gocache` | Check `~/go/bin` & `~/go/src` first! If only `pkg/mod` cache exists, run `go clean -modcache` instead of copying 100k tiny read-only files onto an HDD. |
| **Node / pnpm / npm / yarn / bun / Electron** | `%LOCALAPPDATA%\pnpm*`, `%LOCALAPPDATA%\npm-cache`, `%APPDATA%\npm-cache`, `%LOCALAPPDATA%\Yarn`, `%USERPROFILE%\.bun\install\cache`, `%LOCALAPPDATA%\electron\Cache` | `PNPM_HOME=<ROOT>\Node\pnpm-home`<br>`pnpm config set store-dir <ROOT>\Node\pnpm-store`<br>`npm_config_cache=<ROOT>\Node\npm-cache`<br>`YARN_CACHE_FOLDER=<ROOT>\Node\yarn-cache`<br>`BUN_INSTALL_CACHE_DIR=<ROOT>\Node\bun-cache`<br>`ELECTRON_CACHE=<ROOT>\Node\electron-cache` | Check `Get-Command node,npm,pnpm -All` first! Node/pnpm may live inside Conda, NVM, Volta, or fnm. Never move the runtime binary directory blindly—redirect caches/stores safely. |
| **Python / pip / uv / Poetry / Conda** | `%LOCALAPPDATA%\pip`, `%LOCALAPPDATA%\uv`, `%LOCALAPPDATA%\pypoetry\Cache`, `~/.conda/pkgs`, `~/.conda/envs` | `PIP_CACHE_DIR=<ROOT>\Python\pip-cache`<br>`UV_CACHE_DIR=<ROOT>\Python\uv-cache`<br>`POETRY_CACHE_DIR=<ROOT>\Python\poetry-cache`<br>`CONDA_PKGS_DIRS=<ROOT>\Python\conda-pkgs`<br>`~/.condarc`: set `envs_dirs` & `pkgs_dirs` | **CRITICAL CONDA TRAP**: Never `Move-Item` an existing active Conda env whose `.exe` shims embed absolute paths—keep existing envs in place and redirect `.condarc` for future envs and package caches. |
| **AI / ML Model Caches** | `~/.cache/huggingface`, `~/.cache/torch`, `~/.ollama/models`, `~/.lmstudio/models` | `HF_HOME=<ROOT>\AI-Models\huggingface`<br>`TORCH_HOME=<ROOT>\AI-Models\torch`<br>`OLLAMA_MODELS=<ROOT>\AI-Models\ollama` | Can easily be 10–100+ GB! Confirm with user before moving or deleting downloaded weights; stop Ollama/LM Studio before moving their model folders. |
| **Java (Gradle / Maven)** | `~/.gradle`, `~/.m2/repository` | `GRADLE_USER_HOME=<ROOT>\Java\gradle`<br>`~/.m2/settings.xml` (`<localRepository>`) | Preserve custom `~/.gradle/gradle.properties` or `~/.m2/settings.xml` credentials/mirrors when migrating. |
| **.NET (NuGet)** | `~/.nuget/packages` | `NUGET_PACKAGES=<ROOT>\DotNet\nuget` | Pure package cache; safe to redirect and clear old cache. |
| **Android / Flutter / Dart** | `%LOCALAPPDATA%\Android\Sdk`, `~/.android/avd`, `%LOCALAPPDATA%\Pub\Cache` | `ANDROID_HOME` / `ANDROID_SDK_ROOT`<br>`ANDROID_AVD_HOME`<br>`PUB_CACHE=<ROOT>\Flutter\pub-cache` | Android SDK/AVD relocation should be reflected in Android Studio settings too; warn if user relies on emulator snapshots. |
| **Selenium / Playwright Browsers** | `~/.cache/selenium`, `%LOCALAPPDATA%\ms-playwright` | `SE_CACHE_PATH=<ROOT>\Browsers\selenium`<br>`PLAYWRIGHT_BROWSERS_PATH=<ROOT>\Browsers\playwright` | Check whether MCP servers or scripts set their own Playwright browser path before deleting old browser binaries. |

## 3. PATH, Shell Profile & Git Config Hygiene
- **Deduplicate & Clean `PATH`**: Inspect both User and Machine `PATH`. Remove non-existent directories, duplicate entries, and hardcoded single-version paths when a stable shim exists. Check for accidental shadowing (`Get-Command git,python,node,codex -All`) and warn the user if an older copy shadows a newer one.
- **Dead Environment Variables**: List user env vars pointing to non-existent directories and ask before removing. **NEVER** remove or display raw auth tokens (`GH_TOKEN`, `OPENAI_API_KEY`, etc.).
- **Git Global Config (`~/.gitconfig`)**: Audit for leaked global `http.extraheader` auth headers or dead proxy settings (redact tokens!).
- **Shell Profiles (`$PROFILE`, `~/.bashrc`, `~/.zshrc`)**: Check for broken `source`/PATH hooks left by uninstalled tools.

## 4. Mandatory Post-Reboot Verification
In a fresh shell **after reboot** (no temporary `$env:` overrides):
- Verify every installed toolchain resolves cleanly (`--version`) and reports its new cache/store directory (`pnpm store path`, `npm config get cache`, `pip cache dir`, `uv cache dir`, `go env`, `rustup show home`, etc.).
- Confirm none of the retired `C:` cache directories were silently recreated.
