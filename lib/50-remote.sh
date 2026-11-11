# shellcheck shell=bash
# 50-remote - Xvnc, noVNC, TLS, tunel e bloco de acesso

write_start_desktop() {
    cat >"$H/start-desktop.sh" <<'EOF'
#!/data/data/com.termux/files/usr/bin/sh
# Gerado por dextermux. Sobe sshd, Xvnc, websockify e cloudflared (se ligado).
DIR="$HOME/.dextermux"
PORT=6080
VNCPORT=5901
mkdir -p "$DIR"

termux-wake-lock 2>/dev/null || true
pgrep -f "sshd" >/dev/null || setsid sshd

if ! pgrep -f "[X]vnc :1" >/dev/null; then
    rm -f "$TMPDIR/.X1-lock" "$TMPDIR/.X11-unix/X1" "$HOME/.vnc/"*:1.pid 2>/dev/null || true
fi

vncserver :1 -geometry __GEOMETRY__ -depth 24 -localhost no -SecurityTypes VncAuth 2>/dev/null
sleep 2

TLS=$(cat "$DIR/tls/mode" 2>/dev/null || echo 0)
if [ "$TLS" = "1" ] && [ -x "$DIR/tls.sh" ]; then
    "$DIR/tls.sh" ensure >/dev/null 2>&1 || true
fi

WS_ARGS=""
WANT_TLS=0
if [ "$TLS" = "1" ] && [ -s "$DIR/tls/server.crt" ]; then
    WS_ARGS="--cert=$DIR/tls/server.crt --key=$DIR/tls/server.key --ssl-only"
    WANT_TLS=1
fi

WS_PID=$(pgrep -f "[w]ebsockify.*$PORT" | head -1 || true)
if [ -n "$WS_PID" ]; then
    WS_CMD=$(tr '\0' ' ' <"/proc/$WS_PID/cmdline" 2>/dev/null || echo "")
    WS_TLS=0
    case "$WS_CMD" in
        *--ssl-only*) WS_TLS=1 ;;
    esac
    if [ "$WS_TLS" != "$WANT_TLS" ]; then
        echo "reiniciando websockify no modo TLS=$WANT_TLS"
        kill "$WS_PID" 2>/dev/null || true
        sleep 1
        WS_PID=""
    fi
fi

if [ -z "$WS_PID" ]; then
    # shellcheck disable=SC2086
    setsid websockify --web="$HOME/noVNC" $WS_ARGS "$PORT" "localhost:$VNCPORT" >"$TMPDIR/ws-$PORT.log" 2>&1 </dev/null &
fi
sleep 2

TUNNEL=$(cat "$DIR/tunnel" 2>/dev/null || echo 0)
CF_PID=$(pgrep -f "[c]loudflared tunnel" | head -1 || true)
if [ -n "$CF_PID" ]; then
    CF_CMD=$(tr '\0' ' ' <"/proc/$CF_PID/cmdline" 2>/dev/null || echo "")
    CF_TLS=0
    case "$CF_CMD" in
        *https://localhost:6080*) CF_TLS=1 ;;
    esac
    if [ "$TUNNEL" != "1" ] || [ "$CF_TLS" != "$WANT_TLS" ]; then
        kill "$CF_PID" 2>/dev/null || true
        sleep 1
        CF_PID=""
    fi
fi

if [ "$TUNNEL" = "1" ] && [ -z "$CF_PID" ]; then
    if [ "$WANT_TLS" = "1" ]; then
        setsid cloudflared tunnel --url https://localhost:6080 --no-tls-verify --no-autoupdate >"$TMPDIR/cf.log" 2>&1 </dev/null &
    else
        setsid cloudflared tunnel --url http://localhost:6080 --no-autoupdate >"$TMPDIR/cf.log" 2>&1 </dev/null &
    fi
    sleep 15
    grep -oE "https://[a-z0-9-]+\.trycloudflare\.com" "$TMPDIR/cf.log" | tail -1 >"$HOME/tunnel-url.txt"
fi

if [ "$TUNNEL" = "1" ]; then
    echo "VNC $VNCPORT | noVNC $PORT | tunel: $(cat "$HOME/tunnel-url.txt" 2>/dev/null || echo abrindo)"
