#!/usr/bin/env bash
# Verifica se os SHA256 embutidos no setup.sh correspondem a lib/.
# Falha quando uma lib muda sem atualizar o bootstrap (e o commit fixado).
set -eu

fail=0

for f in lib/*.sh; do
    name=$(basename "$f")
    want=$(sed -n "s/^ *${name}) printf '%s' '\([0-9a-f]*\)' ;;$/\1/p" setup.sh)
    got=$(sha256sum "$f" | awk '{print $1}')
    if [ -z "$want" ]; then
        printf 'sem hash no setup.sh: %s\n' "$name" >&2
        fail=1
    elif [ "$want" != "$got" ]; then
        printf 'hash divergente: %s\n  setup.sh: %s\n  lib:      %s\n' \
            "$name" "$want" "$got" >&2
        fail=1
    fi
done

if [ "$fail" -ne 0 ]; then
    printf '\nAtualize setup.sh (hashes e LIBS_COMMIT) apos mudar lib/.\n' >&2
    exit 1
fi

printf 'checksums ok\n'
