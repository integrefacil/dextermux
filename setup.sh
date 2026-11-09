#!/data/data/com.termux/files/usr/bin/bash
# dextermux - instalador do ambiente remoto no Termux
#
# Instala e configura:
#   - Diagnostico de recursos antes de qualquer download
#   - Interface interativa numerada (sem emojis, sem dependencias)
#   - Sessao grafica escolhida: Ubuntu-like (XFCE restilizado), Cinnamon, MATE ou nenhuma
#   - TigerVNC (Xvnc) com VncAuth, resolucao configuravel e accept-resize
#   - noVNC + websockify (navegador, porta 6080)
#   - Cloudflare quick tunnel (HTTPS publico, opcional)
#   - sshd + chave autorizada
#   - Banner com as URLs, comandos "url", "desktop", "dextermux-session" e "dextermux-theme"
#   - Autostart no boot (Termux:Boot)
#
# Uso interativo:
#   curl -fsSL <URL_RAW> -o setup.sh && bash setup.sh
#   bash <(curl -fsSL <URL_RAW>)
#   curl -fsSL <URL_RAW> | bash          # interativo se houver terminal; senao usa os padroes
#
# Uso nao interativo:
#   bash setup.sh --yes --desktop=ubuntu --dev=core,web
#   curl -fsSL <URL_RAW> | VNC_PASS=MinhaSen bash
#
# Flags:
#   -y, --yes              nao pergunta nada, usa os padroes
#   --desktop=NAME         ubuntu | cinnamon | mate | all | none
#   --dev=LIST             core,web,rust,go,java,db,browser (ou none)
#   --geometry=WxH         resolucao inicial (default 1600x900)
#   --password=PASS        senha do VNC (max. 8 caracteres)
#   --ssh-pubkey=KEY       chave publica para authorized_keys
#   --tunnel / --no-tunnel liga ou desliga o Cloudflare (default ligado)
#   --repair               nao instala pacotes, apenas regrava configs e reinicia
#   --dry-run              mostra o plano e sai sem alterar nada
#   --list                 lista presets, tamanhos e perfis
#   -h, --help             ajuda
#
# Variaveis de ambiente (compatibilidade):
#   VNC_PASS, GEOMETRY, NOVNC_VER, SSH_PUBKEY, TUNNEL
#   DEXTERMUX_ASCII=1      desenha sem caracteres de caixa
#   DEXTERMUX_NO_UPDATE=1  pula "pkg update"
#
# NAO usa xrdp: o pacote 0.10.6.1 do Termux tem bug de autenticacao
# ("Bugcheck; inconsistent auth result"). Use VNC/noVNC.

set -eu
export DEBIAN_FRONTEND=noninteractive

DEXTERMUX_VERSION="2.0.0"

P="${PREFIX:-/data/data/com.termux/files/usr}"
H="$HOME"
GEOMETRY="${GEOMETRY:-1600x900}"
NOVNC_VER="${NOVNC_VER:-1.5.0}"
TUNNEL="${TUNNEL:-1}"
SSH_PUBKEY="${SSH_PUBKEY:-}"
VNC_PASS="${VNC_PASS:-}"

DESKTOP="ubuntu"
DEV_GROUPS="core web"
MODE="install"
DRY_RUN=0
INTERACTIVE=1
TOTAL_STEPS=15
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

clear_screen() {
    if [ "$INTERACTIVE" = "1" ]; then
        printf '\033[2J\033[H'
    fi
}

step() {
    STEP_NO=$((STEP_NO + 1))
    printf '\n%s[%02d/%02d]%s %s%s%s\n' \
        "$C_DIM" "$STEP_NO" "$TOTAL_STEPS" "$C_RESET" "$C_B" "$1" "$C_RESET"
    printf '[%02d/%02d] %s\n' "$STEP_NO" "$TOTAL_STEPS" "$1" >>"$LOG"
}

banner() {
    printf '\n%s%sdextermux %s%s\n' "$C_B" "$C_ACC" "$DEXTERMUX_VERSION" "$C_RESET"
    printf '%sDesktop remoto no Termux com VNC, noVNC e tunel.%s\n' "$C_DIM" "$C_RESET"
    rule
}

usage() {
    cat <<'TXT'
dextermux - desktop remoto no Termux

Uso interativo:
  curl -fsSL <URL_RAW> -o setup.sh && bash setup.sh
  bash <(curl -fsSL <URL_RAW>)
  curl -fsSL <URL_RAW> | bash          # interativo se houver terminal; senao usa os padroes

Uso nao interativo:
  bash setup.sh --yes --desktop=ubuntu --dev=core,web

Flags:
  -y, --yes              nao pergunta nada, usa os padroes
  --desktop=NAME         ubuntu | cinnamon | mate | all | none
  --dev=LIST             core,web,rust,go,java,db,browser (ou none)
  --geometry=WxH         resolucao inicial (default 1600x900)
  --password=PASS        senha do VNC (max. 8 caracteres)
  --ssh-pubkey=KEY       chave publica para authorized_keys
  --tunnel / --no-tunnel liga ou desliga o Cloudflare (default ligado)
  --repair               nao instala pacotes, apenas regrava configs e reinicia
  --dry-run              mostra o plano e sai sem alterar nada
  --list                 lista presets, tamanhos e perfis
  -h, --help             esta ajuda

Variaveis de ambiente:
  VNC_PASS, GEOMETRY, NOVNC_VER, SSH_PUBKEY, TUNNEL
  DEXTERMUX_ASCII=1      desenha sem caracteres de caixa
  DEXTERMUX_NO_UPDATE=1  pula "pkg update"
TXT
}

# ---------------------------------------------------------------- entrada

open_tty() {
    if [ "$INTERACTIVE" != "1" ]; then
        return 0
    fi
    if ( exec 3</dev/tty ) 2>/dev/null; then
        exec 3</dev/tty
    else
        INTERACTIVE=0
        warn "sem terminal interativo: usando os padroes"
    fi
}

ask() {
    local prompt="$1" default="${2:-}" answer
    if [ "$INTERACTIVE" != "1" ]; then
        printf '%s\n' "$default"
        return 0
    fi
    printf '  %s%s%s ' "$C_B" "$prompt" "$C_RESET" >&2
    read -r answer <&3 || answer=""
    [ -z "$answer" ] && answer="$default"
    printf '%s\n' "$answer"
}

ask_secret() {
    local prompt="$1" answer
    if [ "$INTERACTIVE" != "1" ]; then
        printf '%s\n' "${VNC_PASS}"
        return 0
    fi
    printf '  %s%s%s ' "$C_B" "$prompt" "$C_RESET" >&2
    read -rs answer <&3 || answer=""
    printf '\n' >&2
    printf '%s\n' "$answer"
}

