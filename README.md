<div align="center">

# cac — Claude Code Cloak

**Privacy Cloak + CLI Proxy for Claude Code**

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

Claude Code 在运行过程中会读取并上报设备标识符（硬件 UUID、安装 ID、网络出口 IP 等）。cac 通过 wrapper 机制拦截所有 `claude` 调用，在进程层面同时解决两个问题：

**A. 隐私隔离** — 每个配置对外呈现独立的设备身份，彻底隔离真实设备指纹。

**B. CLI 专属代理** — 进程级注入代理，`claude` 流量直连远端代理服务器。无需 Clash / Shadowrocket 等本地代理工具，无需中转，无需起本地服务端。配合静态住宅 IP，获得固定、干净的出口身份。

### 特性一览

| | 特性 | 说明 |
|:---|:---|:---|
| **A** | 硬件 UUID 隔离 | 拦截 `ioreg`，每个配置返回独立 UUID |
| **A** | stable_id / userID 隔离 | 切换配置时自动写入独立标识 |
| **A** | 时区 / 语言伪装 | 根据代理出口地区自动匹配 |
| **A** | 遥测关闭 | 置空 `CLAUDE_CODE_ENABLE_TELEMETRY` |
| **B** | 进程级代理 | 直接注入 `HTTPS_PROXY` / `HTTP_PROXY` / `ALL_PROXY` |
| **B** | 免本地服务端 | 无需 Clash / Shadowrocket / TUN，CLI 直连 |
| **B** | 静态住宅 IP 支持 | 配置固定代理 → 固定出口 IP |
| **B** | 启动前连通检测 | 代理不可达时拒绝启动，真实 IP 零泄漏 |

所有 `claude` 调用（含 Agent 子进程）均通过 wrapper 拦截。

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

# 切换配置（同时刷新所有隐私参数）
cac us1

# 检查当前状态
cac check

# 启动 Claude Code（走 wrapper）
claude
```

首次使用需在 Claude Code 内执行 `/login` 完成账号登录。

### 命令

| 命令 | 说明 |
|:---|:---|
| `cac add <名字> <host:port:u:p>` | 添加新配置 |
| `cac <名字>` | 切换配置，刷新所有隐私参数 |
| `cac ls` | 列出所有配置 |
| `cac check` | 检查代理连通性和当前隐私参数 |
| `cac stop` | 临时停用保护 |
| `cac -c` | 恢复保护 |

### 工作原理

```
                cac wrapper (进程级)
                ┌─────────────────────────┐
  claude ──────►│ 注入代理环境变量         │──── 直连远端代理 ────► Anthropic API
                │ 注入伪装设备标识         │     (静态住宅 IP)
                │ PATH 前置 ioreg shim    │
                │ 启动前检测代理连通性      │
                └─────────────────────────┘
                    ↑ 无本地服务端
                    ↑ 无流量中转
                    ↑ 无 TUN / 系统代理
```

### 文件结构

```
~/.cac/
├── bin/claude          # wrapper（拦截所有 claude 调用）
├── shim-bin/ioreg      # ioreg shim，返回配置独立的硬件 UUID
├── real_claude         # 真实 claude 二进制路径
├── current             # 当前激活的配置名
├── stopped             # 存在则临时停用
└── envs/
    └── <name>/
        ├── proxy       # http://user:pass@host:port
        ├── uuid        # 独立硬件 UUID
        ├── stable_id   # 独立 stable_id
        ├── user_id     # 独立 userID
        ├── tz          # 时区（如 America/New_York）
        └── lang        # 语言（如 en_US.UTF-8）
