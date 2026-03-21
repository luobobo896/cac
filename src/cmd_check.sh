# ── cmd: check ─────────────────────────────────────────────────

cmd_check() {
    _require_setup

    local current; current=$(_current_env)

    if [[ -f "$CAC_DIR/stopped" ]]; then
        echo "$(_yellow "⚠ cac 已停用（cacstop）") — 受控 CLI 裸跑中"
        echo "  恢复：cac ${current:-<name>}"
        return
    fi

    if [[ -z "$current" ]]; then
        echo "错误：未激活任何环境，运行 'cac <name>'" >&2; exit 1
    fi

    local env_dir="$ENVS_DIR/$current"
    local proxy; proxy=$(_read "$env_dir/proxy")

    echo "当前环境：$(_bold "$current")"
    echo "  代理      ：$proxy"
    echo "  UUID      ：$(_read "$env_dir/uuid")"
    echo "  stable_id ：$(_read "$env_dir/stable_id")"
    echo "  user_id   ：$(_read "$env_dir/user_id" "（旧环境，无此字段）")"
    echo "  TZ        ：$(_read "$env_dir/tz" "（未设置）")"
    echo "  LANG      ：$(_read "$env_dir/lang" "（未设置）")"
    echo

    printf "  TCP 连通  ... "
    if ! _proxy_reachable "$proxy"; then
        echo "$(_red "✗ 不通")"; return
    fi
    echo "$(_green "✓")"

    printf "  出口 IP   ... "
    local ip
    ip=$(curl -s --proxy "$proxy" \
         --connect-timeout 8 https://api.ipify.org 2>/dev/null || true)
    if [[ -n "$ip" ]]; then
        echo "$(_green "$ip")"
    else
        echo "$(_yellow "获取失败")"
    fi
}