pause_screen() {
    if [ "$INTERACTIVE" = "1" ]; then
        printf '\n  %sEnter para continuar%s ' "$C_DIM" "$C_RESET"
        read -r _ <&3 || true
    fi
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

    if [ -f "$P/bin/pkg" ] || command -v pkg >/dev/null 2>&1; then
        TERMUX_STATE="ok"
    else
        TERMUX_STATE="ausente"
    fi

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

    INSTALLED_SESSIONS=$(session_installed_list)
    ACTIVE_SESSION=$(current_session)
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

session_installed_list() {
    local out=""
    command -v startxfce4 >/dev/null 2>&1 && out="$out ubuntu"
    command -v cinnamon-session >/dev/null 2>&1 && out="$out cinnamon"
    command -v mate-session >/dev/null 2>&1 && out="$out mate"
    printf '%s\n' "${out# }"
}

current_session() {
    cat "$H/.dextermux/session" 2>/dev/null || echo "ubuntu"
}

session_available() {
    case "$1" in
        ubuntu) command -v startxfce4 >/dev/null 2>&1 ;;
        cinnamon) command -v cinnamon-session >/dev/null 2>&1 ;;
        mate) command -v mate-session >/dev/null 2>&1 ;;
        *) return 1 ;;
    esac
}

# ---------------------------------------------------------------- tamanhos

SIZE_BASE=260
SIZE_UBUNTU=817
SIZE_CINNAMON=1691
SIZE_MATE=1345
SIZE_ALL=2256
SIZE_NONE=260
SIZE_DEV_CORE=255
SIZE_DEV_WEB=270
SIZE_DEV_RUST=1104
SIZE_DEV_GO=725
SIZE_DEV_JAVA=1365
SIZE_DEV_DB=296
SIZE_DEV_BROWSER=1278

desktop_size() {
    case "$1" in
        ubuntu) printf '%s\n' "$SIZE_UBUNTU" ;;
        cinnamon) printf '%s\n' "$SIZE_CINNAMON" ;;
        mate) printf '%s\n' "$SIZE_MATE" ;;
        all) printf '%s\n' "$SIZE_ALL" ;;
        *) printf '%s\n' "$SIZE_NONE" ;;
    esac
}

dev_size() {
    local total=0 g
    for g in $1; do
        case "$g" in
            core) total=$((total + SIZE_DEV_CORE)) ;;
            web) total=$((total + SIZE_DEV_WEB)) ;;
            rust) total=$((total + SIZE_DEV_RUST)) ;;
            go) total=$((total + SIZE_DEV_GO)) ;;
            java) total=$((total + SIZE_DEV_JAVA)) ;;
            db) total=$((total + SIZE_DEV_DB)) ;;
            browser) total=$((total + SIZE_DEV_BROWSER)) ;;
        esac
    done
    printf '%s\n' "$total"
}

dev_label() {
    case "$1" in
        core) printf 'Core CLI' ;;
        web) printf 'Web' ;;
        rust) printf 'Rust' ;;
        go) printf 'Go' ;;
        java) printf 'Java/Kotlin' ;;
        db) printf 'Bancos' ;;
        browser) printf 'Chromium' ;;
        *) printf '%s' "$1" ;;
    esac
}

dev_labels() {
    local out="" g
    for g in $1; do
        out="$out, $(dev_label "$g")"
    done
    printf '%s\n' "${out#, }"
}

estimated_total_mb() {
    local d
    d=$(desktop_size "$DESKTOP")
    if [ "$DESKTOP" = "none" ]; then
        d=$SIZE_BASE
    fi
    printf '%s\n' "$((d + $(dev_size "$DEV_GROUPS")))"
}

# ---------------------------------------------------------------- pacotes

PKGS_BASE="tigervnc openssh openssl-tool python net-tools cloudflared curl tar git"
PKGS_UBUNTU="xfce4 xfdesktop xfce4-whiskermenu-plugin rofi plank-reloaded arc-gtk-theme picom gnome-terminal gnome-text-editor gnome-calculator gnome-screenshot dbus gsettings-desktop-schemas ttf-dejavu"
PKGS_CINNAMON="cinnamon nemo cinnamon-session cinnamon-settings-daemon cinnamon-control-center mint-themes mint-y-icon-theme"
PKGS_MATE="mate mate-applet-brisk-menu mate-tweak"
PKGS_DEV_CORE="gh neovim tmux zsh starship ripgrep fd fzf jq lazygit eza bat zoxide htop micro rsync unzip wget"
PKGS_DEV_WEB="nodejs-lts php composer python-pip"
PKGS_DEV_RUST="rust"
PKGS_DEV_GO="golang"
PKGS_DEV_JAVA="openjdk-17 gradle kotlin clang make cmake android-tools"
PKGS_DEV_DB="mariadb postgresql sqlite redis nginx"
PKGS_DEV_BROWSER="chromium"

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
    # shellcheck disable=SC2086
    pkg install -y $missing 2>&1 | tee -a "$LOG"
    local st=${PIPESTATUS[0]}
    if [ "$st" -ne 0 ]; then
        die "falha ao instalar: $missing"
    fi
}

desktop_pkg_list() {
    case "$1" in
        ubuntu) printf '%s\n' "$PKGS_UBUNTU" ;;
        cinnamon) printf '%s\n' "$PKGS_CINNAMON" ;;
        mate) printf '%s\n' "$PKGS_MATE" ;;
        *) printf '\n' ;;
    esac
}

dev_pkg_list() {
    local out="" g
    for g in $1; do
        case "$g" in
            core) out="$out $PKGS_DEV_CORE" ;;
            web) out="$out $PKGS_DEV_WEB" ;;
            rust) out="$out $PKGS_DEV_RUST" ;;
            go) out="$out $PKGS_DEV_GO" ;;
            java) out="$out $PKGS_DEV_JAVA" ;;
            db) out="$out $PKGS_DEV_DB" ;;
            browser) out="$out $PKGS_DEV_BROWSER" ;;
        esac
    done
    printf '%s\n' "${out# }"
}

# ---------------------------------------------------------------- telas

screen_resources() {
    clear_screen
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
    row "Termux" "$TERMUX_STATE"
    if [ "$EXISTING" = "sim" ]; then
        row "Instalacao" "detectada (sessao: $ACTIVE_SESSION)"
    else
        row "Instalacao" "nenhuma"
    fi
    if [ -n "$INSTALLED_SESSIONS" ]; then
        row "Sessoes" "$INSTALLED_SESSIONS"
    fi

    section "Veredito"
    local need=1400
    if [ "$DISK_FREE_MB" -lt "$need" ]; then
        err "espaco insuficiente: $DISK_FREE_MB MB livres, minimo $need MB"
        info "libere espaco ou escolha 'Sem desktop' no menu seguinte"
    elif [ "$DISK_FREE_MB" -lt 3500 ]; then
        warn "espaco justo para o preset Ubuntu-like; 'Todas as tres' nao cabe"
    else
        ok "espaco suficiente para qualquer preset"
    fi
    if [ "$MEM_TOTAL_MB" -lt 2000 ]; then
        warn "memoria total baixa (${MEM_TOTAL_MB} MB); Cinnamon pode ficar lento"
    else
        ok "memoria adequada (${MEM_TOTAL_MB} MB)"
    fi
    if [ "$CORES" -lt 4 ]; then
        warn "poucos nucleos ($CORES); sessoes com compositor pesam"
    else
        ok "processamento adequado ($CORES nucleos)"
    fi
    if [ "$NET_PKG" != "ok" ] || [ "$NET_GH" != "ok" ]; then
        warn "rede instavel: a instalacao pode falhar no meio"
    fi

    pause_screen
}

