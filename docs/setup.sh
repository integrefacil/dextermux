#!/data/data/com.termux/files/usr/bin/bash
# dextermux - ambiente remoto no Termux, focado em XFCE4
#
# Instala e configura:
#   - XFCE4 minimo (xfwm4, painel, sessao, settings, xfconf, xfdesktop, thunar, terminal)
#   - TigerVNC (Xvnc) com VncAuth e resolucao configuravel
#   - noVNC + websockify com HTTPS autoassinado na LAN (porta 6080)
#   - sshd com chave publica opcional (porta 8022)
#   - Cloudflare quick tunnel (desligado por padrao)
#   - Banner com as URLs, comandos "desktop", "url", "dextermux-tls" e "dextermux-status"
#   - Autostart no boot via Termux:Boot
#
# Uso:
#   curl -fsSL <URL> | bash
#   bash setup.sh
#   bash setup.sh --tunnel --ssh-pubkey "ssh-ed25519 AAAA..."
#
# Flags:
#   --geometry=WxH         resolucao inicial (default 1600x900)
#   --password=PASS        senha do VNC (max. 8 caracteres)
#   --ssh-pubkey=KEY       chave publica para authorized_keys
#   --tunnel / --no-tunnel liga ou desliga o Cloudflare (default desligado)
#   --tls / --no-tls       HTTPS autoassinado na LAN (default ligado)
#   --repair               nao instala pacotes, apenas regrava configs e reinicia
#   --dry-run              mostra o plano e sai sem alterar nada
#   --version              versao do instalador
#   -h, --help             esta ajuda
#
# Variaveis de ambiente:
#   VNC_PASS, GEOMETRY, NOVNC_VER, SSH_PUBKEY, TUNNEL, TLS
#   DEXTERMUX_ASCII=1      desenha sem caracteres de caixa
#   DEXTERMUX_NO_UPDATE=1  pula "pkg update"
#
# O instalador nao faz perguntas. Tudo vem por flag ou variavel de ambiente.
# NAO usa xrdp: o pacote 0.10.6.1 do Termux tem bug de autenticacao
# ("Bugcheck; inconsistent auth result"). Use VNC/noVNC.

set -eu
export DEBIAN_FRONTEND=noninteractive
export APT_LISTCHANGES_FRONTEND=none

DEXTERMUX_VERSION="3.0.1"

P="${PREFIX:-/data/data/com.termux/files/usr}"
H="$HOME"
GEOMETRY="${GEOMETRY:-1600x900}"
NOVNC_VER="${NOVNC_VER:-1.5.0}"
TUNNEL="${TUNNEL:-0}"
TLS="${TLS:-1}"
SSH_PUBKEY="${SSH_PUBKEY:-}"
VNC_PASS="${VNC_PASS:-}"

MODE="install"
DRY_RUN=0
TOTAL_STEPS=13
STEP_NO=0
LOG="$H/dextermux-install.log"

# ---------------------------------------------------------------- interface

if [ -t 1 ] && [ "${TERM:-dumb}" != "dumb" ] && [ -z "${NO_COLOR:-}" ]; then
    C_RESET=$'\033[0m'
    C_B=$'\033[1m'
    C_DIM=$'\033[2m'
    C_ACC=$'\033[36m'
    C_OK=$'\033[32m'
    C_WARN=$'\033[33m'
    C_ERR=$'\033[31m'
else
    C_RESET=""
    C_B=""
    C_DIM=""
    C_ACC=""
    C_OK=""
    C_WARN=""
    C_ERR=""
fi

if [ "${DEXTERMUX_ASCII:-0}" = "1" ]; then
    RULE_CH="-"
else
    RULE_CH="─"
fi

rule() {
    printf '%s' "$C_DIM"
    printf "${RULE_CH}%.0s" {1..64}
    printf '%s\n' "$C_RESET"
}

section() {
    printf '\n%s%s%s\n' "$C_ACC$C_B" "$1" "$C_RESET"
    rule
}

row() {
    printf '  %s%-16s%s %s\n' "$C_DIM" "$1" "$C_RESET" "$2"
}

