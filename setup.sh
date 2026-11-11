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

DEXTERMUX_VERSION="6.1.3"
LIBS_COMMIT="e5446ba643f5b910295e7e489d5acf63a4b7bbc5"
LIBS_ORDER="00-common 10-ui 20-detect 30-packages 40-session 50-remote 52-cast 60-ssh 70-proot 75-tunnel 80-reset 90-summary"

lib_sha() {
    case "$1" in
        00-common.sh) printf '%s' 'eacd5669b10b6669b50cf1956a1319e69c8396c42218894345c089a23236ccd5' ;;
        10-ui.sh) printf '%s' 'fa872528aef5689fb029906aa6c736f77626dd6c58d465f7045bf6ce4d2842d6' ;;
        20-detect.sh) printf '%s' '0085f5abc462ec613c12e590a92a122e6f3690c2dc227f6246858af07ffaab88' ;;
        30-packages.sh) printf '%s' '6053001bab30cebea89784f6bf9c17d263e4802205728ca8553b09b99ad79083' ;;
        40-session.sh) printf '%s' 'b59e33f02aeeff0214a8ff87c41e56466fc5b2821c21fbbcfd673778841324fa' ;;
        50-remote.sh) printf '%s' '1dc5ac0b71cece75e4bcb139d1f65c2eb48dbcd91b0e32dedcad4582a5d7c603' ;;
        52-cast.sh) printf '%s' 'f8144a3c23d50fd72e5510e8ed52a6c9f3aa8983839193a6f17515788373887b' ;;
        60-ssh.sh) printf '%s' '2b145f7d080cbe15d94579f8a5a57e5270c49f4f64285fc9b87dccc585fc86f6' ;;
        70-proot.sh) printf '%s' 'a49b12f524bf458169a788150c3a8d955f824947f0476874105c4617607750bd' ;;
        75-tunnel.sh) printf '%s' '506904a4e720fd0f7aefb8dd6522e934480d09c81f02f305ce973a6a0551c570' ;;
        80-reset.sh) printf '%s' '68f443e5a1f039014a0347d1cbd96bdec7e79d1deff469be710fb7b82744df33' ;;
        90-summary.sh) printf '%s' 'd1641262fdcdf12eaabfe2be13acaafb979d8d888ea10f41bd4a6f2b382d986c' ;;
        *) printf '' ;;
    esac
}

SELF="${BASH_SOURCE[0]:-}"
LIBDIR=""

# caminho absoluto do instalador: sobrevive ao wipe do $HOME e ao exec do reset
if [ -n "$SELF" ] && [ -f "$SELF" ]; then
    DEXTERMUX_SELF="$(cd "$(dirname "$SELF")" && pwd)/$(basename "$SELF")"
else
    DEXTERMUX_SELF=""
fi
export DEXTERMUX_SELF

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