screen_desktop() {
    local choice
    if [ "$INTERACTIVE" != "1" ]; then
        return 0
    fi
    while true; do
        clear_screen
        banner
        section "Ambiente grafico"
        printf '  1  %-38s %7s MB  %s\n' "Ubuntu-like (XFCE restilizado)" "~$SIZE_UBUNTU" "validado"
        printf '  2  %-38s %7s MB  %s\n' "Cinnamon (Mint-like)" "~$SIZE_CINNAMON" "experimental"
        printf '  3  %-38s %7s MB  %s\n' "MATE (classico)" "~$SIZE_MATE" "experimental"
        printf '  4  %-38s %7s MB  %s\n' "Todas as tres (avaliacao)" "~$SIZE_ALL" "recomendado agora"
        printf '  5  %-38s %7s MB  %s\n' "Sem desktop (so servidor)" "~$SIZE_NONE" "leve"
        printf '\n  %s1: sem painel XFCE, launcher de busca, dock e apps GNOME.%s\n' "$C_DIM" "$C_RESET"
        printf '  %s2/3: nao validados neste aparelho; o instalador registra falhas e cai para Ubuntu-like.%s\n' "$C_DIM" "$C_RESET"
        printf '  %s4: instala as tres e permite alternar com "dextermux-session".%s\n' "$C_DIM" "$C_RESET"
        choice=$(ask "Escolha [1-5] (padrao 1):" "1")
        case "$choice" in
            1) DESKTOP="ubuntu"; return 0 ;;
            2) DESKTOP="cinnamon"; return 0 ;;
            3) DESKTOP="mate"; return 0 ;;
            4) DESKTOP="all"; return 0 ;;
            5) DESKTOP="none"; return 0 ;;
            *) warn "opcao invalida"; sleep 1 ;;
        esac
    done
}

screen_dev() {
    local sel="${DEV_GROUPS:-}" choice g
    if [ "$INTERACTIVE" != "1" ]; then
        return 0
    fi
    while true; do
        clear_screen
        banner
        section "Ferramentas de desenvolvimento"
        printf '  Marque os grupos desejados. Enter confirma.\n\n'
        dev_line "$sel" core 1 "Core CLI (git, gh, neovim, tmux)" "~$SIZE_DEV_CORE MB"
        dev_line "$sel" web 2 "Web (Node, PHP, Composer, Python)" "~$SIZE_DEV_WEB MB"
        dev_line "$sel" rust 3 "Rust" "~$SIZE_DEV_RUST MB"
        dev_line "$sel" go 4 "Go" "~$SIZE_DEV_GO MB"
        dev_line "$sel" java 5 "Java, Kotlin, Gradle, clang, cmake" "~$SIZE_DEV_JAVA MB"
        dev_line "$sel" db 6 "Bancos (MariaDB, Postgres, Redis) e nginx" "~$SIZE_DEV_DB MB"
        dev_line "$sel" browser 7 "Chromium no desktop" "~$SIZE_DEV_BROWSER MB"
        printf '\n  %sDigite numeros separados (ex: 1 3), "a" tudo, "n" nada.%s\n' "$C_DIM" "$C_RESET"
        choice=$(ask "Selecao:" "")
        case "$choice" in
            "") DEV_GROUPS="$sel"; return 0 ;;
            a|A) sel="core web rust go java db browser" ;;
            n|N) sel="" ;;
            *)
                for g in $choice; do
                    case "$g" in
                        1) sel=$(toggle "$sel" core) ;;
                        2) sel=$(toggle "$sel" web) ;;
                        3) sel=$(toggle "$sel" rust) ;;
                        4) sel=$(toggle "$sel" go) ;;
                        5) sel=$(toggle "$sel" java) ;;
                        6) sel=$(toggle "$sel" db) ;;
                        7) sel=$(toggle "$sel" browser) ;;
                        *) warn "numero invalido: $g" ;;
                    esac
                done
                ;;
        esac
    done
}

dev_line() {
    printf '  %s %s  %-42s %10s\n' "$(mark "$1" "$2")" "$3" "$4" "$5"
}

# marca [x] ou [ ] para o grupo
mark() {
    local list="$1" item="$2" x
    for x in $list; do
        if [ "$x" = "$item" ]; then
            printf '[x]'
            return 0
        fi
    done
    printf '[ ]'
}

toggle() {
    local list="$1" item="$2" out="" x found=0
    for x in $list; do
        if [ "$x" = "$item" ]; then
            found=1
        else
            out="$out $x"
        fi
    done
    if [ "$found" = "0" ]; then
        out="$out $item"
    fi
    printf '%s\n' "${out# }"
}

screen_remote() {
    local answer
    if [ "$INTERACTIVE" != "1" ]; then
        return 0
    fi
    clear_screen
    banner
    section "Acesso remoto"

    if [ "$DESKTOP" = "none" ]; then
        TUNNEL=0
        printf '  Sem desktop: apenas sshd na porta 8022.\n\n'
        if [ -z "$SSH_PUBKEY" ]; then
            answer=$(ask "Chave publica SSH (Enter para pular):" "")
            SSH_PUBKEY="$answer"
        fi
        return 0
    fi

    printf '  Tunel publico do Cloudflare expoe o noVNC na internet.\n'
    printf '  A unica barreira e a senha de 8 caracteres do VNC.\n\n'
    answer=$(ask "Ligar tunel publico? [S/n]:" "$([ "$TUNNEL" = "1" ] && echo s || echo n)")
    case "$answer" in
        s|S|y|Y) TUNNEL=1 ;;
        *) TUNNEL=0 ;;
    esac

    if [ -z "$VNC_PASS" ] && [ ! -f "$H/.vnc/passwd" ]; then
        answer=$(ask_secret "Senha do VNC (Enter para gerar aleatoria):")
        if [ -n "$answer" ]; then
            VNC_PASS="$answer"
        fi
    fi

    answer=$(ask "Geometria inicial [1600x900]:" "$GEOMETRY")
    case "$answer" in
        [0-9]*x[0-9]*) GEOMETRY="$answer" ;;
        *) warn "geometria invalida, mantendo $GEOMETRY" ;;
    esac

    if [ -z "$SSH_PUBKEY" ]; then
        answer=$(ask "Chave publica SSH (Enter para pular):" "")
        SSH_PUBKEY="$answer"
    fi
}

