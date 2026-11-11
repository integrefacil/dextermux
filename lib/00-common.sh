# shellcheck shell=bash
# 00-common - constantes, UI basica, log e utilitarios

DEXTERMUX_VERSION="${DEXTERMUX_VERSION:-6.1.1}"

P="${PREFIX:-/data/data/com.termux/files/usr}"
H="$HOME"
LOG="$H/dextermux-install.log"
GEOMETRY="${GEOMETRY:-1600x900}"
NOVNC_VER="${NOVNC_VER:-1.5.0}"
TLS_MODE="${TLS:-1}"
TUNNEL_MODE="${TUNNEL:-0}"
SSH_PUBKEY="${SSH_PUBKEY:-}"
SHARED_PASS="${VNC_PASS:-}"
DESKTOP="${DESKTOP:-cinnamon}"
PROOT_WANTED="${PROOT:-0}"
CAST_MODE="${CAST:-0}"
CAST_KIND="${CAST_KIND:-novnc}"
CAST_QUALITY="${CAST_QUALITY:-720p}"
KEYBOARD_LAYOUT="${KEYBOARD:-br}"

STEP_NO=0
TOTAL_STEPS=0

if [ -t 1 ] && [ "${TERM:-dumb}" != "dumb" ] && [ -z "${NO_COLOR:-}" ]; then
    C_RESET=$'\033[0m'; C_B=$'\033[1m'; C_DIM=$'\033[2m'
    C_ACC=$'\033[36m'; C_OK=$'\033[32m'; C_WARN=$'\033[33m'; C_ERR=$'\033[31m'
else
    C_RESET=""; C_B=""; C_DIM=""; C_ACC=""; C_OK=""; C_WARN=""; C_ERR=""
fi

if [ "${DEXTERMUX_ASCII:-0}" = "1" ]; then RULE_CH="-"; else RULE_CH="─"; fi

rule() {
    printf '%s' "$C_DIM"
    printf "${RULE_CH}%.0s" {1..64}
    printf '%s\n' "$C_RESET"
}

section() {
    printf '\n%s%s%s\n' "$C_ACC$C_B" "$1" "$C_RESET"
    rule
}

row() { printf '  %s%-16s%s %s\n' "$C_DIM" "$1" "$C_RESET" "$2"; }
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
    if [ "$TOTAL_STEPS" -gt 0 ]; then
        printf '\n%s[%02d/%02d]%s %s%s%s\n' \
            "$C_DIM" "$STEP_NO" "$TOTAL_STEPS" "$C_RESET" "$C_B" "$1" "$C_RESET"
    else
        printf '\n%s[*]%s %s%s%s\n' "$C_DIM" "$C_RESET" "$C_B" "$1" "$C_RESET"
    fi
    printf '[%02d] %s\n' "$STEP_NO" "$1" >>"$LOG"
}

banner() {
    printf '\n%s%sdextermux %s%s\n' "$C_B" "$C_ACC" "$DEXTERMUX_VERSION" "$C_RESET"
    printf '%sDesktop remoto no Termux: VNC, noVNC, TLS e SSH.%s\n' "$C_DIM" "$C_RESET"
    rule
}

is_termux() { [ -d /data/data/com.termux/files/usr ]; }

process_count() {
    local n
    # shellcheck disable=SC2009
    n=$(ps -u "$(id -u)" -o comm= 2>/dev/null \
        | grep -vcE '^(ps|head|wc|tr|grep|sed|awk|sort|sleep)$' || true)
    if [ -z "$n" ] || [ "$n" = "0" ]; then
        n=0
        for d in /proc/[0-9]*; do
            if [ -d "$d" ] && [ -O "$d" ]; then n=$((n + 1)); fi
        done
    fi
    printf '%s\n' "${n:-0}"
}

process_verdict() {
    if [ "$1" -ge 27 ]; then printf 'critico'
    elif [ "$1" -ge 23 ]; then printf 'atencao'
    else printf 'ok'
    fi
}

disk_free_mb() {
    local path="$1" kb bsize
    kb=$(df -k "$path" 2>/dev/null | awk 'NR==2{print $4}')
    if [ -z "${kb:-}" ]; then
        kb=$(stat -f -c '%a' "$path" 2>/dev/null || echo 0)
        bsize=$(stat -f -c '%S' "$path" 2>/dev/null || echo 4096)
        kb=$((kb * bsize / 1024))
    fi
    printf '%s\n' "$((kb / 1024))"
}