ok() { printf '  %sok%s   %s\n' "$C_OK" "$C_RESET" "$*"; }
warn() { printf '  %satencao%s %s\n' "$C_WARN" "$C_RESET" "$*"; }
err() { printf '  %serro%s %s\n' "$C_ERR" "$C_RESET" "$*"; }
info() { printf '  %s%s\n' "$C_DIM" "$*$C_RESET"; }

die() {
    err "$*"
    printf '\n%sInstalacao interrompida.%s\n' "$C_ERR" "$C_RESET" >&2
    exit 1
}

step() {
    STEP_NO=$((STEP_NO + 1))
    printf '\n%s[%02d/%02d]%s %s%s%s\n' \
        "$C_DIM" "$STEP_NO" "$TOTAL_STEPS" "$C_RESET" "$C_B" "$1" "$C_RESET"
    printf '[%02d/%02d] %s\n' "$STEP_NO" "$TOTAL_STEPS" "$1" >>"$LOG"
}

banner() {
    printf '\n%s%sdextermux %s%s\n' "$C_B" "$C_ACC" "$DEXTERMUX_VERSION" "$C_RESET"
    printf '%sXFCE4 remoto no Termux com VNC, noVNC e SSH.%s\n' "$C_DIM" "$C_RESET"
    rule
}

usage() {
    cat <<'TXT'
dextermux - XFCE4 remoto no Termux

Uso:
  curl -fsSL <URL> | bash
  bash setup.sh
  bash setup.sh --tunnel --ssh-pubkey "ssh-ed25519 AAAA..."

Flags:
  --geometry=WxH         resolucao inicial (default 1600x900)
  --password=PASS        senha do VNC (max. 8 caracteres)
  --ssh-pubkey=KEY       chave publica para authorized_keys
  --tunnel / --no-tunnel liga ou desliga o Cloudflare (default desligado)
  --tls / --no-tls       HTTPS autoassinado na LAN (default ligado)
  --repair               nao instala pacotes, apenas regrava configs e reinicia
  --dry-run              mostra o plano e sai sem alterar nada
  --version              versao do instalador
  -h, --help             esta ajuda

Variaveis de ambiente:
  VNC_PASS, GEOMETRY, NOVNC_VER, SSH_PUBKEY, TUNNEL, TLS
  DEXTERMUX_ASCII=1      desenha sem caracteres de caixa
  DEXTERMUX_NO_UPDATE=1  pula "pkg update"

O instalador nao faz perguntas.
TXT
}

# ---------------------------------------------------------------- sistema

detect_resources() {
    DEVICE_MODEL=$(getprop ro.product.model 2>/dev/null || echo "desconhecido")
    ANDROID_VER=$(getprop ro.build.version.release 2>/dev/null || echo "?")
    ANDROID_SDK=$(getprop ro.build.version.sdk 2>/dev/null || echo "?")
    ABI=$(getprop ro.product.cpu.abi 2>/dev/null || echo "?")
    CORES=$(nproc 2>/dev/null || grep -c '^processor' /proc/cpuinfo 2>/dev/null || echo 0)

    local total_kb avail_kb
    total_kb=$(awk '/^MemTotal:/{print $2}' /proc/meminfo 2>/dev/null || echo 0)
    avail_kb=$(awk '/^MemAvailable:/{print $2}' /proc/meminfo 2>/dev/null || echo 0)
    MEM_TOTAL_MB=$((total_kb / 1024))
    MEM_FREE_MB=$((avail_kb / 1024))

    DISK_FREE_MB=$(disk_free_mb "$HOME")
    PROC_COUNT=$(process_count)

    if curl -fsS -m 8 -o /dev/null "https://packages.termux.dev/" 2>/dev/null; then
        NET_PKG="ok"
    else
        NET_PKG="falhou"
    fi
    if curl -fsS -m 8 -o /dev/null "https://github.com/" 2>/dev/null; then
        NET_GH="ok"
    else
        NET_GH="falhou"
    fi

    EXISTING="nao"
    if [ -f "$H/start-desktop.sh" ] || [ -f "$H/.vnc/passwd" ]; then
        EXISTING="sim"
    fi
}

