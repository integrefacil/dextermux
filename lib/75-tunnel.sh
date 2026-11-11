# shellcheck shell=bash
# 75-tunnel - Cloudflare quick tunnel sob demanda

write_tunnel_mode() {
    mkdir -p "$H/.dextermux"
    printf '%s\n' "$TUNNEL_MODE" >"$H/.dextermux/tunnel"
}

write_tunnel_command() {
    cat >"$H/.dextermux/tunnel.sh" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
# Gerado por dextermux. Liga, desliga e mostra o tunel Cloudflare.
set -eu
DIR="$HOME/.dextermux"
MODE="$DIR/tunnel"

tls_on() { [ "$(cat "$DIR/tls/mode" 2>/dev/null || echo 0)" = "1" ]; }

url() {
    grep -oE "https://[a-z0-9-]+\.trycloudflare\.com" "$TMPDIR/cf.log" 2>/dev/null | tail -1 \
        || cat "$HOME/tunnel-url.txt" 2>/dev/null \
        || true
}

start() {
    echo 1 >"$MODE"
    if pgrep -f "[c]loudflared tunnel" >/dev/null; then
        echo "tunel ja estava ativo"
    else
        if tls_on; then
            setsid cloudflared tunnel --url https://localhost:6080 --no-tls-verify --no-autoupdate \
                >"$TMPDIR/cf.log" 2>&1 </dev/null &
        else
            setsid cloudflared tunnel --url http://localhost:6080 --no-autoupdate \
                >"$TMPDIR/cf.log" 2>&1 </dev/null &
        fi
        echo "abrindo tunel..."
        sleep 15
    fi
    U=$(url)
    [ -n "$U" ] && echo "$U" >"$HOME/tunnel-url.txt"
    echo "publico: ${U:-abrindo (veja: tunnel status)}"
    "$HOME/show-access.sh"
}

stop() {
    echo 0 >"$MODE"
    pkill -f "[c]loudflared tunnel" 2>/dev/null || true
    echo "tunel desligado"
    "$HOME/show-access.sh"
}

status() {
    if pgrep -f "[c]loudflared tunnel" >/dev/null; then
        echo "tunel: ativo"
        U=$(url)
        [ -n "$U" ] && echo "url: $U/vnc.html"
    else
        echo "tunel: desligado"
    fi
}

case "${1:-status}" in
    on) start ;;
    off) stop ;;
    status) status ;;
    url)
        U=$(url)
        if [ -n "$U" ]; then
            echo "$U/vnc.html"
        else
            echo "sem url; rode: tunnel on" >&2
            exit 1
        fi
        ;;
    *)
        echo "uso: tunnel [on|off|status|url]" >&2
        exit 1
        ;;
esac
EOF
    chmod +x "$H/.dextermux/tunnel.sh"
    ln -sf "$H/.dextermux/tunnel.sh" "$P/bin/tunnel"
}
