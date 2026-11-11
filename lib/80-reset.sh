# shellcheck shell=bash
# 80-reset - reinstalacao do zero (artefatos ou $HOME)

reset_artifacts() {
    info "apagando artefatos do dextermux"
    rm -rf "$H/.dextermux" "$H/.vnc" "$H/noVNC" "$H/noVNC-$NOVNC_VER"
    rm -f "$H/start-desktop.sh" "$H/show-access.sh" "$H/tunnel-url.txt"
    rm -f "$H/.termux/boot/start-services.sh"
    sed -i '/# dextermux-start/,/# dextermux-end/d' "$H/.bashrc" 2>/dev/null || true
    rm -rf "$P/var/lib/proot-distro/containers"
    rm -f "$P/bin/desktop" "$P/bin/url" "$P/bin/session" "$P/bin/tls" \
        "$P/bin/tunnel" "$P/bin/password" "$P/bin/ubuntu" "$P/bin/gui"
    ok "artefatos removidos"
}

reset_home() {
    if [ "${DEXTERMUX_RESET_DONE:-0}" = "1" ]; then
        return 0
    fi
    local self="${BASH_SOURCE[0]:-}" tmp
    if [ -z "$self" ] || [ ! -f "$self" ]; then
        die "reset do \$HOME exige rodar o setup.sh como arquivo"
    fi
    tmp="$TMPDIR/dextermux-reset.sh"
    cp "$self" "$tmp"
    chmod +x "$tmp"
    info "apagando rootfs e todo o conteudo de \$HOME"
    rm -rf "$P/var/lib/proot-distro/containers"
    find "$H" -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null || true
    DEXTERMUX_RESET_DONE=1 DEXTERMUX_LIBDIR="${DEXTERMUX_LIBDIR:-}" exec bash "$tmp" "$@"
}
