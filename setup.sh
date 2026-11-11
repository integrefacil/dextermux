#!/data/data/com.termux/files/usr/bin/bash
# dextermux - instalador modular do desktop remoto no Termux
#
# Estrutura:
#   setup.sh       este bootstrap (nao editar a mao)
#   lib/*.sh       modulos; rodando do repositorio, sao usados localmente
#
# Rodando por pipe, os modulos sao baixados do commit fixo em LIBS_COMMIT
# e verificados por SHA256 antes de qualquer execucao.

set -eu

DEXTERMUX_VERSION="6.0.0"
LIBS_COMMIT="__LIBS_COMMIT__"
LIBS_ORDER="00-common 10-ui 20-detect 30-packages 40-session 50-remote 60-ssh 70-proot 75-tunnel 80-reset 90-summary"

lib_sha() {
    case "$1" in
        00-common.sh) printf '%s' '6c85aede3bb6b73fd02ca4a021bb0d4f5fe0982be1cd3a809542a121a08c8f4c' ;;
        10-ui.sh) printf '%s' '2bfce2e9ca07e6145f41ce2a8bf6c1b1e6ef79599490ada626d33658bf1a2ce8' ;;
        20-detect.sh) printf '%s' '0085f5abc462ec613c12e590a92a122e6f3690c2dc227f6246858af07ffaab88' ;;
        30-packages.sh) printf '%s' '3f042d2f49504fa528ab5336cebbbc4014b71a46980fea6080f1f80996f537d5' ;;
        40-session.sh) printf '%s' 'b59e33f02aeeff0214a8ff87c41e56466fc5b2821c21fbbcfd673778841324fa' ;;
        50-remote.sh) printf '%s' 'a662790c6844db6f7c4008c70bb5f4f51e081a955e51306886f2da3f7538f38a' ;;
        60-ssh.sh) printf '%s' '2b145f7d080cbe15d94579f8a5a57e5270c49f4f64285fc9b87dccc585fc86f6' ;;
        70-proot.sh) printf '%s' 'a49b12f524bf458169a788150c3a8d955f824947f0476874105c4617607750bd' ;;
        75-tunnel.sh) printf '%s' '506904a4e720fd0f7aefb8dd6522e934480d09c81f02f305ce973a6a0551c570' ;;
        80-reset.sh) printf '%s' '80df83016cf8f075c672fe3b2eed60f56fae5d4f46ae9bec46ee33f54ed11070' ;;
        90-summary.sh) printf '%s' '50d66e53184f6321212b8c32398fbd17047b13f2982eaf0b4b4b4c0b4d37c116' ;;
        *) printf '' ;;
    esac
}

SELF="${BASH_SOURCE[0]:-}"
LIBDIR=""

if [ -n "${DEXTERMUX_LIBDIR:-}" ] && [ -d "$DEXTERMUX_LIBDIR" ]; then
    LIBDIR="$DEXTERMUX_LIBDIR"
elif [ -n "$SELF" ] && [ -f "$SELF" ] && [ -d "$(dirname "$SELF")/lib" ]; then
    LIBDIR="$(cd "$(dirname "$SELF")" && pwd)/lib"
else
    LIBDIR="${TMPDIR:-/tmp}/dextermux-$DEXTERMUX_VERSION"
    mkdir -p "$LIBDIR"
fi

need=0
for f in $LIBS_ORDER; do
    [ -f "$LIBDIR/$f.sh" ] || need=1
done

if [ "$need" = "1" ]; then
    if ! command -v curl >/dev/null 2>&1; then
        printf 'curl ausente. Rode: pkg install curl\n' >&2
        exit 1
    fi
    if [ "$LIBS_COMMIT" = "__LIBS_COMMIT__" ]; then
        printf 'instalador sem commit fixado; use o setup.sh publicado\n' >&2
        exit 1
    fi
    base="https://raw.githubusercontent.com/integrefacil/dextermux/$LIBS_COMMIT/lib"
    for f in $LIBS_ORDER; do
        dest="$LIBDIR/$f.sh"
        if [ ! -f "$dest" ]; then
            if ! curl -fsSL "$base/$f.sh" -o "$dest"; then
                printf 'falha ao baixar %s.sh; verifique a rede\n' "$f" >&2
                exit 1
            fi
        fi
        want=$(lib_sha "$f.sh")
        got=$(sha256sum "$dest" | awk '{print $1}')
        if [ -z "$want" ] || [ "$want" != "$got" ]; then
            printf 'checksum invalido em %s.sh; abortando\n' "$f" >&2
            exit 1
        fi
    done
fi

export DEXTERMUX_LIBDIR="$LIBDIR"

for f in $LIBS_ORDER; do
    # shellcheck source=/dev/null
    . "$LIBDIR/$f.sh"
done

main "$@"