screen_confirm() {
    local answer total free
    if [ "$INTERACTIVE" != "1" ]; then
        return 0
    fi
    total=$(estimated_total_mb)
    free=$DISK_FREE_MB
    while true; do
        clear_screen
        banner
        section "Resumo da instalacao"
        case "$DESKTOP" in
            ubuntu) row "Desktop" "Ubuntu-like (XFCE restilizado)" ;;
            cinnamon) row "Desktop" "Cinnamon (experimental)" ;;
            mate) row "Desktop" "MATE (experimental)" ;;
            all) row "Desktop" "Todas as tres sessoes" ;;
            *) row "Desktop" "nenhum" ;;
        esac
        if [ -n "$DEV_GROUPS" ]; then
            row "Dev" "$(dev_labels "$DEV_GROUPS")"
        else
            row "Dev" "nenhum"
        fi
        if [ "$DESKTOP" = "none" ]; then
            row "Tunel" "desligado"
            row "SSH" "sshd na 8022"
        else
            row "Tunel" "$([ "$TUNNEL" = "1" ] && echo ligado || echo desligado)"
            row "Geometria" "$GEOMETRY"
            row "Senha VNC" "$([ -n "$VNC_PASS" ] && echo definida || echo "manter/gerar")"
            row "Chave SSH" "$([ -n "$SSH_PUBKEY" ] && echo fornecida || echo nao)"
        fi
        row "Estimativa" "~$total MB de disco"
        row "Espaco livre" "$free MB"
        if [ "$total" -gt "$free" ]; then
            warn "estimativa maior que o espaco livre"
        fi
        printf '\n  1  Confirmar e instalar\n'
        printf '  2  Voltar e refazer as escolhas\n'
        printf '  3  Sair\n'
        answer=$(ask "Escolha [1-3] (padrao 1):" "1")
        case "$answer" in
            1) return 0 ;;
            2) return 1 ;;
            3) printf '  saindo.\n'; exit 0 ;;
            *) warn "opcao invalida" ;;
        esac
    done
}

# ---------------------------------------------------------------- arquivos

write_xstartup() {
    mkdir -p "$H/.vnc"
    cat >"$H/.vnc/xstartup" <<'EOF'
#!/data/data/com.termux/files/usr/bin/sh
# Gerado por dextermux. A sessao e lida de ~/.dextermux/session.
unset SESSION_MANAGER
export PATH="/data/data/com.termux/files/usr/bin:$PATH"
export XDG_RUNTIME_DIR="$TMPDIR"

DISP="${DISPLAY#:}"
SESSION=$(cat "$HOME/.dextermux/session.$DISP" 2>/dev/null || cat "$HOME/.dextermux/session" 2>/dev/null || echo ubuntu)
mkdir -p "$HOME/.dextermux"
echo "$SESSION" >"$HOME/.dextermux/running.$DISP"

if [ -z "$DBUS_SESSION_BUS_ADDRESS" ] && command -v dbus-launch >/dev/null 2>&1; then
    eval "$(dbus-launch --sh-syntax --exit-with-session)" 2>/dev/null || true
fi

case "$SESSION" in
    cinnamon) CMD=cinnamon-session ;;
    mate) CMD=mate-session ;;
    *) CMD=startxfce4 ;;
esac

if [ "$SESSION" = "ubuntu" ]; then
    export GTK_THEME=Arc-Dark
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null || true
    gsettings set org.gnome.desktop.interface gtk-theme 'Arc-Dark' 2>/dev/null || true
    xfconf-query -c xsettings -p /Gtk/FontName -n -t string -s "Ubuntu 10" 2>/dev/null || true
    xfconf-query -c xsettings -p /Xft/Antialias -n -t int -s 1 2>/dev/null || true
    xfconf-query -c xsettings -p /Xft/Hinting -n -t int -s 1 2>/dev/null || true
    xfconf-query -c xsettings -p /Xft/HintStyle -n -t string -s hintfull 2>/dev/null || true
    xfconf-query -c xsettings -p /Xft/RGBA -n -t string -s rgb 2>/dev/null || true
    ( sleep 2; setsid picom --config "$HOME/.config/picom.conf" >/dev/null 2>&1 & ) &
    ( sleep 3; setsid plank >/dev/null 2>&1 & ) &
fi

"$CMD" &
PID=$!
i=0
while [ $i -lt 15 ]; do
    kill -0 "$PID" 2>/dev/null || break
    i=$((i + 1))
    sleep 1
done
if kill -0 "$PID" 2>/dev/null; then
    wait "$PID"
else
    echo "$(date) sessao $SESSION falhou; usando ubuntu" >>"$TMPDIR/session.log"
    echo ubuntu >"$HOME/.dextermux/running.$DISP"
    exec startxfce4
fi
EOF
    chmod +x "$H/.vnc/xstartup"
}

write_start_desktop() {
    cat >"$H/start-desktop.sh" <<'EOF'
#!/data/data/com.termux/files/usr/bin/sh
# Gerado por dextermux. Uso: start-desktop.sh [display] [sessao]
DISP="${1:-1}"
SESSION="${2:-}"
PORT=$((6080 + DISP - 1))
VNCPORT=$((5900 + DISP))
DIR="$HOME/.dextermux"
mkdir -p "$DIR"

if [ -n "$SESSION" ]; then
    ACTIVE=$(cat "$DIR/running.$DISP" 2>/dev/null || echo "")
    if [ "$ACTIVE" != "$SESSION" ] && pgrep -f "[X]vnc :$DISP" >/dev/null; then
        echo "trocando :$DISP de ${ACTIVE:-desconhecida} para $SESSION"
        vncserver -kill :"$DISP" >/dev/null 2>&1 || true
        sleep 1
        rm -f "$TMPDIR/.X$DISP-lock" "$TMPDIR/.X11-unix/X$DISP" "$HOME/.vnc/"*:"$DISP".pid 2>/dev/null || true
    fi
    echo "$SESSION" >"$DIR/session.$DISP"
fi

EFFECTIVE=$(cat "$DIR/session.$DISP" 2>/dev/null || cat "$DIR/session" 2>/dev/null || echo ubuntu)
if [ "$EFFECTIVE" = "none" ]; then
    echo "sem desktop instalado; rode o setup e escolha uma sessao grafica"
    exit 1
fi

termux-wake-lock 2>/dev/null || true
pgrep -f "sshd" >/dev/null || setsid sshd

if ! pgrep -f "[X]vnc :$DISP" >/dev/null; then
    rm -f "$TMPDIR/.X$DISP-lock" "$TMPDIR/.X11-unix/X$DISP" "$HOME/.vnc/"*:"$DISP".pid 2>/dev/null || true
fi

vncserver :"$DISP" -geometry __GEOMETRY__ -depth 24 -localhost no -SecurityTypes VncAuth 2>/dev/null
sleep 2

for _ in 1 2 3 4 5; do
    DISPLAY=:"$DISP" xfconf-query -c xsettings -p /Xft/Antialias >/dev/null 2>&1 && break
    sleep 1
done

if ! pgrep -f "[w]ebsockify.*$PORT" >/dev/null; then
    setsid websockify --web="$HOME/noVNC" "$PORT" "localhost:$VNCPORT" >"$TMPDIR/ws-$PORT.log" 2>&1 </dev/null &
fi
sleep 2

# shellcheck disable=SC2050
if [ "$DISP" = "1" ] && [ "__TUNNEL__" = "1" ] && ! pgrep -f "[c]loudflared tunnel" >/dev/null; then
    setsid cloudflared tunnel --url http://localhost:6080 --no-autoupdate >"$TMPDIR/cf.log" 2>&1 </dev/null &
    sleep 15
    grep -oE "https://[a-z0-9-]+\.trycloudflare\.com" "$TMPDIR/cf.log" | tail -1 >"$HOME/tunnel-url.txt"
fi

echo "VNC $VNCPORT | noVNC $PORT | sessao: $(cat "$DIR/session.$DISP" 2>/dev/null || cat "$DIR/session" 2>/dev/null || echo ubuntu)"
EOF
    sed -i "s/__GEOMETRY__/$GEOMETRY/g; s/__TUNNEL__/$TUNNEL/g" "$H/start-desktop.sh"
    chmod +x "$H/start-desktop.sh"
    ln -sf "$H/start-desktop.sh" "$P/bin/desktop"
}

