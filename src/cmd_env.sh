# ── cmd: add / switch / ls ─────────────────────────────────────

cmd_add() {
    _require_setup
    local scheme="http"
    if [[ "${1:-}" == "--socks5" ]]; then
        scheme="socks5"
        shift
    fi

    if [[ $# -lt 2 || $# -gt 3 ]]; then
        echo "用法：cac add [--socks5] <名字> <host:port[:user:pass]>" >&2
        echo "示例(HTTP)：cac add us1 1.2.3.4:1080:username:password" >&2
        echo "示例(SOCKS5)：cac add --socks5 us1 1.2.3.4:1080:username:password" >&2
        exit 1
    fi

    local name="$1" raw_proxy="$2"
    if [[ $# -eq 3 ]]; then
        if [[ "$3" == "--socks5" ]]; then
            scheme="socks5"
        else
            echo "错误：不支持的参数 '$3'，仅支持 --socks5" >&2
            exit 1
        fi
    fi
    local env_dir="$ENVS_DIR/$name"

    if [[ -d "$env_dir" ]]; then
        echo "错误：环境 '$name' 已存在，用 'cac ls' 查看" >&2
        exit 1
    fi

    local proxy
    proxy=$(_parse_proxy "$raw_proxy" "$scheme")

    echo "即将创建环境：$(_bold "$name")"
    echo "  协议：$scheme"
    echo "  代理：$proxy"
    echo

    printf "  检测代理 ... "
    if _proxy_reachable "$proxy"; then
        echo "$(_green "✓ 可达")"
    else
        echo "$(_red "✗ 不通")"
        echo "  警告：代理当前不可达（代理客户端可能未启动）"
    fi

    # 自动检测出口 IP 的时区和语言
    printf "  检测时区 ... "
    local exit_ip tz lang
    exit_ip=$(curl -s --proxy "$proxy" --connect-timeout 8 https://api.ipify.org 2>/dev/null || true)
    if [[ -n "$exit_ip" ]]; then
        local ip_info
        ip_info=$(curl -s --connect-timeout 8 "http://ip-api.com/json/${exit_ip}?fields=timezone,countryCode" 2>/dev/null || true)
        tz=$(echo "$ip_info" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('timezone',''))" 2>/dev/null || true)
        country=$(echo "$ip_info" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('countryCode',''))" 2>/dev/null || true)
        [[ -z "$tz" ]] && tz="America/New_York"
        [[ "$country" == "US" || "$country" == "GB" || "$country" == "AU" || "$country" == "CA" ]] && lang="en_US.UTF-8" || lang="en_US.UTF-8"
        echo "$(_green "✓ $tz")"
    else
        tz="America/New_York"
        lang="en_US.UTF-8"
        echo "$(_yellow "⚠ 获取失败，默认 $tz")"
    fi
    echo

    printf "确认创建？[yes/N] "
    read -r confirm
    [[ "$confirm" == "yes" ]] || { echo "已取消。"; exit 0; }

    mkdir -p "$env_dir"
    mkdir -p "$env_dir/codex-state/codex-home" "$env_dir/codex-state/xdg/config" \
             "$env_dir/codex-state/xdg/cache" "$env_dir/codex-state/xdg/data" "$env_dir/codex-state/xdg/state"
    mkdir -p "$env_dir/gemini-state/gemini-home" "$env_dir/gemini-state/xdg/config" \
             "$env_dir/gemini-state/xdg/cache" "$env_dir/gemini-state/xdg/data" "$env_dir/gemini-state/xdg/state"
    echo "$proxy"              > "$env_dir/proxy"
    echo "$(_new_uuid)"        > "$env_dir/uuid"
    echo "$(_new_sid)"         > "$env_dir/stable_id"
    echo "$(_new_user_id)"     > "$env_dir/user_id"
    echo "$(_new_serial)"      > "$env_dir/serial"
    echo "$(_new_hostname)"    > "$env_dir/hostname"
    echo "$tz"                 > "$env_dir/tz"
    echo "$lang"               > "$env_dir/lang"
    _minimal_claude_json "$(_read "$env_dir/user_id")" "$(_now_iso)" > "$env_dir/claude.json"

    echo
    echo "$(_green "✓") 环境 '$(_bold "$name")' 已创建"
    echo "  UUID     ：$(cat "$env_dir/uuid")"
    echo "  Serial   ：$(cat "$env_dir/serial")"
    echo "  Hostname ：$(cat "$env_dir/hostname")"
    echo "  stable_id：$(cat "$env_dir/stable_id")"
    echo "  TZ       ：$tz"
    echo "  LANG     ：$lang"
    echo
    echo "切换到该环境：cac $name"
}

cmd_switch() {
    _require_setup
    local name="$1"
    _require_env "$name"

    local proxy; proxy=$(_read "$ENVS_DIR/$name/proxy")

    printf "检测 [%s] 代理 ... " "$name"
    if _proxy_reachable "$proxy"; then
        echo "$(_green "✓ 可达")"
    else
        echo "$(_yellow "⚠ 不通")"
        echo "警告：代理不可达，仍切换（启动受控 CLI 时会拦截）"
    fi

    if [[ -f "$CAC_DIR/real_claude" ]]; then
        _swap_claude_json "$name"
    fi

    echo "$name" > "$CAC_DIR/current"
    rm -f "$CAC_DIR/stopped"

    if [[ -f "$CAC_DIR/real_claude" ]]; then
        _update_statsig "$(_read "$ENVS_DIR/$name/stable_id")"
    fi

    echo "$(_green "✓") 已切换到 $(_bold "$name")"
}

cmd_rm() {
    _require_setup
    if [[ $# -lt 1 ]]; then
        echo "用法：cac rm <名字>" >&2; exit 1
    fi

    local name="$1"
    _require_env "$name"

    local current; current=$(_current_env)
    if [[ "$name" == "$current" ]]; then
        echo "错误：'$name' 是当前激活的环境，请先切换到其他环境再删除" >&2; exit 1
    fi

    printf "确认删除环境 '%s'？[yes/N] " "$(_bold "$name")"
    read -r confirm
    [[ "$confirm" == "yes" ]] || { echo "已取消。"; exit 0; }

    rm -rf "$ENVS_DIR/$name"
    echo "$(_green "✓") 环境 '$(_bold "$name")' 已删除"
}

cmd_ls() {
    _require_setup

    if [[ ! -d "$ENVS_DIR" ]] || [[ -z "$(ls -A "$ENVS_DIR" 2>/dev/null)" ]]; then
        echo "（暂无环境，用 'cac add <名字> <proxy>' 添加）"
        return
    fi

    local current; current=$(_current_env)
    local stopped_tag=""
    [[ -f "$CAC_DIR/stopped" ]] && stopped_tag=" $(_red "[stopped]")"

    for env_dir in "$ENVS_DIR"/*/; do
        local name; name=$(basename "$env_dir")
        local proxy; proxy=$(_read "$env_dir/proxy" "（未配置）")
        if [[ "$name" == "$current" ]]; then
            printf "  %s %s%s\n" "$(_green "▶")" "$(_bold "$name")" "$stopped_tag"
            printf "    %s\n" "$proxy"
        else
            printf "    %s\n" "$name"
            printf "    %s\n" "$proxy"
        fi
    done
}