disk_free_mb() {
    local path="$1" kb
    kb=$(df -k "$path" 2>/dev/null | awk 'NR==2{print $4}')
    if [ -z "${kb:-}" ]; then
        kb=$(stat -f -c '%a' "$path" 2>/dev/null || echo 0)
        local bsize
        bsize=$(stat -f -c '%S' "$path" 2>/dev/null || echo 4096)
        kb=$((kb * bsize / 1024))
    fi
    printf '%s\n' "$((kb / 1024))"
}

process_count() {
    local n
    n=$(ps -u "$(id -u)" -o pid= 2>/dev/null | wc -l | tr -d ' ')
    if [ -z "$n" ] || [ "$n" = "0" ]; then
        n=0
        for d in /proc/[0-9]*; do
            if [ -d "$d" ] && [ -O "$d" ]; then n=$((n + 1)); fi
        done
    fi
    printf '%s\n' "${n:-0}"
}

process_verdict() {
    local n="$1"
    if [ "$n" -ge 30 ]; then
        printf 'critico'
    elif [ "$n" -ge 24 ]; then
        printf 'atencao'
    else
        printf 'ok'
    fi
}

print_resources() {
    banner
    section "Recursos do sistema"
    row "Aparelho" "$DEVICE_MODEL"
    row "Android" "$ANDROID_VER (SDK $ANDROID_SDK)"
    row "Arquitetura" "$ABI"
    row "Nucleos" "$CORES"
    row "Memoria" "$MEM_TOTAL_MB MB total, $MEM_FREE_MB MB livre"
    row "Armazenamento" "$DISK_FREE_MB MB livres em \$HOME"
    row "Rede (pacotes)" "$NET_PKG"
    row "Rede (github)" "$NET_GH"
    row "Processos" "$PROC_COUNT ($(process_verdict "$PROC_COUNT"))"
    row "Instalacao" "$EXISTING"
}

# ---------------------------------------------------------------- pacotes

PKGS_BASE="tigervnc openssh openssl-tool python net-tools cloudflared curl tar dbus"
PKGS_XFCE="xfwm4 xfce4-panel xfce4-session xfce4-settings xfconf xfdesktop thunar xfce4-terminal ttf-dejavu"

pkg_installed() {
    dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q "install ok installed"
}

install_pkgs() {
    local missing="" p
    for p in "$@"; do
        pkg_installed "$p" || missing="$missing $p"
    done
    missing="${missing# }"
    if [ -z "$missing" ]; then
        info "ja instalado: $*"
        return 0
    fi
    info "instalando: $missing"
    # --force-confold evita prompt de conffile (ex: openssl.cnf) com stdin fechado
    # shellcheck disable=SC2086
    pkg install -y \
        -o Dpkg::Options::=--force-confdef \
        -o Dpkg::Options::=--force-confold \
        $missing </dev/null 2>&1 | tee -a "$LOG"
    if [ "${PIPESTATUS[0]}" -ne 0 ]; then
        die "falha ao instalar: $missing"
    fi
}

# ---------------------------------------------------------------- arquivos

write_xstartup() {
    mkdir -p "$H/.vnc"
    cat >"$H/.vnc/xstartup" <<'EOF'
#!/data/data/com.termux/files/usr/bin/sh
# Gerado por dextermux. Sessao XFCE4 unica.
unset SESSION_MANAGER
export PATH="/data/data/com.termux/files/usr/bin:$PATH"
export XDG_RUNTIME_DIR="$TMPDIR"
# evita at-spi e daemons de acessibilidade
export NO_AT_BRIDGE=1
export GTK_A11Y=none

if [ -z "$DBUS_SESSION_BUS_ADDRESS" ] && command -v dbus-launch >/dev/null 2>&1; then
    eval "$(dbus-launch --sh-syntax --exit-with-session)" 2>/dev/null || true
fi

exec startxfce4
EOF
    chmod +x "$H/.vnc/xstartup"
}

