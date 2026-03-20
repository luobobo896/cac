# ── utils: 颜色、读写、UUID、proxy 解析 ───────────────────────

_read()   { [[ -f "$1" ]] && tr -d '[:space:]' < "$1" || echo "${2:-}"; }
_bold()   { printf '\033[1m%s\033[0m' "$*"; }
_green()  { printf '\033[32m%s\033[0m' "$*"; }
_red()    { printf '\033[31m%s\033[0m' "$*"; }
_yellow() { printf '\033[33m%s\033[0m' "$*"; }

_new_uuid()    { uuidgen | tr '[:lower:]' '[:upper:]'; }
_new_sid()     { uuidgen | tr '[:upper:]' '[:lower:]'; }
_new_user_id() { python3 -c "import os; print(os.urandom(32).hex())"; }
_new_serial()  { python3 -c "import random,string; print('C02'+''.join(random.choices(string.ascii_uppercase+string.digits,k=8)))"; }
_new_hostname(){ python3 -c "import random; print('MacBook-Pro-%04X' % random.randint(0,0xFFFF))"; }
_now_iso()     { python3 -c "import datetime; print(datetime.datetime.now(datetime.timezone.utc).isoformat(timespec='milliseconds').replace('+00:00','Z'))"; }

_minimal_claude_json() {
    local user_id="$1" first_start="$2"
    python3 -c "import json; print(json.dumps({
        'numStartups': 0,
        'installMethod': 'native',
        'autoUpdates': False,
        'tipsHistory': {},
        'firstStartTime': '${first_start}',
        'userID': '${user_id}',
        'hasCompletedOnboarding': False,
        'projects': {},
        'githubRepoPaths': {},
        'skillUsage': {}
    }, indent=2))"
}

# host:port:user:pass → http://user:pass@host:port
_parse_proxy() {
    local raw="$1"
    local host port user pass
    host=$(echo "$raw" | cut -d: -f1)
    port=$(echo "$raw" | cut -d: -f2)
    user=$(echo "$raw" | cut -d: -f3)
    pass=$(echo "$raw" | cut -d: -f4)
    if [[ -z "$user" ]]; then
        echo "http://${host}:${port}"
    else
        echo "http://${user}:${pass}@${host}:${port}"
    fi
}

# socks5://user:pass@host:port → host:port
_proxy_host_port() {
    echo "$1" | sed 's|.*@||' | sed 's|.*://||'
}

_proxy_reachable() {
    local hp host port
    hp=$(_proxy_host_port "$1")
    host=$(echo "$hp" | cut -d: -f1)
    port=$(echo "$hp" | cut -d: -f2)
    (echo >/dev/tcp/"$host"/"$port") 2>/dev/null
}

_current_env()  { _read "$CAC_DIR/current"; }
_env_dir()      { echo "$ENVS_DIR/$1"; }

_require_setup() {
    [[ -f "$CAC_DIR/real_claude" ]] || {
        echo "错误：请先运行 'cac setup'" >&2; exit 1
    }
}

_require_env() {
    [[ -d "$ENVS_DIR/$1" ]] || {
        echo "错误：环境 '$1' 不存在，用 'cac ls' 查看" >&2; exit 1
    }
}

_find_real_claude() {
    PATH=$(echo "$PATH" | tr ':' '\n' | grep -v "$CAC_DIR/bin" | tr '\n' ':') \
        command -v claude 2>/dev/null || true
}

_update_statsig() {
    local statsig="$HOME/.claude/statsig"
    [[ -d "$statsig" ]] || return 0
    for f in "$statsig"/statsig.stable_id.*; do
        [[ -f "$f" ]] && printf '"%s"' "$1" > "$f"
    done
}

_swap_claude_json() {
    local new_name="$1"
    local claude_json="$HOME/.claude.json"
    # 备份当前 profile 的 JSON
    local current_name; current_name=$(_current_env)
    if [[ -n "$current_name" && -f "$claude_json" && -d "$ENVS_DIR/$current_name" ]]; then
        cp "$claude_json" "$ENVS_DIR/$current_name/claude.json"
    fi
    # 恢复新 profile 的 JSON
    if [[ -f "$ENVS_DIR/$new_name/claude.json" ]]; then
        cp "$ENVS_DIR/$new_name/claude.json" "$claude_json"
    fi
}
