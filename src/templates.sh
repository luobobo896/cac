# ── templates: 写入 wrapper 和 ioreg shim ──────────────────────

_write_wrapper() {
    local tool="$1"
    local wrapper_file="$CAC_DIR/bin/$tool"

    mkdir -p "$CAC_DIR/bin"
    cat > "$wrapper_file" << WRAPPER_HEAD_EOF
#!/usr/bin/env bash
set -euo pipefail

CAC_DIR="\$HOME/.cac"
ENVS_DIR="\$CAC_DIR/envs"
TOOL="$tool"
REAL_FILE="\$CAC_DIR/real_${tool}"

# cacstop 状态：直接透传
if [[ -f "\$CAC_DIR/stopped" ]]; then
    _real=\$(tr -d '[:space:]' < "\$REAL_FILE" 2>/dev/null || true)
    [[ -x "\$_real" ]] && exec "\$_real" "\$@"
    echo "[cac] 错误：找不到真实 \$TOOL，运行 'cac setup'" >&2; exit 1
fi

# 读取当前环境
if [[ ! -f "\$CAC_DIR/current" ]]; then
    echo "[cac] 错误：未激活任何环境，运行 'cac <name>'" >&2; exit 1
fi
_name=\$(tr -d '[:space:]' < "\$CAC_DIR/current")
_env_dir="\$ENVS_DIR/\$_name"
[[ -d "\$_env_dir" ]] || { echo "[cac] 错误：环境 '\$_name' 不存在" >&2; exit 1; }

PROXY=\$(tr -d '[:space:]' < "\$_env_dir/proxy")

# pre-flight：代理连通性
_hp=\$(echo "\$PROXY" | sed 's|.*@||' | sed 's|.*://||')
_host=\$(echo "\$_hp" | cut -d: -f1)
_port=\$(echo "\$_hp" | cut -d: -f2)
if ! (echo >/dev/tcp/"\$_host"/"\$_port") 2>/dev/null; then
    echo "[cac] 错误：[\$_name] 代理 \$_hp 不通，拒绝启动。" >&2
    echo "[cac] 提示：运行 'cac check' 排查，或 'cacstop' 临时停用" >&2
    exit 1
fi

# 注入环境变量
export HTTPS_PROXY="\$PROXY" HTTP_PROXY="\$PROXY" ALL_PROXY="\$PROXY"
export NO_PROXY="localhost,127.0.0.1"
[[ -f "\$_env_dir/tz" ]]       && export TZ=\$(tr -d '[:space:]' < "\$_env_dir/tz")
[[ -f "\$_env_dir/lang" ]]     && export LANG=\$(tr -d '[:space:]' < "\$_env_dir/lang")
[[ -f "\$_env_dir/hostname" ]] && export HOSTNAME=\$(tr -d '[:space:]' < "\$_env_dir/hostname")
export PATH="\$CAC_DIR/shim-bin:\$PATH"
WRAPPER_HEAD_EOF

    if [[ "$tool" == "claude" ]]; then
        cat >> "$wrapper_file" << 'WRAPPER_CLAUDE_EOF'
# 注入 statsig stable_id（仅 claude）
if [[ -f "$_env_dir/stable_id" ]]; then
    _sid=$(tr -d '[:space:]' < "$_env_dir/stable_id")
    for _f in "$HOME/.claude/statsig"/statsig.stable_id.*; do
        [[ -f "$_f" ]] && printf '"%s"' "$_sid" > "$_f"
    done
fi

export CLAUDE_CODE_ENABLE_TELEMETRY=0
unset ANTHROPIC_BASE_URL
unset ANTHROPIC_AUTH_TOKEN
unset ANTHROPIC_API_KEY
WRAPPER_CLAUDE_EOF
    elif [[ "$tool" == "codex" ]]; then
        cat >> "$wrapper_file" << 'WRAPPER_CODEX_EOF'
_state_dir="$_env_dir/codex-state"
mkdir -p "$_state_dir/codex-home" "$_state_dir/xdg/config" \
         "$_state_dir/xdg/cache" "$_state_dir/xdg/data" "$_state_dir/xdg/state"
export CODEX_HOME="$_state_dir/codex-home"
export XDG_CONFIG_HOME="$_state_dir/xdg/config"
export XDG_CACHE_HOME="$_state_dir/xdg/cache"
export XDG_DATA_HOME="$_state_dir/xdg/data"
export XDG_STATE_HOME="$_state_dir/xdg/state"
WRAPPER_CODEX_EOF
    elif [[ "$tool" == "gemini" ]]; then
        cat >> "$wrapper_file" << 'WRAPPER_GEMINI_EOF'
_state_dir="$_env_dir/gemini-state"
mkdir -p "$_state_dir/gemini-home" "$_state_dir/xdg/config" \
         "$_state_dir/xdg/cache" "$_state_dir/xdg/data" "$_state_dir/xdg/state"
export GEMINI_HOME="$_state_dir/gemini-home"
export XDG_CONFIG_HOME="$_state_dir/xdg/config"
export XDG_CACHE_HOME="$_state_dir/xdg/cache"
export XDG_DATA_HOME="$_state_dir/xdg/data"
export XDG_STATE_HOME="$_state_dir/xdg/state"
WRAPPER_GEMINI_EOF
    fi

    cat >> "$wrapper_file" << 'WRAPPER_TAIL_EOF'
# 执行真实命令
_real=$(tr -d '[:space:]' < "$REAL_FILE" 2>/dev/null || true)
[[ -x "$_real" ]] || { echo "[cac] 错误：$REAL_FILE 不可执行，运行 'cac setup'" >&2; exit 1; }
exec "$_real" "$@"
WRAPPER_TAIL_EOF

    chmod +x "$wrapper_file"
}

