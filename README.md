<div align="center">

# cac — Multi-CLI Cloak

**Privacy Cloak + CLI Proxy for Claude / Codex / Gemini**

**[中文](#中文) | [English](#english)**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-macOS-lightgrey.svg)]()
[![Shell](https://img.shields.io/badge/Shell-Bash-green.svg)]()

</div>

---

<a id="中文"></a>

## 中文

> **[Switch to English](#english)**

### 为什么需要 cac

CLI 工具在运行过程中会暴露多维设备与本地状态标识符（不同工具字段不同）：

- **硬件层**：硬件 UUID、序列号（通过 `ioreg` 读取）、主机名（`os.hostname()`）
- **本地状态层**：配置目录、缓存目录、历史会话目录（如 `~/.codex`、XDG 目录等）
- **账号层（以 Claude 为例）**：`stable_id`、`userID`（存储于 `~/.claude/statsig/` 和 `~/.claude.json`）
- **网络层**：出口 IP

单独换代理或只改 userID 不够——只要其余字段不变，多个账号仍可被关联为同一设备。

cac 通过 wrapper 机制拦截受控 CLI 调用（`claude` / `codex` / `gemini`），在进程层面同时解决两个问题：

**A. 隐私隔离** — 每个配置独立管理全套设备标识，切换时原子替换所有字段，对外呈现完全独立的设备身份。

**B. CLI 专属代理** — 进程级注入代理，CLI 流量直连远端代理服务器。无需 Clash / Shadowrocket 等本地代理工具，无需中转，无需起本地服务端。配合静态住宅 IP，获得固定、干净的出口身份。

### 特性一览

| | 特性 | 说明 |
|:---|:---|:---|
| **A** | 硬件 UUID 隔离 | 拦截 `ioreg`，每个配置返回独立 UUID |
| **A** | 序列号隔离 | 拦截 `ioreg`，每个配置返回独立序列号 |
| **A** | stable_id / userID 隔离 | 切换配置时自动写入独立标识 |
| **A** | 行为数据隔离 | `claude` 通过替换 `~/.claude.json` 隔离行为字段；`codex/gemini` 通过 profile 级本地状态目录隔离会话与配置 |
| **A** | codex/gemini 本地状态隔离 | 注入 profile 级 `CODEX_HOME` / `GEMINI_HOME` 与 XDG 目录 |
| **A** | 主机名伪装 | 注入独立 `HOSTNAME`，防止 `os.hostname()` 泄露真实机器名 |
| **A** | 时区 / 语言伪装 | 根据代理出口地区自动匹配 |
| **A** | 遥测关闭 | 显式设置 `CLAUDE_CODE_ENABLE_TELEMETRY=0` |
| **B** | 进程级代理 | 直接注入 `HTTPS_PROXY` / `HTTP_PROXY` / `ALL_PROXY` |
| **B** | 免本地服务端 | 无需 Clash / Shadowrocket / TUN，CLI 直连 |
| **B** | 静态住宅 IP 支持 | 配置固定代理 → 固定出口 IP |
| **B** | 启动前连通检测 | 代理不可达时拒绝启动，真实 IP 零泄漏 |

所有受控 CLI 调用均通过 wrapper 拦截。

### 安装

**一键安装（推荐）：**

```bash
curl -fsSL https://raw.githubusercontent.com/luobobo896/cac/master/install.sh | bash
```

安装脚本会自动完成：将 `cac` 放入 `~/bin`、在 `~/.zshrc` 中添加 PATH、生成 wrapper 和 ioreg shim。

**手动安装：**

```bash
git clone https://github.com/luobobo896/cac.git
cd cac
bash install.sh
```

安装完成后重开终端，或执行：

```bash
source ~/.zshrc
```

### 使用

```bash
# 添加一个配置（自动检测代理出口的时区和语言）
cac add us1 1.2.3.4:1080:username:password

# 添加一个 SOCKS5 配置（默认是 HTTP，需显式加 --socks5）
cac add --socks5 us2 1.2.3.4:1080:username:password

# 切换配置（同时刷新所有隐私参数）
cac us1

# 检查当前状态
cac check

# 启动受控 CLI（均走 wrapper）
claude
codex
gemini
```

首次使用各 CLI 请分别登录：`claude` 在 Claude Code 内执行 `/login`；`codex` / `gemini` 使用各自登录命令。

### 命令

| 命令 | 说明 |
|:---|:---|
| `cac add [--socks5] <名字> <host:port[:u:p]>` | 添加新配置（默认 HTTP，带 `--socks5` 时使用 SOCKS5） |
| `cac <名字>` | 切换配置，刷新所有隐私参数 |
| `cac ls` | 列出所有配置 |
| `cac rm <名字>` | 删除指定配置（需要 yes 确认） |
| `cac check` | 检查代理连通性和当前隐私参数 |
| `cac stop` | 临时停用保护（受控 CLI 裸跑） |
| `cac -c` | 恢复保护 |

### 工作原理

```
                cac wrappers (进程级)
                ┌─────────────────────────┐
  cli(cmd) ────►│ 注入代理环境变量         │──── 直连远端代理 ────► Provider API
                │ 注入伪装设备标识         │     (静态住宅 IP)
                │ (TZ/LANG/HOSTNAME/ioreg)│
                │ 注入 profile 级本地状态目录│
                │ 启动前检测代理连通性      │
                └─────────────────────────┘
                    ↑ 无本地服务端
                    ↑ 无流量中转
                    ↑ 无 TUN / 系统代理
```

### 文件结构

```
~/.cac/
├── bin/
│   ├── claude          # wrapper
│   ├── codex           # wrapper
│   └── gemini          # wrapper
├── shim-bin/ioreg      # ioreg shim，返回配置独立的硬件 UUID
├── real_claude         # 真实 claude 二进制路径
├── real_codex          # 真实 codex 二进制路径
├── real_gemini         # 真实 gemini 二进制路径
├── current             # 当前激活的配置名
├── stopped             # 存在则临时停用
└── envs/
    └── <name>/
        ├── proxy       # http://... 或 socks5h://...
        ├── uuid        # 独立硬件 UUID
        ├── serial      # 独立序列号（如 C02XXXXXXXX）
        ├── stable_id   # 独立 stable_id
        ├── user_id     # 独立 userID
        ├── hostname    # 独立主机名（如 MacBook-Pro-A3F1）
        ├── tz          # 时区（如 America/New_York）
        ├── lang        # 语言（如 en_US.UTF-8）
        ├── claude.json # ~/.claude.json 快照（首次启动时间、使用记录、项目路径等）
        ├── codex-state/  # codex 的 profile 级本地状态目录（CODEX_HOME + XDG）
        └── gemini-state/ # gemini 的 profile 级本地状态目录（GEMINI_HOME + XDG）
```

### 注意事项

> **本地代理工具共存**
> 若同时使用 Clash / Shadowrocket 等 TUN 模式，需为代理服务器 IP 添加 DIRECT 规则，避免流量被二次拦截。

> **第三方 API 配置**
> `claude` wrapper 启动时会自动清除 `ANTHROPIC_BASE_URL` / `ANTHROPIC_AUTH_TOKEN` / `ANTHROPIC_API_KEY`，确保使用官方登录端点；`codex` / `gemini` wrapper 默认不清理各自 API Key 变量。

> **IPv6**
> 建议在系统层关闭 IPv6，防止真实出口 IPv6 地址被暴露。

---

<a id="english"></a>

## English

> **[切换到中文](#中文)**

### Why cac

CLI tools expose multiple identity and local-state surfaces at runtime (fields vary by tool):

- **Hardware**: UUID and serial number (via `ioreg`), hostname (via `os.hostname()`)
- **Local state**: config/cache/session directories (for example `~/.codex`, XDG directories)
- **Account (Claude example)**: `stable_id` and `userID` (stored in `~/.claude/statsig/` and `~/.claude.json`)
- **Network**: egress IP

Swapping a proxy or changing only the userID is not enough — as long as other fields remain the same, multiple accounts can still be correlated to the same device.

cac intercepts managed CLI invocations (`claude` / `codex` / `gemini`) via wrappers, solving two problems at the process level:

**A. Privacy Cloak** — Each profile manages a full set of independent device identifiers. On switch, all fields are replaced atomically, presenting a completely isolated device identity.

**B. CLI Proxy** — Process-level proxy injection; CLI traffic connects directly to the remote proxy server. No Clash / Shadowrocket or any local proxy tools needed. No relay, no local server. Pair with a static residential IP for a fixed, clean egress identity.

### Features

| | Feature | Description |
|:---|:---|:---|
| **A** | Hardware UUID isolation | Intercepts `ioreg`, returns profile-specific UUID |
| **A** | Serial number isolation | Intercepts `ioreg`, returns profile-specific serial number |
| **A** | stable_id / userID isolation | Writes independent identifiers on profile switch |
| **A** | Behavioral data isolation | `claude` isolates behavior by swapping `~/.claude.json`; `codex/gemini` isolate sessions and config via profile-scoped local state dirs |
| **A** | codex/gemini local state isolation | Injects profile-scoped `CODEX_HOME` / `GEMINI_HOME` and XDG directories |
| **A** | Hostname spoofing | Injects independent `HOSTNAME` to prevent `os.hostname()` from leaking the real machine name |
| **A** | Timezone / locale spoofing | Auto-detected from proxy exit region |
| **A** | Telemetry disabled | Explicitly sets `CLAUDE_CODE_ENABLE_TELEMETRY=0` |
| **B** | Process-level proxy | Injects `HTTPS_PROXY` / `HTTP_PROXY` / `ALL_PROXY` directly |
| **B** | No local server needed | No Clash / Shadowrocket / TUN — direct CLI connection |
| **B** | Static residential IP support | Fixed proxy config = fixed egress IP |
| **B** | Pre-launch connectivity check | Blocks startup if proxy unreachable — zero real IP leakage |

All managed CLI invocations are intercepted by wrappers.

### Installation

**One-line install (recommended):**

```bash
curl -fsSL https://raw.githubusercontent.com/luobobo896/cac/master/install.sh | bash
```

The install script automatically: places `cac` in `~/bin`, adds PATH to `~/.zshrc`, and generates the wrapper and ioreg shim.

**Manual install:**

```bash
git clone https://github.com/luobobo896/cac.git
cd cac
bash install.sh
```

After installation, restart your terminal or run:

```bash
source ~/.zshrc
```

### Usage

```bash
# Add a profile (auto-detects timezone and locale from proxy exit)
cac add us1 1.2.3.4:1080:username:password

# Add a SOCKS5 profile (HTTP is default; pass --socks5 explicitly)
cac add --socks5 us2 1.2.3.4:1080:username:password

# Switch profile (refreshes all privacy parameters)
cac us1

# Check current status
cac check

# Launch managed CLIs (through wrappers)
claude
codex
gemini
```

Authenticate each CLI on first use: `/login` inside `claude`, and the corresponding login command for `codex` / `gemini`.

### Commands

| Command | Description |
|:---|:---|
| `cac add [--socks5] <name> <host:port[:u:p]>` | Add a new profile (HTTP by default, SOCKS5 with `--socks5`) |
| `cac <name>` | Switch profile, refresh all privacy parameters |
| `cac ls` | List all profiles |
| `cac rm <name>` | Delete a profile (requires yes confirmation) |
| `cac check` | Check proxy connectivity and current privacy parameters |
| `cac stop` | Temporarily disable protection (managed CLIs run without wrapper protection) |
| `cac -c` | Re-enable protection |

### How It Works

```
                cac wrappers (process-level)
                ┌─────────────────────────┐
  cli(cmd) ────►│ Inject proxy env vars    │──── Direct to remote ────► Provider APIs
                │ Inject spoofed local identity │ (static residential)
                │ (TZ/LANG/HOSTNAME/ioreg) │
                │ Inject profile local-state dirs│
                │ Pre-flight proxy check   │
                └─────────────────────────┘
                    ↑ No local server
                    ↑ No traffic relay
                    ↑ No TUN / system proxy
```

### File Structure

```
~/.cac/
├── bin/
│   ├── claude          # wrapper
│   ├── codex           # wrapper
│   └── gemini          # wrapper
├── shim-bin/ioreg      # ioreg shim, returns profile-specific hardware UUID
├── real_claude         # path to the real claude binary
├── real_codex          # path to the real codex binary
├── real_gemini         # path to the real gemini binary
├── current             # currently active profile name
├── stopped             # if present, protection is temporarily disabled
└── envs/
    └── <name>/
        ├── proxy       # http://... or socks5h://...
        ├── uuid        # independent hardware UUID
        ├── serial      # independent serial number (e.g. C02XXXXXXXX)
        ├── stable_id   # independent stable_id
        ├── user_id     # independent userID
        ├── hostname    # independent hostname (e.g. MacBook-Pro-A3F1)
        ├── tz          # timezone (e.g. America/New_York)
        ├── lang        # locale (e.g. en_US.UTF-8)
        ├── claude.json # ~/.claude.json snapshot (first-launch time, usage history, project paths, etc.)
        ├── codex-state/  # profile-scoped local state for codex (CODEX_HOME + XDG)
        └── gemini-state/ # profile-scoped local state for gemini (GEMINI_HOME + XDG)
```

### Notes

> **Coexisting with local proxy tools**
> If you also use Clash / Shadowrocket in TUN mode, add a DIRECT rule for the proxy server IP to prevent traffic from being double-intercepted.

> **Third-party API configuration**
> The `claude` wrapper clears `ANTHROPIC_BASE_URL` / `ANTHROPIC_AUTH_TOKEN` / `ANTHROPIC_API_KEY` on startup to enforce official OAuth endpoints; `codex` / `gemini` wrappers keep their API key env vars untouched by default.

> **IPv6**
> It is recommended to disable IPv6 at the system level to prevent your real IPv6 egress address from being exposed.

---

<div align="center">

MIT License

</div>
