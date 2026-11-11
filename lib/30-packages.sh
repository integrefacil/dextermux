# shellcheck shell=bash
# 30-packages - listas de pacotes e instalacao via pkg/apt

PKGS_BASE="tigervnc openssh openssl-tool python net-tools cloudflared curl tar dbus git nano"
PKGS_CINNAMON="cinnamon gnome-terminal ttf-dejavu"
PKGS_XFCE="xfwm4 xfce4-panel xfce4-session xfce4-settings xfconf xfdesktop thunar xfce4-terminal ttf-dejavu"

SIZE_CINNAMON=1700
SIZE_XFCE=690

desktop_packages() {
    case "$1" in
        cinnamon) printf '%s\n' "$PKGS_CINNAMON" ;;
        xfce) printf '%s\n' "$PKGS_XFCE" ;;
        *) printf '\n' ;;
    esac
}

desktop_size() {
    case "$1" in
        cinnamon) printf '%s\n' "$SIZE_CINNAMON" ;;
        xfce) printf '%s\n' "$SIZE_XFCE" ;;
        *) printf '0\n' ;;
    esac
}

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
    pkg install -y --no-install-recommends \
        -o Dpkg::Options::=--force-confdef \
        -o Dpkg::Options::=--force-confold \
        $missing </dev/null 2>&1 | tee -a "$LOG"
    if [ "${PIPESTATUS[0]}" -ne 0 ]; then
        die "falha ao instalar: $missing"
    fi
}

update_indexes() {
    step "Atualizando indices"
    if [ "${DEXTERMUX_NO_UPDATE:-0}" = "1" ]; then
        info "pulado (DEXTERMUX_NO_UPDATE=1)"
    else
        pkg update -y 2>&1 | tee -a "$LOG" || warn "pkg update retornou erro; seguindo"
    fi
}

install_x11_repo() {
    step "Repositorio x11"
    install_pkgs x11-repo
    pkg update -y 2>&1 | tee -a "$LOG" || warn "pkg update retornou erro; seguindo"
}

upgrade_packages() {
    step "Atualizando pacotes"
    if [ "${DEXTERMUX_NO_UPGRADE:-0}" = "1" ]; then
        info "pulado (DEXTERMUX_NO_UPGRADE=1)"
        return 0
    fi
    pkg upgrade -y \
        -o Dpkg::Options::=--force-confdef \
        -o Dpkg::Options::=--force-confold \
        </dev/null 2>&1 | tee -a "$LOG" || warn "pkg upgrade retornou erro; seguindo"
}

audit_dpkg() {
    step "Pacotes pendentes"
    if [ -n "$(dpkg --audit 2>/dev/null)" ]; then
        info "corrigindo pacotes pendentes"
        dpkg --force-confdef --force-confold --configure -a 2>&1 | tee -a "$LOG" || true
    else
        info "nenhum pacote pendente"
    fi
}

cleanup_legacy() {
    # remove artefatos de versoes anteriores (v2..v5)
    rm -f "$H/.dextermux/theme.sh" "$H/.dextermux/wallpaper.svg" \
        "$H/.dextermux/status.sh" "$H/.dextermux/dev.sh" \
        "$H/.dextermux/ubuntu.sh" "$H/.dextermux/gui.sh" \
        "$H/.dextermux/session-manager.sh"
    rm -f "$P/bin/dextermux-theme" "$P/bin/dextermux-status" \
        "$P/bin/dextermux-tls" "$P/bin/dextermux-session" \
        "$P/bin/dextermux-dev" "$P/bin/dextermux-ubuntu" \
        "$P/bin/dextermux-gui" "$P/bin/dextermux-desktop"
    rm -rf "$H/.config/rofi" "$H/.config/plank" "$H/.config/xfce4/panel"
    rm -f "$H/.config/picom.conf" \
        "$H/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml" \
        "$H/.config/xfce4/helpers.rc"
    rm -f "$H/.local/share/applications/"dextermux-*.desktop
}