write_show_access() {
    cat >"$H/show-access.sh" <<'EOF'
#!/data/data/com.termux/files/usr/bin/sh
# Gerado por dextermux. Mostra IP, portas, sessao e estado dos servicos.
IP=$(ifconfig 2>/dev/null | sed -n '/^wlan0/,/^$/s/.*inet \([0-9.]*\).*/\1/p' | head -1)
[ -z "$IP" ] && IP="IP-DO-CELULAR"
SESSION=$(cat "$HOME/.dextermux/session" 2>/dev/null || echo ubuntu)

echo ""
echo "=== Acesso remoto ==="
echo "Sessao:       $SESSION"
if pgrep -f "[X]vnc :1" >/dev/null; then
    echo "VNC local:    vnc://$IP:5901"
else
    echo "VNC:          iniciando/parado (rode: desktop)"
fi
if pgrep -f "[w]ebsockify" >/dev/null; then
    echo "noVNC local:  http://$IP:6080/vnc.html"
else
    echo "noVNC:        iniciando/parado (rode: desktop)"
fi
U=$(grep -oE "https://[a-z0-9-]+\.trycloudflare\.com" "$TMPDIR/cf.log" 2>/dev/null | tail -1)
[ -z "$U" ] && U=$(cat "$HOME/tunnel-url.txt" 2>/dev/null)
if pgrep -f "[c]loudflared tunnel" >/dev/null; then
    echo "Publico:      ${U:-abrindo...}/vnc.html"
else
    echo "Publico:      ${U:+ultimo: }${U:-indisponivel} (rode: desktop)"
fi
if pgrep -f "[X]vnc :2" >/dev/null; then
    echo "Teste :2      http://$IP:6081/vnc.html"
fi
echo "======================"
echo ""
EOF
    chmod +x "$H/show-access.sh"
    ln -sf "$H/show-access.sh" "$P/bin/url"
}

write_session_manager() {
    mkdir -p "$H/.dextermux"
    cat >"$H/.dextermux/session-manager.sh" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
# Gerado por dextermux. Alterna, testa e remove sessoes graficas.
set -eu
DIR="$HOME/.dextermux"
FILE="$DIR/session"
mkdir -p "$DIR"

usage() {
    cat <<TXT
uso: dextermux-session [comando]

  (vazio)            mostra a sessao atual, as instaladas e os displays ativos
  list               lista sessoes com estado
  set NOME           define a sessao padrao e reinicia o VNC
  try NOME [DISPLAY] sobe a sessao no display indicado (padrao 2)
  stop [DISPLAY]     encerra o display de teste (padrao 2)
  remove NOME        remove os pacotes exclusivos da sessao
TXT
}

have() { command -v "$1" >/dev/null 2>&1; }
installed() {
    case "$1" in
        ubuntu) have startxfce4 ;;
        cinnamon) have cinnamon-session ;;
        mate) have mate-session ;;
        *) return 1 ;;
    esac
}
current() { cat "$FILE" 2>/dev/null || echo ubuntu; }

list_sessions() {
    local s
    for s in ubuntu cinnamon mate; do
        if installed "$s"; then
            if [ "$s" = "$(current)" ]; then
                printf '  %-10s instalada  padrao\n' "$s"
            else
                printf '  %-10s instalada\n' "$s"
            fi
        else
            printf '  %-10s ausente\n' "$s"
        fi
    done
}

running_displays() {
    local d found=0
    for d in 1 2 3 4 5 6; do
        if pgrep -f "[X]vnc :$d" >/dev/null; then
            found=1
            printf '  :%-2s VNC %-5s noVNC %-5s sessao %s\n' \
                "$d" "$((5900 + d))" "$((6080 + d - 1))" \
                "$(cat "$DIR/running.$d" 2>/dev/null || echo "?")"
        fi
    done
    if [ "$found" = "0" ]; then
        printf '  nenhum display ativo\n'
    fi
}

restart_vnc() {
    vncserver -kill :1 >/dev/null 2>&1 || true
    sleep 1
    rm -f "$TMPDIR/.X1-lock" "$TMPDIR/.X11-unix/X1" "$HOME/.vnc/"*:1.pid 2>/dev/null || true
    "$HOME/start-desktop.sh" 1
}

cmd="${1:-}"
case "$cmd" in
    ""|status)
        echo ""
        echo "Sessao padrao: $(current)"
        list_sessions
        echo ""
        echo "Displays ativos:"
        running_displays
        echo ""
        ;;
    list)
        list_sessions
        ;;
    set)
        name="${2:-}"
        installed "$name" || { echo "sessao nao instalada: $name" >&2; exit 1; }
        echo "$name" >"$FILE"
        rm -f "$DIR/session.1"
        echo "sessao padrao: $name"
        restart_vnc
        ;;
    try)
        name="${2:-}"
        disp="${3:-2}"
        installed "$name" || { echo "sessao nao instalada: $name" >&2; exit 1; }
        case "$disp" in
            ""|*[!0-9]*) echo "display invalido: $disp" >&2; exit 1 ;;
        esac
        "$HOME/start-desktop.sh" "$disp" "$name"
        echo ""
        echo "Sessao $name no display :$disp"
        echo "noVNC: http://<ip>:$((6080 + disp - 1))/vnc.html"
        echo "VNC:   <ip>:$((5900 + disp))"
        ;;
    stop)
        disp="${2:-2}"
        case "$disp" in
            ""|*[!0-9]*) disp=2 ;;
        esac
        vncserver -kill ":$disp" >/dev/null 2>&1 || true
        pkill -f "[w]ebsockify.*$((6080 + disp - 1))" 2>/dev/null || true
        rm -f "$DIR/session.$disp" "$DIR/running.$disp"
        echo "display :$disp encerrado"
        ;;
    remove)
        name="${2:-}"
        case "$name" in
            cinnamon) pkgs="cinnamon cinnamon-session cinnamon-settings-daemon cinnamon-control-center cinnamon-desktop cinnamon-menus muffin cjs nemo mint-themes mint-y-icon-theme" ;;
            mate) pkgs="mate mate-session-manager mate-panel mate-settings-daemon mate-control-center mate-terminal marco caja pluma mate-applet-brisk-menu mate-tweak mate-menus mate-desktop mate-utils mate-media mate-power-manager mate-screensaver mate-notification-daemon mate-themes mate-icon-theme" ;;
            *) echo "remocao suportada apenas para cinnamon e mate" >&2; exit 1 ;;
        esac
        if [ "$(current)" = "$name" ]; then
            echo "sessao ativa; trocando para ubuntu antes de remover"
            echo ubuntu >"$FILE"
            restart_vnc
        fi
        echo "pacotes a remover: $pkgs"
        printf 'confirmar remocao? [s/N] '
        read -r a || a=""
        case "$a" in
            s|S) ;;
            *) echo "cancelado"; exit 0 ;;
        esac
        for p in $pkgs; do
            dpkg-query -W -f='${Status}' "$p" 2>/dev/null | grep -q "install ok installed" || continue
            pkg uninstall -y "$p" || true
        done
        pkg autoremove -y || true
        echo "concluido; rode 'pkg clean' para liberar o cache"
        ;;
    -h|--help|help)
        usage
        ;;
    *)
        echo "comando invalido: $cmd" >&2
        usage
        exit 1
        ;;