```

### 注意事项

> **本地代理工具共存**
> 若同时使用 Clash / Shadowrocket 等 TUN 模式，需为代理服务器 IP 添加 DIRECT 规则，避免流量被二次拦截。

> **第三方 API 配置**
> wrapper 启动时自动清除 `ANTHROPIC_BASE_URL` / `ANTHROPIC_AUTH_TOKEN` / `ANTHROPIC_API_KEY`，确保使用官方登录端点。

> **IPv6**
> 建议在系统层关闭 IPv6，防止真实出口 IPv6 地址被暴露。

---

<a id="english"></a>

## English

> **[切换到中文](#中文)**

### Why cac

Claude Code reads and reports device identifiers at runtime (hardware UUID, installation ID, network egress IP, etc.). cac intercepts all `claude` invocations via a wrapper, solving two problems at the process level:

**A. Privacy Cloak** — Each profile presents an independent device identity, fully isolating your real device fingerprint.

**B. CLI Proxy** — Process-level proxy injection; `claude` traffic connects directly to the remote proxy server. No Clash / Shadowrocket or any local proxy tools needed. No relay, no local server. Pair with a static residential IP for a fixed, clean egress identity.

### Features

| | Feature | Description |
|:---|:---|:---|
| **A** | Hardware UUID isolation | Intercepts `ioreg`, returns profile-specific UUID |
| **A** | stable_id / userID isolation | Writes independent identifiers on profile switch |
| **A** | Timezone / locale spoofing | Auto-detected from proxy exit region |
| **A** | Telemetry disabled | Clears `CLAUDE_CODE_ENABLE_TELEMETRY` |
| **B** | Process-level proxy | Injects `HTTPS_PROXY` / `HTTP_PROXY` / `ALL_PROXY` directly |
| **B** | No local server needed | No Clash / Shadowrocket / TUN — direct CLI connection |
| **B** | Static residential IP support | Fixed proxy config = fixed egress IP |
| **B** | Pre-launch connectivity check | Blocks startup if proxy unreachable — zero real IP leakage |

All `claude` invocations (including Agent subprocesses) are intercepted by the wrapper.

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

# Switch profile (refreshes all privacy parameters)
cac us1

# Check current status
cac check

# Launch Claude Code (through wrapper)
claude
```

On first use, run `/login` inside Claude Code to authenticate.

### Commands

| Command | Description |
|:---|:---|
| `cac add <name> <host:port:u:p>` | Add a new profile |
| `cac <name>` | Switch profile, refresh all privacy parameters |
| `cac ls` | List all profiles |
| `cac check` | Check proxy connectivity and current privacy parameters |
| `cac stop` | Temporarily disable protection |
| `cac -c` | Re-enable protection |

### How It Works

```
                cac wrapper (process-level)
                ┌─────────────────────────┐
  claude ──────►│ Inject proxy env vars    │──── Direct to remote ────► Anthropic API
                │ Inject spoofed identity  │     (static residential)
                │ Prepend ioreg shim       │
                │ Pre-flight proxy check   │
                └─────────────────────────┘
                    ↑ No local server
                    ↑ No traffic relay
                    ↑ No TUN / system proxy
```

### File Structure

```
~/.cac/
├── bin/claude          # wrapper (intercepts all claude invocations)
├── shim-bin/ioreg      # ioreg shim, returns profile-specific hardware UUID
├── real_claude         # path to the real claude binary
├── current             # currently active profile name
├── stopped             # if present, protection is temporarily disabled
└── envs/
    └── <name>/
        ├── proxy       # http://user:pass@host:port
        ├── uuid        # independent hardware UUID
        ├── stable_id   # independent stable_id
        ├── user_id     # independent userID
        ├── tz          # timezone (e.g. America/New_York)
        └── lang        # locale (e.g. en_US.UTF-8)
```

### Notes

> **Coexisting with local proxy tools**
> If you also use Clash / Shadowrocket in TUN mode, add a DIRECT rule for the proxy server IP to prevent traffic from being double-intercepted.

> **Third-party API configuration**
> The wrapper automatically clears `ANTHROPIC_BASE_URL` / `ANTHROPIC_AUTH_TOKEN` / `ANTHROPIC_API_KEY` on startup to ensure the official login endpoint is used.

> **IPv6**
> It is recommended to disable IPv6 at the system level to prevent your real IPv6 egress address from being exposed.

---

<div align="center">

MIT License

</div>