write_start_desktop() {
    cat >"$H/start-desktop.sh" <<'EOF'
#!/data/data/com.termux/files/usr/bin/sh
# Gerado por dextermux. Uso: start-desktop.sh
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
# Gerado por dextermux. Mostra IP, portas, TLS, tunel e estado dos servicos.
IP=$(ifconfig 2>/dev/null | sed -n '/^wlan0/,/^$/s/.*inet \([0-9.]*\).*/\1/p' | head -1)
[ -z "$IP" ] && IP="IP-DO-CELULAR"
TLS=$(cat "$HOME/.dextermux/tls/mode" 2>/dev/null || echo 0)
if [ "$TLS" = "1" ]; then SCHEME=https; else SCHEME=http; fi

echo ""
echo "=== Acesso remoto ==="
echo "Desktop:      XFCE4"
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
    echo "Publico:      desligado (rode: desktop com --tunnel)"
fi
echo "======================"
echo ""
EOF
    chmod +x "$H/show-access.sh"
    ln -sf "$H/show-access.sh" "$P/bin/url"
}

write_tls_helper() {
    mkdir -p "$H/.dextermux"
    cat >"$H/.dextermux/tls.sh" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
# Gerado por dextermux. Certificado TLS autoassinado para a LAN.
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
    if [ -n "$ip" ]; then
        list="$list,IP:$ip"
    fi
    printf '%s\n' "$list"
}

enabled() {
    [ "$(cat "$MODE" 2>/dev/null || echo 0)" = "1" ]
}

stop_services() {
    pkill -f "[w]ebsockify" 2>/dev/null || true
    pkill -f "[c]loudflared tunnel" 2>/dev/null || true
    sleep 1
}

generate() {
    if ! command -v openssl >/dev/null 2>&1; then
        echo "openssl ausente; instale openssl-tool" >&2
        return 1
    fi
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
        echo "sem certificado; rode: dextermux-tls renew"
        return 0
    fi
    if enabled; then echo "modo: https"; else echo "modo: http"; fi
    echo "cert: $CERT"
    echo "key:  $KEY"
    openssl x509 -in "$CERT" -noout -subject -dates 2>/dev/null || true
    openssl x509 -in "$CERT" -noout -ext subjectAltName 2>/dev/null | tail -1 || true
    echo "Para evitar o aviso do navegador, instale o cert como autoridade no cliente."
}

case "${1:-ensure}" in
    ensure)
        if enabled; then ensure; fi
        ;;
    renew) generate ;;
    enable)
        echo 1 >"$MODE"
        ensure || true
        stop_services
        echo "HTTPS ligado; rode 'desktop' para subir os servicos"
        ;;
    disable)
        echo 0 >"$MODE"
        stop_services
        echo "HTTPS desligado; rode 'desktop' para subir os servicos"
        ;;
    mode)
        if enabled; then echo https; else echo http; fi
        ;;
    show) show ;;
    *)
        echo "uso: dextermux-tls [ensure|renew|enable|disable|mode|show]" >&2
        exit 1
        ;;
esac
EOF
    chmod +x "$H/.dextermux/tls.sh"
    ln -sf "$H/.dextermux/tls.sh" "$P/bin/dextermux-tls"
    mkdir -p "$H/.dextermux/tls"
    printf '%s\n' "$TLS" >"$H/.dextermux/tls/mode"
}