esac
EOF
    chmod +x "$H/.dextermux/session-manager.sh"
    ln -sf "$H/.dextermux/session-manager.sh" "$P/bin/dextermux-session"
}

write_theme_helper() {
    cat >"$H/.dextermux/theme.sh" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
# Gerado por dextermux. Reaplica o visual Ubuntu-like sem reinstalar pacotes.
set -eu
H="$HOME"
P="${PREFIX:-/data/data/com.termux/files/usr}"
CONF="$H/.config"
mkdir -p "$CONF/xfce4/xfconf/xfce-perchannel-xml" "$CONF/rofi" "$CONF/plank/dock1/launchers" "$CONF/autostart" "$H/.local/share/applications" "$H/.dextermux"

cat >"$H/.local/share/applications/dextermux-apps.desktop" <<DESK
[Desktop Entry]
Type=Application
Name=Aplicativos
Comment=Buscar aplicativos
Exec=rofi -show drun -theme "$CONF/rofi/config.rasi"
Icon=view-app-grid-symbolic
Terminal=false
Categories=System;
DESK

for item in gnome-terminal thunar; do
    if [ -f "$P/share/applications/$item.desktop" ]; then
        cat >"$CONF/plank/dock1/launchers/$item.dockitem" <<DOCK
[PlankDockItemPreferences]
Launcher=file://$P/share/applications/$item.desktop
DOCK
    fi
done

cat >"$CONF/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml" <<PANEL
<?xml version="1.0" encoding="UTF-8"?>

<channel name="xfce4-panel" version="1.0">
  <property name="configdir" type="string" value="$CONF/xfce4/panel"/>
  <property name="panels" type="uint" value="1">
    <property name="panel-1" type="empty">
      <property name="autohide-behavior" type="uint" value="0"/>
      <property name="background-alpha" type="uint" value="92"/>
      <property name="background-rgba" type="array">
        <value type="double" value="0.086"/>
        <value type="double" value="0.086"/>
        <value type="double" value="0.117"/>
        <value type="double" value="0.941"/>
      </property>
      <property name="background-style" type="uint" value="1"/>
      <property name="length" type="uint" value="100"/>
      <property name="length-adjust" type="bool" value="true"/>
      <property name="mode" type="uint" value="0"/>
      <property name="position" type="string" value="p=6;x=0;y=0"/>
      <property name="position-locked" type="bool" value="true"/>
      <property name="size" type="uint" value="30"/>
      <property name="size-max" type="uint" value="32"/>
      <property name="plugin-ids" type="array">
        <value type="int" value="1"/>
        <value type="int" value="2"/>
        <value type="int" value="3"/>
        <value type="int" value="4"/>
        <value type="int" value="5"/>
      </property>
    </property>
  </property>
  <property name="plugins" type="empty">
    <property name="plugin-1" type="string" value="launcher">
      <property name="items" type="array">
        <value type="string" value="dextermux-apps.desktop"/>
      </property>
    </property>
    <property name="plugin-2" type="string" value="tasklist">
      <property name="flat-buttons" type="bool" value="true"/>
      <property name="show-handle" type="bool" value="false"/>
      <property name="show-labels" type="bool" value="false"/>
    </property>
    <property name="plugin-3" type="string" value="separator">
      <property name="expand" type="bool" value="true"/>
      <property name="style" type="uint" value="0"/>
    </property>
    <property name="plugin-4" type="string" value="systray">
      <property name="known-legacy-items" type="array">
        <value type="string" value="plank"/>
      </property>
    </property>
    <property name="plugin-5" type="string" value="clock">
      <property name="digital-layout" type="uint" value="3"/>
      <property name="digital-time-format" type="string" value="%H:%M"/>
      <property name="digital-date-format" type="string" value="%a, %d %b"/>
    </property>
  </property>
</channel>
PANEL

cat >"$CONF/rofi/config.rasi" <<'RASI'
configuration {
  modi: "drun,run,window";
  font: "Ubuntu 11";
  show-icons: true;
  drun-display-format: "{name}";
  display-drun: "Aplicativos";
  display-run: "Executar";
  display-window: "Janelas";
  terminal: "gnome-terminal";
}
window { width: 44%; border-radius: 12px; background-color: #16161e; }
inputbar { padding: 12px; background-color: #1e1e28; border-radius: 10px; }
listview { lines: 8; columns: 1; }
element { padding: 8px; border-radius: 8px; }
element selected { background-color: #2a2a3a; }
RASI

cat >"$CONF/picom.conf" <<'PICOM'
backend = "xrender";
vsync = false;
shadow = true;
shadow-radius = 12;
shadow-opacity = 0.35;
shadow-offset-x = -8;
shadow-offset-y = -8;
corner-radius = 12;
rounded-corners-exclude = [ "class_g = 'Plank'" ];
blur-background = false;
mark-wmwin-focused = true;
mark-ovredir-focused = true;
PICOM

cat >"$CONF/plank/dock1/settings" <<'PLANK'
[PlankDockPreferences]
Alignment=3
AutoHideDelay=200
HideMode=1
IconSize=48
LockItems=false
PinnedOnly=false
Theme=Transparent
ZoomEnabled=true
ZoomPercent=115
PLANK

cat >"$H/.dextermux/wallpaper.svg" <<'WALL'
<svg xmlns="http://www.w3.org/2000/svg" width="1600" height="900">
  <defs>
    <linearGradient id="g" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0%" stop-color="#2b1b3d"/>
      <stop offset="55%" stop-color="#1b2333"/>
      <stop offset="100%" stop-color="#0e0f14"/>
    </linearGradient>
  </defs>
  <rect width="1600" height="900" fill="url(#g)"/>
</svg>
WALL

if command -v xfconf-query >/dev/null 2>&1; then
    xfconf-query -c xsettings -p /Net/ThemeName -n -t string -s "Arc-Dark" 2>/dev/null || true
    xfconf-query -c xsettings -p /Net/IconThemeName -n -t string -s "Adwaita" 2>/dev/null || true
    xfconf-query -c xsettings -p /Gtk/FontName -n -t string -s "Ubuntu 10" 2>/dev/null || true
    xfconf-query -c xsettings -p /Xft/Antialias -n -t int -s 1 2>/dev/null || true
    xfconf-query -c xsettings -p /Xft/Hinting -n -t int -s 1 2>/dev/null || true
    xfconf-query -c xsettings -p /Xft/HintStyle -n -t string -s hintfull 2>/dev/null || true
    xfconf-query -c xsettings -p /Xft/RGBA -n -t string -s rgb 2>/dev/null || true
    if command -v xfce4-panel >/dev/null 2>&1 && pgrep -x xfce4-panel >/dev/null 2>&1; then
        xfce4-panel -r >/dev/null 2>&1 || true
    fi
    props=$(xfconf-query -c xfce4-desktop -l 2>/dev/null | grep 'last-image' || true)
    for p in $props; do
        xfconf-query -c xfce4-desktop -p "$p" -s "$H/.dextermux/wallpaper.svg" 2>/dev/null || true
    done
fi

echo "tema aplicado em $CONF"
EOF
    chmod +x "$H/.dextermux/theme.sh"
    ln -sf "$H/.dextermux/theme.sh" "$P/bin/dextermux-theme"
}

install_fonts() {
    local dir="$H/.local/share/fonts" base f
    base="https://github.com/google/fonts/raw/main/ufl/ubuntu"
    mkdir -p "$dir"
    for f in Ubuntu-Regular.ttf Ubuntu-Medium.ttf Ubuntu-Bold.ttf; do
        if [ -s "$dir/$f" ]; then
            continue
        fi
        if ! curl -fsSL "$base/$f" -o "$dir/$f" 2>/dev/null; then
            rm -f "$dir/$f"
            warn "fonte $f indisponivel; usando DejaVu"
            return 0
        fi
    done
    if command -v fc-cache >/dev/null 2>&1; then
        fc-cache -f >/dev/null 2>&1 || true
    fi
    ok "fontes Ubuntu instaladas"
}

write_bashrc_block() {
    touch "$H/.bashrc"
    sed -i '/# dextermux-start/,/# dextermux-end/d' "$H/.bashrc"
    sed -i '/show-access.sh/d; /start-desktop.sh >\/dev\/null 2>&1/d' "$H/.bashrc"
    cat >>"$H/.bashrc" <<'EOF'
# dextermux-start
if ! pgrep -f "[X]vnc :1" >/dev/null 2>&1; then setsid "$HOME/start-desktop.sh" >/dev/null 2>&1 & fi
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

write_session_default() {
    mkdir -p "$H/.dextermux"
    if [ "$DESKTOP" = "all" ]; then
        printf 'ubuntu\n' >"$H/.dextermux/session"
    elif [ "$DESKTOP" = "none" ]; then
        printf 'none\n' >"$H/.dextermux/session"
    else
        printf '%s\n' "$DESKTOP" >"$H/.dextermux/session"
    fi
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

    step "Pacotes base"
    # shellcheck disable=SC2086
    install_pkgs $PKGS_BASE

    step "Sessao grafica"
    case "$DESKTOP" in
        ubuntu)
            # shellcheck disable=SC2086
            install_pkgs $PKGS_UBUNTU
            install_fonts
            ;;
        cinnamon)
            # shellcheck disable=SC2086
            install_pkgs $PKGS_CINNAMON
            install_fonts
            ;;
        mate)
            # shellcheck disable=SC2086
            install_pkgs $PKGS_MATE
            install_fonts
            ;;
        all)
            # shellcheck disable=SC2086
            install_pkgs $PKGS_UBUNTU
            install_fonts
            # shellcheck disable=SC2086
            install_pkgs $PKGS_CINNAMON
            # shellcheck disable=SC2086
            install_pkgs $PKGS_MATE
            ;;
        none)
            info "nenhuma sessao grafica sera instalada"
            ;;
    esac
}

