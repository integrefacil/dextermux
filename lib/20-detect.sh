# shellcheck shell=bash
# 20-detect - recursos do aparelho e estado da instalacao

UBUNTU_ROOT="$P/var/lib/proot-distro/containers/ubuntu/rootfs"

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

    DISK_FREE_MB=$(disk_free_mb "$H")
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

    if [ -d "$H/.dextermux" ] || [ -f "$H/start-desktop.sh" ]; then
        EXISTING="sim"
    else
        EXISTING="nao"
    fi
}

desktop_installed() {
    case "$1" in
        cinnamon) command -v cinnamon-session >/dev/null 2>&1 ;;
        xfce) command -v startxfce4 >/dev/null 2>&1 ;;
        *) return 1 ;;
    esac
}

current_desktop() {
    cat "$H/.dextermux/desktop" 2>/dev/null || echo "cinnamon"
}

proot_installed() { [ -d "$UBUNTU_ROOT" ]; }

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
    if [ "$EXISTING" = "sim" ]; then
        row "Desktop atual" "$(current_desktop)"
    fi
    if proot_installed; then
        row "Ubuntu (proot)" "instalado"
    fi
}
