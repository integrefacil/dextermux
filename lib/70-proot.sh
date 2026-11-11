# shellcheck shell=bash
# 70-proot - Ubuntu opcional para apps glibc (sem ferramentas de dev)

proot_setup() {
    install_pkgs proot-distro
    if [ ! -d "$UBUNTU_ROOT" ]; then
        info "instalando Ubuntu base (pode levar alguns minutos)"
        proot-distro install ubuntu 2>&1 | tee -a "$LOG" || warn "falha ao instalar o Ubuntu"
    else
        info "Ubuntu ja instalado"
    fi
    if [ -d "$UBUNTU_ROOT" ] && [ ! -f "$UBUNTU_ROOT/etc/ssl/certs/ca-certificates.crt" ]; then
        proot-distro login ubuntu -- bash -lc \
            'apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq ca-certificates' \
            2>&1 | tee -a "$LOG" || warn "apt falhou no Ubuntu"
    fi
}

write_ubuntu_helpers() {
    mkdir -p "$H/.dextermux"
    cat >"$H/.dextermux/gui.sh" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
# Gerado por dextermux. Roda um app do Ubuntu no desktop nativo.
set -eu
P="${PREFIX:-/data/data/com.termux/files/usr}"
ROOT="$P/var/lib/proot-distro/containers/ubuntu/rootfs"
if [ ! -d "$ROOT" ]; then
    echo "Ubuntu nao instalado; rode: bash setup.sh --proot" >&2
    exit 1
fi
if [ ! -S "$TMPDIR/.X11-unix/X1" ]; then
    echo "sessao grafica parada; rode: desktop" >&2
    exit 1
fi
if [ -f "$HOME/.Xauthority" ]; then
    cp -f "$HOME/.Xauthority" "$ROOT/root/.Xauthority"
fi
exec proot-distro login ubuntu --shared-tmp -- env DISPLAY=:1 XAUTHORITY=/root/.Xauthority "$@"
EOF
    chmod +x "$H/.dextermux/gui.sh"
    ln -sf "$H/.dextermux/gui.sh" "$P/bin/gui"

    cat >"$H/.dextermux/ubuntu.sh" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
# Gerado por dextermux. Abre um shell no Ubuntu.
set -eu
exec "$HOME/.dextermux/gui.sh" bash -l
EOF
    chmod +x "$H/.dextermux/ubuntu.sh"
    ln -sf "$H/.dextermux/ubuntu.sh" "$P/bin/ubuntu"
}