run_dev() {
    step "Ferramentas de desenvolvimento"
    if [ -z "$DEV_GROUPS" ]; then
        info "nenhum grupo selecionado"
        return 0
    fi
    local pkgs g
    for g in $DEV_GROUPS; do
        pkgs=$(dev_pkg_list "$g")
        if [ -z "$pkgs" ]; then
            continue
        fi
        info "grupo $g"
        # shellcheck disable=SC2086
        install_pkgs $pkgs
    done
}

run_install() {
    mkdir -p "$H/.dextermux"
    : >"$LOG"
    printf 'dextermux %s - %s\n' "$DEXTERMUX_VERSION" "$(date)" >>"$LOG"
    printf 'desktop=%s dev=%s tunnel=%s geometry=%s\n' "$DESKTOP" "$DEV_GROUPS" "$TUNNEL" "$GEOMETRY" >>"$LOG"

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

    step "Configuracoes da sessao"
    write_session_default
    write_xstartup

    step "Scripts de operacao"
    write_start_desktop
    write_show_access
    write_session_manager
    if [ "$DESKTOP" != "none" ]; then
        write_theme_helper
    fi

    run_dev

    step "Banner do shell"
    write_bashrc_block

    step "Autostart no boot"
    write_boot_script

    step "Chave SSH"
    write_ssh_key

    step "Subindo servicos"
    if [ "$DESKTOP" = "none" ]; then
        setsid sshd >/dev/null 2>&1 || true
        ok "sshd iniciado (sem desktop)"
    else
        "$H/start-desktop.sh" 2>&1 | tee -a "$LOG" || warn "servicos iniciaram com avisos; veja $LOG"
    fi

    step "Limpando cache"
    pkg clean >/dev/null 2>&1 || true
    ok "cache do pkg limpo"
}

repair_only() {
    TOTAL_STEPS=6
    : >"$LOG"
    printf 'dextermux %s - reparo %s\n' "$DEXTERMUX_VERSION" "$(date)" >>"$LOG"
    step "Configuracoes da sessao"
    write_session_default
    write_xstartup
    step "Scripts de operacao"
    write_start_desktop
    write_show_access
    write_session_manager
    if [ "$DESKTOP" != "none" ]; then
        write_theme_helper
    fi
    step "Banner do shell"
    write_bashrc_block
    step "Autostart no boot"
    write_boot_script
    step "Reiniciando servicos"
    vncserver -kill :1 >/dev/null 2>&1 || true
    sleep 1
    rm -f "$TMPDIR/.X1-lock" "$TMPDIR/.X11-unix/X1" "$H/.vnc/"*:1.pid 2>/dev/null || true
    "$H/start-desktop.sh" 2>&1 | tee -a "$LOG" || warn "servicos iniciaram com avisos"
}

# ---------------------------------------------------------------- resumo

