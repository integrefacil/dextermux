# shellcheck shell=bash
# 60-ssh - chave SSH, senha compartilhada e comando password

write_ssh_key() {
    mkdir -p "$H/.ssh"
    chmod 700 "$H/.ssh"
    touch "$H/.ssh/authorized_keys"
    chmod 600 "$H/.ssh/authorized_keys"
    if [ -n "$SSH_PUBKEY" ]; then
        case "$SSH_PUBKEY" in
            ssh-*|ecdsa-*|sk-*) ;;
            *)
                warn "SSH_PUBKEY nao parece uma chave publica; ignorando"
                info "adicione a chave em ~/.ssh/authorized_keys"
                return 0
                ;;
        esac
        if grep -qF "$SSH_PUBKEY" "$H/.ssh/authorized_keys" 2>/dev/null; then
            ok "chave ja estava autorizada"
        else
            printf '%s\n' "$SSH_PUBKEY" >>"$H/.ssh/authorized_keys"
            ok "chave adicionada em ~/.ssh/authorized_keys"
        fi
    else
        info "sem chave: adicione depois em ~/.ssh/authorized_keys"
    fi
}

set_vnc_password() {
    local pass="$1"
    mkdir -p "$H/.vnc"
    printf '%s' "$pass" | vncpasswd -f >"$H/.vnc/passwd"
    chmod 600 "$H/.vnc/passwd"
}

set_ssh_password() {
    local pass="$1"
    if [ "$INTERACTIVE" != "1" ]; then
        warn "senha do SSH nao alterada (modo --yes); use: password"
        return 0
    fi
    info "aplicando a mesma senha no SSH (se o passwd pedir, digite a mesma)"
    if printf '%s\n%s\n' "$pass" "$pass" | timeout 60 passwd >/dev/null 2>&1; then
        ok "senha do SSH atualizada"
    else
        warn "nao consegui definir a senha do SSH; rode: passwd (mesma senha)"
    fi
}

write_shared_password() {
    local pass="$SHARED_PASS" rand
    if [ -z "$pass" ]; then
        rand=$(head -c 256 /dev/urandom | tr -dc 'A-Za-z0-9' | head -c 8 || true)
        pass="$rand"
    fi
    if [ "${#pass}" -gt 8 ]; then
        warn "senha maior que 8 caracteres; o VncAuth usa apenas os 8 primeiros"
        pass=$(printf '%s' "$pass" | cut -c1-8)
    fi
    SHARED_PASS="$pass"
    mkdir -p "$H/.dextermux"
    printf '%s\n' "$pass" >"$H/.dextermux/password"
    chmod 600 "$H/.dextermux/password"
    set_vnc_password "$pass"
    ok "senha do VNC definida"
    set_ssh_password "$pass"
}

write_password_command() {
    cat >"$H/.dextermux/password.sh" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
# Gerado por dextermux. Troca a senha de VNC/noVNC/SSH (max. 8 caracteres).
set -eu

ask_new() {
    local a b
    printf 'Nova senha (ate 8 caracteres): '
    read -rs a || a=""
    printf '\n'
    printf 'Confirme: '
    read -rs b || b=""
    printf '\n'
    if [ -z "$a" ]; then echo "senha vazia" >&2; exit 1; fi
    if [ "$a" != "$b" ]; then echo "senhas diferentes" >&2; exit 1; fi
    if [ "${#a}" -gt 8 ]; then
        echo "aviso: o VNC usa apenas os 8 primeiros caracteres" >&2
        a=$(printf '%s' "$a" | cut -c1-8)
    fi
    printf '%s\n' "$a"
}

PASS=$(ask_new)
printf '%s' "$PASS" | vncpasswd -f >"$HOME/.vnc/passwd"
chmod 600 "$HOME/.vnc/passwd"
printf '%s\n' "$PASS" >"$HOME/.dextermux/password"
chmod 600 "$HOME/.dextermux/password"
echo "senha do VNC atualizada"

echo "aplicando no SSH (se o passwd pedir, digite a mesma)"
if printf '%s\n%s\n' "$PASS" "$PASS" | timeout 60 passwd >/dev/null 2>&1; then
    echo "senha do SSH atualizada"
else
    echo "nao consegui definir a senha do SSH; rode: passwd (mesma senha)" >&2
fi

pkill -f "[w]ebsockify" 2>/dev/null || true
"$HOME/start-desktop.sh" >/dev/null 2>&1 || true
"$HOME/show-access.sh"
EOF
    chmod +x "$H/.dextermux/password.sh"
    ln -sf "$H/.dextermux/password.sh" "$P/bin/password"
}
