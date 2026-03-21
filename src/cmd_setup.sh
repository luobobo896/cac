# ── cmd: setup ─────────────────────────────────────────────────

cmd_setup() {
    echo "=== cac setup ==="

    local tools=("claude" "codex" "gemini")
    local tool real_cmd found=0

    mkdir -p "$ENVS_DIR" "$CAC_DIR/bin"
    for tool in "${tools[@]}"; do
        real_cmd=$(_find_real_cmd "$tool")
        if [[ -n "$real_cmd" ]]; then
            echo "  真实 ${tool}：$real_cmd"
            echo "$real_cmd" > "$CAC_DIR/real_${tool}"
            _write_wrapper "$tool"
            echo "  ✓ wrapper    → $CAC_DIR/bin/${tool}"
            found=1
        else
            echo "  ⚠ 未找到 ${tool}，跳过该 wrapper"
            rm -f "$CAC_DIR/real_${tool}" "$CAC_DIR/bin/${tool}"
        fi
    done

    if [[ "$found" -eq 0 ]]; then
        echo "错误：未找到可接管 CLI（claude/codex/gemini）" >&2
        echo "请先安装至少一个 CLI 后重试 'cac setup'" >&2
        exit 1
    fi

    _write_ioreg_shim

    echo "  ✓ ioreg shim → $CAC_DIR/shim-bin/ioreg"
    echo
    echo "── 下一步 ──────────────────────────────────────────────"
    echo "1. 将以下两行加到 ~/.zshrc 最前面："
    echo
    echo "   export PATH=\"\$HOME/bin:\$PATH\"          # cac 命令"
    echo "   export PATH=\"$CAC_DIR/bin:\$PATH\"  # cli wrappers（claude/codex/gemini）"
    echo
    echo "2. source ~/.zshrc"
    echo
    echo "3. 添加第一个代理环境："
    echo "   cac add <名字> <host:port:user:pass>"
    echo "   cac add --socks5 <名字> <host:port:user:pass>"
}