else
    echo "VNC $VNCPORT | noVNC $PORT | tunel: desligado"
fi
EOF
    sed -i "s/__GEOMETRY__/$GEOMETRY/g" "$H/start-desktop.sh"
    chmod +x "$H/start-desktop.sh"
    ln -sf "$H/start-desktop.sh" "$P/bin/desktop"
}

write_show_access() {
    cat >"$H/show-access.sh" <<'EOF'
#!/data/data/com.termux/files/usr/bin/sh
# Gerado por dextermux. Bloco de acesso.
IP=$(ifconfig 2>/dev/null | sed -n '/^wlan0/,/^$/s/.*inet \([0-9.]*\).*/\1/p' | head -1)
[ -z "$IP" ] && IP="IP-DO-CELULAR"
MODE=$(cat "$HOME/.dextermux/desktop" 2>/dev/null || echo cinnamon)
TLS=$(cat "$HOME/.dextermux/tls/mode" 2>/dev/null || echo 0)
if [ "$TLS" = "1" ]; then SCHEME=https; else SCHEME=http; fi
PASS=$(cat "$HOME/.dextermux/password" 2>/dev/null || echo "(use password)")

echo ""
echo "=== Acesso remoto ==="
echo "Desktop:      $MODE"
echo "SSH:          ssh -p 8022 $(whoami)@$IP"
if [ -s "$HOME/.ssh/authorized_keys" ]; then
    echo "Chaves SSH:   $(grep -c '^ssh-\|^ecdsa-' "$HOME/.ssh/authorized_keys" 2>/dev/null || echo 0) autorizada(s)"
fi
if pgrep -f "[X]vnc :1" >/dev/null; then
    echo "VNC local:    vnc://$IP:5901"
else
    echo "VNC:          parado (rode: desktop)"
fi
if pgrep -f "[w]ebsockify" >/dev/null; then
    echo "noVNC local:  $SCHEME://$IP:6080/vnc.html"
else
    echo "noVNC:        parado (rode: desktop)"
fi
U=$(grep -oE "https://[a-z0-9-]+\.trycloudflare\.com" "$TMPDIR/cf.log" 2>/dev/null | tail -1)
[ -z "$U" ] && U=$(cat "$HOME/tunnel-url.txt" 2>/dev/null)
if pgrep -f "[c]loudflared tunnel" >/dev/null; then
    echo "Publico:      ${U:-abrindo...}/vnc.html"
else
    echo "Publico:      desligado (rode: tunnel on)"
fi
echo "Senha:        $PASS"
echo "=========="
echo ""
EOF
    chmod +x "$H/show-access.sh"
    ln -sf "$H/show-access.sh" "$P/bin/url"
}