print_summary() {
    local ip session public
    ip=$(ifconfig 2>/dev/null | sed -n '/^wlan0/,/^$/s/.*inet \([0-9.]*\).*/\1/p' | head -1)
    [ -z "$ip" ] && ip="<ip>"
    session=$(current_session)
    public=$(cat "$H/tunnel-url.txt" 2>/dev/null || echo "indisponivel")

    section "Resumo"
    row "Usuario" "$(whoami)"
    if [ "$session" = "none" ]; then
        row "Sessao" "sem desktop"
        row "SSH" "ssh -p 8022 $(whoami)@$ip"
        row "Log" "$LOG"
    else
        row "Sessao" "$session"
        row "VNC local" "vnc://$ip:5901"
        row "noVNC local" "http://$ip:6080/vnc.html"
        row "Tunel publico" "$public"
        row "Senha VNC" "${VNC_PASS:-(a existente em ~/.vnc/passwd)}"
        row "Log" "$LOG"
    fi

    section "Comandos"
    printf '  %-22s %s\n' "desktop" "sobe sshd, Xvnc, websockify e cloudflared"
    printf '  %-22s %s\n' "url" "mostra IP, portas e estado"
    printf '  %-22s %s\n' "dextermux-session" "lista e troca a sessao grafica"
    printf '  %-22s %s\n' "dextermux-session try X" "testa uma sessao em paralelo na porta 6081"
    printf '  %-22s %s\n' "dextermux-theme" "reaplica o visual Ubuntu-like"
    printf '  %-22s %s\n' "dextermux-session remove X" "remove pacotes de cinnamon ou mate"

    section "Pendencias manuais"
    printf '  1. Instalar o app Termux:Boot (F-Droid/GitHub) e abrir uma vez.\n'
    printf '  2. Samsung: Configuracoes > Aplicativos > Termux > Bateria > Sem restricoes.\n'
    printf '     Bateria > Limites de uso em segundo plano > Apps que nunca dormem > Termux.\n'
    printf '     Remover Termux de "Apps em suspensao" e "em suspensao profunda".\n'
    printf '  3. Reservar o IP do celular no roteador para nao mudar.\n'
    printf '  4. Se quiser senha do usuario: passwd\n'
    printf '  5. O tunel publico expoe o noVNC na internet; use senha forte.\n'
    rule
}

print_list() {
    section "Presets de desktop"
    printf '  %-34s %7s MB\n' "ubuntu  (XFCE restilizado)" "$SIZE_UBUNTU"
    printf '  %-34s %7s MB\n' "cinnamon" "$SIZE_CINNAMON"
    printf '  %-34s %7s MB\n' "mate" "$SIZE_MATE"
    printf '  %-34s %7s MB\n' "all  (as tres)" "$SIZE_ALL"
    printf '  %-34s %7s MB\n' "none  (so servidor)" "$SIZE_NONE"
    section "Perfis de desenvolvimento"
    printf '  %-34s %7s MB\n' "core" "$SIZE_DEV_CORE"
    printf '  %-34s %7s MB\n' "web" "$SIZE_DEV_WEB"
    printf '  %-34s %7s MB\n' "rust" "$SIZE_DEV_RUST"
    printf '  %-34s %7s MB\n' "go" "$SIZE_DEV_GO"
    printf '  %-34s %7s MB\n' "java" "$SIZE_DEV_JAVA"
    printf '  %-34s %7s MB\n' "db" "$SIZE_DEV_DB"
    printf '  %-34s %7s MB\n' "browser" "$SIZE_DEV_BROWSER"
    printf '\n  Tamanhos incluem dependencias e a base remota (VNC, noVNC, tunel).\n\n'
}

print_dry_run() {
    section "Plano (dry-run)"
    row "Desktop" "$DESKTOP"
    row "Dev" "${DEV_GROUPS:-nenhum}"
    row "Tunel" "$([ "$TUNNEL" = "1" ] && echo ligado || echo desligado)"
    row "Geometria" "$GEOMETRY"
    row "Estimativa" "~$(estimated_total_mb) MB"
    printf '\n  Pacotes base: %s\n' "$PKGS_BASE"
    case "$DESKTOP" in
        ubuntu) printf '  Pacotes desktop: %s\n' "$PKGS_UBUNTU" ;;
        cinnamon) printf '  Pacotes desktop: %s\n' "$PKGS_CINNAMON" ;;
        mate) printf '  Pacotes desktop: %s\n' "$PKGS_MATE" ;;
        all) printf '  Pacotes desktop: %s %s %s\n' "$PKGS_UBUNTU" "$PKGS_CINNAMON" "$PKGS_MATE" ;;
        *) printf '  Pacotes desktop: nenhum\n' ;;
    esac
    if [ -n "$DEV_GROUPS" ]; then
        printf '  Pacotes dev: %s\n' "$(dev_pkg_list "$DEV_GROUPS")"
    fi
    printf '\n  Arquivos que seriam gravados:\n'
    printf '    ~/.vnc/xstartup\n    ~/.vnc/passwd\n    ~/start-desktop.sh\n'
    printf '    ~/show-access.sh\n    ~/.dextermux/session\n    ~/.dextermux/session-manager.sh\n'
    if [ "$DESKTOP" != "none" ]; then
        printf '    ~/.dextermux/theme.sh\n    ~/.config/rofi/config.rasi\n    ~/.config/picom.conf\n'
        printf '    ~/.config/plank/dock1/settings\n    ~/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml\n'
    fi
    printf '    ~/.termux/boot/start-services.sh\n    ~/.bashrc (bloco dextermux)\n\n'
}

# ---------------------------------------------------------------- main

parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            -y|--yes) INTERACTIVE=0 ;;
            --non-interactive) INTERACTIVE=0 ;;
            --desktop=*) DESKTOP="${1#*=}" ;;
            --dev=*) DEV_GROUPS=$(printf '%s' "${1#*=}" | tr ',' ' ') ;;
            --geometry=*) GEOMETRY="${1#*=}" ;;
            --password=*) VNC_PASS="${1#*=}" ;;
            --ssh-pubkey=*) SSH_PUBKEY="${1#*=}" ;;
            --tunnel) TUNNEL=1 ;;
            --no-tunnel) TUNNEL=0 ;;
            --repair) MODE="repair" ;;
            --dry-run) DRY_RUN=1 ;;
            --list) print_list; exit 0 ;;
            -h|--help) usage; exit 0 ;;
            --version) printf '%s\n' "$DEXTERMUX_VERSION"; exit 0 ;;
            *) die "flag desconhecida: $1 (use --help)" ;;
        esac
        shift
    done
    case "$DESKTOP" in
        ubuntu|cinnamon|mate|all|none) ;;
        *) die "desktop invalido: $DESKTOP (ubuntu|cinnamon|mate|all|none)" ;;
    esac
    DEV_GROUPS=$(printf '%s' "$DEV_GROUPS" | tr ',' ' ')
    if [ "$DEV_GROUPS" = "none" ]; then
        DEV_GROUPS=""
    fi
}

main() {
    parse_args "$@"
    if [ "$DRY_RUN" = "0" ]; then
        open_tty
    fi

    if [ ! -d /data/data/com.termux/files/usr ]; then
        if [ "$DRY_RUN" = "0" ]; then
            die "rode este script dentro do Termux"
        fi
    fi

    detect_resources

    if [ "$DRY_RUN" = "1" ]; then
        print_dry_run
        exit 0
    fi

    if [ "$MODE" = "repair" ]; then
        DESKTOP=$(current_session)
        if [ "$DESKTOP" = "none" ]; then
            DESKTOP="ubuntu"
        fi
        repair_only
        print_summary
        exit 0
    fi

    if [ "$INTERACTIVE" = "1" ]; then
        screen_resources
        while true; do
            screen_desktop
            if [ "$DESKTOP" != "none" ]; then
                screen_dev
            else
                DEV_GROUPS=""
            fi
            screen_remote
            if screen_confirm; then
                break
            fi
        done
    else
        banner
        info "modo automatico: desktop=$DESKTOP dev=${DEV_GROUPS:-nenhum} tunel=$TUNNEL"
    fi

    run_install
    print_summary
}

if [ "${DEXTERMUX_LIB_ONLY:-0}" != "1" ]; then
    main "$@"
fi
