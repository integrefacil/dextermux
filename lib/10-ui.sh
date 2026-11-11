# shellcheck shell=bash
# 10-ui - interatividade, menus e parsing de flags

INTERACTIVE=1
MODE="install"
DRY_RUN=0
RESET_SCOPE=""

usage() {
    cat <<'TXT'
dextermux - desktop remoto no Termux (VNC + noVNC + TLS + SSH)

Uso:
  curl -fsSL <url> | bash
  bash setup.sh
  bash setup.sh --desktop=cinnamon --proot --tunnel

Flags:
  -y, --yes              nao pergunta nada; usa os padroes e nunca apaga
  --desktop=NAME         cinnamon (padrao) ou xfce
  --proot / --no-proot   Ubuntu opcional para apps glibc (default nao)
  --tunnel / --no-tunnel Cloudflare (default nao)
  --tls / --no-tls       HTTPS autoassinado na LAN (default ligado)
  --password=PASS        senha de VNC/noVNC/SSH (max. 8 caracteres)
  --ssh-pubkey=KEY       chave publica para authorized_keys
  --geometry=WxH         resolucao inicial (default 1600x900)
  --reset=artifacts      reinstala do zero apagando so os artefatos
  --reset=home           reinstala do zero apagando todo o $HOME
  --repair               regrava configs e reinicia, sem instalar pacotes
  --proot                instala apenas o Ubuntu (nao reinstala o resto)
  --dry-run              mostra o plano e sai
  --version              versao do instalador
  -h, --help             esta ajuda

Variaveis: VNC_PASS, GEOMETRY, NOVNC_VER, SSH_PUBKEY, TUNNEL, TLS, DESKTOP,
PROOT, DEXTERMUX_ASCII=1, DEXTERMUX_NO_UPDATE=1, DEXTERMUX_NO_UPGRADE=1.
TXT
}

open_tty() {
    if [ "$INTERACTIVE" != "1" ]; then return 0; fi
    if ( exec 3</dev/tty ) 2>/dev/null; then
        exec 3</dev/tty
    else
        INTERACTIVE=0
        warn "sem terminal interativo: usando os padroes"
    fi
}

ask() {
    local prompt="$1" default="${2:-}" answer
    if [ "$INTERACTIVE" != "1" ]; then printf '%s\n' "$default"; return 0; fi
    printf '  %s%s%s ' "$C_B" "$prompt" "$C_RESET" >&2
    read -r answer <&3 || answer=""
    [ -z "$answer" ] && answer="$default"
    printf '%s\n' "$answer"
}

ask_secret() {
    local prompt="$1" answer
    if [ "$INTERACTIVE" != "1" ]; then printf '%s\n' "${SHARED_PASS}"; return 0; fi
    printf '  %s%s%s ' "$C_B" "$prompt" "$C_RESET" >&2
    read -rs answer <&3 || answer=""
    printf '\n' >&2
    printf '%s\n' "$answer"
}

confirm() {
    local prompt="$1" default="${2:-n}" answer
    if [ "$INTERACTIVE" != "1" ]; then
        [ "$default" = "y" ]
        return $?
    fi
    printf '  %s%s [%s]: %s' "$C_B" "$prompt" "$([ "$default" = "y" ] && echo "S/n" || echo "s/N")" "$C_RESET" >&2
    read -r answer <&3 || answer=""
    [ -z "$answer" ] && answer="$default"
    case "$answer" in
        s|S|y|Y) return 0 ;;
        *) return 1 ;;
    esac
}

pause_screen() {
    if [ "$INTERACTIVE" = "1" ]; then
        printf '\n  %sEnter para continuar%s ' "$C_DIM" "$C_RESET"
        read -r _ <&3 || true
    fi
}

menu() {
    local title="$1"; shift
    local options=("$@") choice opt i=1
    section "$title" >&2
    for opt in "${options[@]}"; do
        printf '  %d  %s\n' "$i" "$opt" >&2
        i=$((i + 1))
    done
    choice=$(ask "Escolha [1-$#] (padrao 1):" "1")
    case "$choice" in
        ''|*[!0-9]*) printf '1\n' ;;
        *) printf '%s\n' "$choice" ;;
    esac
}

parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            -y|--yes) INTERACTIVE=0 ;;
            --desktop=*) DESKTOP="${1#*=}" ;;
            --geometry=*) GEOMETRY="${1#*=}" ;;
            --password=*) SHARED_PASS="${1#*=}" ;;
            --ssh-pubkey=*) SSH_PUBKEY="${1#*=}" ;;
            --tunnel) TUNNEL_MODE=1 ;;
            --no-tunnel) TUNNEL_MODE=0 ;;
            --tls) TLS_MODE=1 ;;
            --no-tls) TLS_MODE=0 ;;
            --proot) PROOT_WANTED=1; MODE="proot" ;;
            --no-proot) PROOT_WANTED=0 ;;
            --repair) MODE="repair" ;;
            --reset=artifacts) RESET_SCOPE="artifacts" ;;
            --reset=home) RESET_SCOPE="home" ;;
            --dry-run) DRY_RUN=1 ;;
            -h|--help) usage; exit 0 ;;
            --version) printf '%s\n' "$DEXTERMUX_VERSION"; exit 0 ;;
            *) die "flag desconhecida: $1 (use --help)" ;;
        esac
        shift
    done

    case "$DESKTOP" in
        cinnamon|xfce) ;;
        *) die "desktop invalido: $DESKTOP (cinnamon|xfce)" ;;
    esac
    case "$MODE" in
        install|repair|proot) ;;
        *) die "modo invalido" ;;
    esac
}