write_status_helper() {
    mkdir -p "$H/.dextermux"
    cat >"$H/.dextermux/status.sh" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
# Gerado por dextermux. Estado do ambiente e contagem de processos.
set -eu
H="$HOME"

count() {
    local n
    n=$(ps -u "$(id -u)" -o pid= 2>/dev/null | wc -l | tr -d ' ')
    if [ -z "$n" ] || [ "$n" = "0" ]; then
        n=0
        for d in /proc/[0-9]*; do
            if [ -d "$d" ] && [ -O "$d" ]; then n=$((n + 1)); fi
        done
    fi
    printf '%s\n' "${n:-0}"
}

verdict() {
    if [ "$1" -ge 30 ]; then
        printf 'critico'
    elif [ "$1" -ge 24 ]; then
        printf 'atencao'
    else
        printf 'ok'
    fi
}

N=$(count)
TLS=$(cat "$H/.dextermux/tls/mode" 2>/dev/null || echo 0)
TUNNEL=$(cat "$H/.dextermux/tunnel" 2>/dev/null || echo 0)

echo ""
echo "=== dextermux ==="
echo "Desktop:    XFCE4"
if [ "$TLS" = "1" ]; then echo "TLS:        https"; else echo "TLS:        http"; fi
if [ "$TUNNEL" = "1" ]; then echo "Tunel:      ligado"; else echo "Tunel:      desligado"; fi
if pgrep -f "[X]vnc :1" >/dev/null; then echo "VNC:        ativo"; else echo "VNC:        parado"; fi
if pgrep -f "[w]ebsockify" >/dev/null; then echo "noVNC:      ativo"; else echo "noVNC:      parado"; fi
echo "Processos:  $N / limite Android 32 ($(verdict "$N"))"
echo ""
echo "Top 5 por memoria:"
ps -u "$(id -u)" -o pid,rss,comm --sort=-rss 2>/dev/null | head -6 || true
echo ""
echo "Para elevar o limite (via PC com ADB):"
echo "  adb shell settings put global settings_enable_monitor_phantom_procs false"
echo "  adb shell device_config put activity_manager max_phantom_processes 2147483647"
echo "=================="
echo ""
EOF
    chmod +x "$H/.dextermux/status.sh"
    ln -sf "$H/.dextermux/status.sh" "$P/bin/dextermux-status"
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

write_ssh_key() {
    mkdir -p "$H/.ssh"
    chmod 700 "$H/.ssh"
    if [ -n "$SSH_PUBKEY" ]; then
        grep -qF "$SSH_PUBKEY" "$H/.ssh/authorized_keys" 2>/dev/null || echo "$SSH_PUBKEY" >>"$H/.ssh/authorized_keys"
        chmod 600 "$H/.ssh/authorized_keys"
        ok "chave adicionada em ~/.ssh/authorized_keys"
    else
        info "sem chave: use ssh-copy-id -p 8022 <usuario>@<ip> de outro PC"
    fi
}

write_vnc_password() {
    if [ -z "$VNC_PASS" ] && [ -f "$H/.vnc/passwd" ]; then
        ok "mantendo a senha existente em ~/.vnc/passwd"
        return 0
    fi
    if [ -z "$VNC_PASS" ]; then
        VNC_PASS=$(head -c 256 /dev/urandom | tr -dc 'A-Za-z0-9' | head -c 8 || true)
    fi
    if [ "${#VNC_PASS}" -gt 8 ]; then
        warn "senha maior que 8 caracteres; o VncAuth usa apenas os 8 primeiros"
        VNC_PASS=$(printf '%s' "$VNC_PASS" | cut -c1-8)
    fi
    mkdir -p "$H/.vnc"
    printf '%s' "$VNC_PASS" | vncpasswd -f >"$H/.vnc/passwd"
    chmod 600 "$H/.vnc/passwd"
    ok "senha do VNC definida"
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

write_modes() {
    mkdir -p "$H/.dextermux/tls"
    printf '%s\n' "$TLS" >"$H/.dextermux/tls/mode"
    printf '%s\n' "$TUNNEL" >"$H/.dextermux/tunnel"
}

# ---------------------------------------------------------------- instalacao

run_packages() {
    step "Atualizando indices"
    if [ "${DEXTERMUX_NO_UPDATE:-0}" = "1" ]; then
        info "pulado (DEXTERMUX_NO_UPDATE=1)"
    else
        pkg update -y 2>&1 | tee -a "$LOG" || warn "pkg update retornou erro; seguindo"
    fi

    step "Repositorio x11"
    install_pkgs x11-repo
    pkg update -y 2>&1 | tee -a "$LOG" || warn "pkg update retornou erro; seguindo"

    step "Pacotes pendentes"
    if [ -n "$(dpkg --audit 2>/dev/null)" ]; then
        info "corrigindo pacotes pendentes"
        dpkg --force-confdef --force-confold --configure -a 2>&1 | tee -a "$LOG" || true
    else
        info "nenhum pacote pendente"
    fi

    step "Pacotes base"
    # shellcheck disable=SC2086
    install_pkgs $PKGS_BASE

    step "XFCE4 minimo"
    # shellcheck disable=SC2086
    install_pkgs $PKGS_XFCE
}

run_install() {
    mkdir -p "$H/.dextermux"
    : >"$LOG"
    printf 'dextermux %s - %s\n' "$DEXTERMUX_VERSION" "$(date)" >>"$LOG"
    printf 'tunnel=%s tls=%s geometry=%s\n' "$TUNNEL" "$TLS" "$GEOMETRY" >>"$LOG"

    run_packages

    step "websockify"
    if command -v websockify >/dev/null 2>&1; then
        info "websockify ja instalado"
    else
        pip3 install --no-deps -q websockify 2>&1 | tee -a "$LOG"
        if [ "${PIPESTATUS[0]}" -ne 0 ]; then
            die "falha ao instalar websockify"
        fi
    fi

    step "noVNC"
    write_novnc

    step "Senha do VNC"
    write_vnc_password

    step "Configuracoes"
    write_modes
    write_xstartup

    step "Scripts de operacao"
    write_start_desktop
    write_show_access
    write_tls_helper
    write_status_helper

    step "Banner do shell"
    write_bashrc_block

    step "Autostart no boot"
    write_boot_script

    step "Chave SSH"
    write_ssh_key

    step "Certificado TLS"
    if [ "$TLS" = "1" ]; then
        "$H/.dextermux/tls.sh" ensure || warn "falha ao gerar o certificado; a LAN seguira em HTTP"
    else
        info "HTTPS na LAN desligado"
    fi

    step "Subindo servicos"
    "$H/start-desktop.sh" 2>&1 | tee -a "$LOG" || warn "servicos iniciaram com avisos; veja $LOG"

    step "Limpando cache"
    pkg clean >/dev/null 2>&1 || true
    ok "cache do pkg limpo"
}

repair_only() {
    TOTAL_STEPS=8
    : >"$LOG"
    printf 'dextermux %s - reparo %s\n' "$DEXTERMUX_VERSION" "$(date)" >>"$LOG"
    step "Configuracoes"
    write_modes
    write_xstartup
    step "Scripts de operacao"
    write_start_desktop
    write_show_access
    write_tls_helper
    write_status_helper
    step "Banner do shell"
    write_bashrc_block
    step "Autostart no boot"
    write_boot_script
    step "Certificado TLS"
    if [ "$TLS" = "1" ]; then
        "$H/.dextermux/tls.sh" ensure || warn "falha ao gerar o certificado"
    fi
    step "Reiniciando servicos"
    vncserver -kill :1 >/dev/null 2>&1 || true
    pkill -f "[w]ebsockify" 2>/dev/null || true
    pkill -f "[c]loudflared tunnel" 2>/dev/null || true
    sleep 1
    rm -f "$TMPDIR/.X1-lock" "$TMPDIR/.X11-unix/X1" "$H/.vnc/"*:1.pid 2>/dev/null || true
    "$H/start-desktop.sh" 2>&1 | tee -a "$LOG" || warn "servicos iniciaram com avisos"
    step "Verificacao"
    local n
    n=$(process_count)
    row "Processos" "$n ($(process_verdict "$n"))"
}

# ---------------------------------------------------------------- resumo

print_summary() {
    local ip public scheme count verdict
    ip=$(ifconfig 2>/dev/null | sed -n '/^wlan0/,/^$/s/.*inet \([0-9.]*\).*/\1/p' | head -1)
    [ -z "$ip" ] && ip="<ip>"
    public=$(cat "$H/tunnel-url.txt" 2>/dev/null || echo "desligado")
    if [ "$TLS" = "1" ]; then scheme=https; else scheme=http; fi
    count=$(process_count)
    verdict=$(process_verdict "$count")

    section "Resumo"
    row "Usuario" "$(whoami)"
    row "Desktop" "XFCE4"
    row "VNC local" "vnc://$ip:5901"
    row "noVNC local" "$scheme://$ip:6080/vnc.html"
    row "Tunel publico" "$public"
    row "Senha VNC" "${VNC_PASS:-(a existente em ~/.vnc/passwd)}"
    row "Certificado" "$H/.dextermux/tls/server.crt"
    row "Processos" "$count / 32 ($verdict)"
    row "Log" "$LOG"

    section "Comandos"
    printf '  %-22s %s\n' "desktop" "sobe sshd, Xvnc, websockify e o tunel (se ligado)"
    printf '  %-22s %s\n' "url" "mostra IP, portas e estado"
    printf '  %-22s %s\n' "dextermux-status" "processos, top 5, TLS e tunel"
    printf '  %-22s %s\n' "dextermux-tls show" "certificado e SANs"
    printf '  %-22s %s\n' "dextermux-tls renew" "regenera o certificado"

    section "Pendencias manuais"
    printf '  1. Instalar o app Termux:Boot (F-Droid/GitHub) e abrir uma vez.\n'
    printf '  2. Samsung: Configuracoes > Aplicativos > Termux > Bateria > Sem restricoes.\n'
    printf '     Bateria > Limites de uso em segundo plano > Apps que nunca dormem > Termux.\n'
    printf '     Remover Termux de "Apps em suspensao" e "em suspensao profunda".\n'
    printf '  3. Reservar o IP do celular no roteador para nao mudar.\n'
    printf '  4. Se quiser senha do usuario: passwd\n'
    if [ "$TLS" = "1" ]; then
        printf '  5. No primeiro acesso https, aceite o certificado autoassinado no navegador.\n'
    fi
    printf '  6. Android 12+ mata o app acima de 32 processos (phantom process killer).\n'
    printf '     Use dextermux-status para medir; os comandos ADB estao no README.\n'
    if [ "$TUNNEL" = "1" ]; then
        printf '  7. O tunel publico expoe o noVNC na internet; use senha forte.\n'
    fi
    rule
}

print_dry_run() {
    section "Plano (dry-run)"
    row "Desktop" "XFCE4 minimo"
    row "Tunel" "$([ "$TUNNEL" = "1" ] && echo ligado || echo desligado)"
    row "HTTPS LAN" "$([ "$TLS" = "1" ] && echo autoassinado || echo desligado)"
    row "Geometria" "$GEOMETRY"
    printf '\n  Pacotes base: %s\n' "$PKGS_BASE"
    printf '  Pacotes xfce: %s\n' "$PKGS_XFCE"
    printf '\n  Arquivos que seriam gravados:\n'
    printf '    ~/.vnc/xstartup\n    ~/.vnc/passwd\n    ~/start-desktop.sh\n'
    printf '    ~/show-access.sh\n    ~/.dextermux/tls.sh\n    ~/.dextermux/status.sh\n'
    printf '    ~/.dextermux/tunnel\n    ~/.dextermux/tls/{server.crt,server.key,mode}\n'
    printf '    ~/.termux/boot/start-services.sh\n    ~/.bashrc (bloco dextermux, banner)\n\n'
}

# ---------------------------------------------------------------- main

parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            -y|--yes) : ;;
            --desktop=*|--dev=*) : ;;
            --geometry=*) GEOMETRY="${1#*=}" ;;
            --password=*) VNC_PASS="${1#*=}" ;;
            --ssh-pubkey=*) SSH_PUBKEY="${1#*=}" ;;
            --tunnel) TUNNEL=1 ;;
            --no-tunnel) TUNNEL=0 ;;
            --tls) TLS=1 ;;
            --no-tls) TLS=0 ;;
            --repair) MODE="repair" ;;
            --dry-run) DRY_RUN=1 ;;
            -h|--help) usage; exit 0 ;;
            --version) printf '%s\n' "$DEXTERMUX_VERSION"; exit 0 ;;
            *) die "flag desconhecida: $1 (use --help)" ;;
        esac
        shift
    done
}

main() {
    parse_args "$@"

    if [ ! -d /data/data/com.termux/files/usr ] && [ "$DRY_RUN" = "0" ]; then
        die "rode este script dentro do Termux"
    fi

    detect_resources
    print_resources

    if [ "$DRY_RUN" = "1" ]; then
        print_dry_run
        exit 0
    fi

    if [ "$MODE" = "repair" ]; then
        repair_only
        print_summary
        exit 0
    fi

    run_install
    print_summary
}

if [ "${DEXTERMUX_LIB_ONLY:-0}" != "1" ]; then
    main "$@"
fi