_write_ioreg_shim() {
    mkdir -p "$CAC_DIR/shim-bin"
    cat > "$CAC_DIR/shim-bin/ioreg" << 'IOREG_EOF'
#!/usr/bin/env bash
CAC_DIR="$HOME/.cac"

# 非目标调用：透传真实 ioreg
if ! echo "$*" | grep -q "IOPlatformExpertDevice"; then
    _real=$(PATH=$(echo "$PATH" | tr ':' '\n' | grep -v "$CAC_DIR/shim-bin" | tr '\n' ':') \
            command -v ioreg 2>/dev/null || true)
    [[ -n "$_real" ]] && exec "$_real" "$@"
    exit 0
fi

# 读取当前环境的 UUID
_uuid_file="$CAC_DIR/envs/$(tr -d '[:space:]' < "$CAC_DIR/current" 2>/dev/null)/uuid"
if [[ ! -f "$_uuid_file" ]]; then
    _real=$(PATH=$(echo "$PATH" | tr ':' '\n' | grep -v "$CAC_DIR/shim-bin" | tr '\n' ':') \
            command -v ioreg 2>/dev/null || true)
    [[ -n "$_real" ]] && exec "$_real" "$@"
    exit 0
fi
FAKE_UUID=$(tr -d '[:space:]' < "$_uuid_file")
_serial_file="$CAC_DIR/envs/$(tr -d '[:space:]' < "$CAC_DIR/current" 2>/dev/null)/serial"
FAKE_SERIAL=$([ -f "$_serial_file" ] && tr -d '[:space:]' < "$_serial_file" || echo "C02FAKE000001")

cat <<EOF
+-o Root  <class IORegistryEntry, id 0x100000100, retain 11>
  +-o J314sAP  <class IOPlatformExpertDevice, id 0x100000101, registered, matched, active, busy 0 (0 ms), retain 28>
    {
      "IOPlatformUUID" = "$FAKE_UUID"
      "IOPlatformSerialNumber" = "$FAKE_SERIAL"
      "manufacturer" = "Apple Inc."
      "model" = "Mac14,5"
    }
EOF
IOREG_EOF
    chmod +x "$CAC_DIR/shim-bin/ioreg"
}