write_tls_helper() {
    mkdir -p "$H/.dextermux/tls"
    cat >"$H/.dextermux/tls.sh" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
# Gerado por dextermux. Certificado TLS autoassinado da LAN.
set -eu
DIR="$HOME/.dextermux/tls"
CERT="$DIR/server.crt"
KEY="$DIR/server.key"
MODE="$DIR/mode"
mkdir -p "$DIR"

lan_ip() {
    ifconfig 2>/dev/null | sed -n '/^wlan0/,/^$/s/.*inet \([0-9.]*\) .*/\1/p' | head -1
}

sans() {
    local ip list
    list="DNS:localhost,DNS:dextermux,IP:127.0.0.1"
    ip=$(lan_ip)
    [ -n "$ip" ] && list="$list,IP:$ip"
    printf '%s\n' "$list"
}

enabled() { [ "$(cat "$MODE" 2>/dev/null || echo 0)" = "1" ]; }

stop_tls_services() {
    pkill -f "[w]ebsockify" 2>/dev/null || true
    pkill -f "[c]loudflared tunnel" 2>/dev/null || true
    sleep 1
}

generate() {
    command -v openssl >/dev/null 2>&1 || { echo "openssl ausente" >&2; return 1; }
    local san
    san=$(sans)
    rm -f "$CERT" "$KEY"
    openssl req -x509 -newkey rsa:2048 -sha256 -days 825 -nodes \
        -keyout "$KEY" -out "$CERT" \
        -subj "/CN=dextermux" \
        -addext "subjectAltName=$san" \
        -addext "basicConstraints=critical,CA:FALSE" \
        -addext "keyUsage=critical,digitalSignature,keyEncipherment" \
        -addext "extendedKeyUsage=serverAuth" >/dev/null 2>&1
    chmod 600 "$KEY"
    chmod 644 "$CERT"
    printf '%s\n' "$san" >"$DIR/sans"
    echo "certificado gerado para $san"
}

ensure() {
    local want have
    want=$(sans)
    have=$(cat "$DIR/sans" 2>/dev/null || echo "")
    if [ ! -s "$CERT" ] || [ ! -s "$KEY" ] || [ "$want" != "$have" ]; then
        generate
        return 0
    fi
    if ! openssl x509 -checkend 2592000 -noout -in "$CERT" >/dev/null 2>&1; then
        echo "certificado expira em menos de 30 dias; renovando"
        generate
    fi
}

show() {
    if [ ! -s "$CERT" ]; then
        echo "sem certificado; rode: tls renew"
        return 0
    fi
    if enabled; then echo "modo: https"; else echo "modo: http"; fi
    echo "cert: $CERT"
    echo "key:  $KEY"
    openssl x509 -in "$CERT" -noout -subject -dates 2>/dev/null || true
    openssl x509 -in "$CERT" -noout -ext subjectAltName 2>/dev/null | tail -1 || true
}

case "${1:-ensure}" in
    ensure) if enabled; then ensure; fi ;;
    renew) generate ;;
    enable)
        echo 1 >"$MODE"
        ensure || true
        stop_tls_services
        echo "HTTPS ligado; rode 'desktop' para subir os servicos"
        ;;
    disable)
        echo 0 >"$MODE"
        stop_tls_services
        echo "HTTPS desligado; rode 'desktop' para subir os servicos"
        ;;
    mode) if enabled; then echo https; else echo http; fi ;;
    show) show ;;
    *)
        echo "uso: tls [ensure|renew|enable|disable|mode|show]" >&2
        exit 1
        ;;
esac
EOF
    chmod +x "$H/.dextermux/tls.sh"
    ln -sf "$H/.dextermux/tls.sh" "$P/bin/tls"
    printf '%s\n' "$TLS_MODE" >"$H/.dextermux/tls/mode"
}

write_bashrc_block() {
    touch "$H/.bashrc"
    sed -i '/# dextermux-start/,/# dextermux-end/d' "$H/.bashrc"
    sed -i '/show-access.sh/d; /start-desktop.sh >\/dev\/null 2>&1/d' "$H/.bashrc"
    cat >>"$H/.bashrc" <<'EOF'
# dextermux-start
[ -f $HOME/show-access.sh ] && . $HOME/show-access.sh
# dextermux-end
EOF
}

write_boot_script() {
    mkdir -p "$H/.termux/boot"
    cat >"$H/.termux/boot/start-services.sh" <<'EOF'
#!/data/data/com.termux/files/usr/bin/sh
"$HOME/start-desktop.sh"
EOF
    chmod +x "$H/.termux/boot/start-services.sh"
}

write_novnc() {
    if [ -f "$H/noVNC/vnc.html" ]; then
        ok "noVNC ja presente"
        return 0
    fi
    rm -rf "$H/noVNC" "$H/noVNC-$NOVNC_VER"
    curl -fsSL "https://github.com/novnc/noVNC/archive/refs/tags/v$NOVNC_VER.tar.gz" \
        -o "$TMPDIR/novnc.tgz" 2>>"$LOG"
    tar xzf "$TMPDIR/novnc.tgz" -C "$H"
    mv "$H/noVNC-$NOVNC_VER" "$H/noVNC"
    ok "noVNC $NOVNC_VER instalado"
}

install_websockify() {
    step "websockify"
    if command -v websockify >/dev/null 2>&1 && websockify --help >/dev/null 2>&1; then
        info "websockify ja instalado"
        return 0
    fi
    info "instalando websockify para $(python3 --version 2>&1)"
    pip3 install --force-reinstall --no-deps -q websockify 2>&1 | tee -a "$LOG"
    if [ "${PIPESTATUS[0]}" -ne 0 ]; then
        die "falha ao instalar websockify"
    fi
}
