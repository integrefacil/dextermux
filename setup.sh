#!/data/data/com.termux/files/usr/bin/bash
# dextermux - setup completo do ambiente remoto no Termux
#
# Instala e configura:
#   - XFCE4 (x11-repo)
#   - TigerVNC (Xvnc) com XFCE, VncAuth, 1600x900, accept-resize
#   - noVNC + websockify (navegador, porta 6080)
#   - Cloudflare quick tunnel (HTTPS publico)
#   - sshd + chave autorizada
#   - banner com as URLs ao abrir o Termux, comando "url" e "desktop"
#   - autostart no boot (Termux:Boot)
#
# Uso:
#   curl -fsSL <URL_RAW> | bash
#   curl -fsSL <URL_RAW> | VNC_PASS=MinhaSen bash
#   curl -fsSL <URL_RAW> | SSH_PUBKEY="ssh-ed25519 AAAA..." bash
#
# Variaveis:
#   VNC_PASS    senha do VNC (default: aleatoria de 8 chars)
#   GEOMETRY    resolucao inicial (default: 1600x900)
#   NOVNC_VER   versao do noVNC (default: 1.5.0)
#   SSH_PUBKEY  chave publica adicionada ao authorized_keys
#   TUNNEL      1 liga o cloudflared, 0 desliga (default: 1)
#
# NAO usa xrdp: o pacote 0.10.6.1 do Termux tem bug de autenticacao
# ("Bugcheck; inconsistent auth result"). Use VNC/noVNC.

set -eu
export DEBIAN_FRONTEND=noninteractive

P="${PREFIX:-/data/data/com.termux/files/usr}"
H="$HOME"
GEOMETRY="${GEOMETRY:-1600x900}"
NOVNC_VER="${NOVNC_VER:-1.5.0}"
TUNNEL="${TUNNEL:-1}"
SSH_PUBKEY="${SSH_PUBKEY:-}"

step() { printf '\n== %s ==\n' "$*"; }

if [ ! -d /data/data/com.termux/files/usr ]; then
    echo "Rode este script dentro do Termux." >&2
    exit 1
fi

step "Pacotes"
pkg update -y
pkg install -y x11-repo
pkg install -y xfce4 tigervnc openssh openssl-tool git python net-tools cloudflared curl tar

step "Senha do VNC"
if [ -z "${VNC_PASS:-}" ] && [ -f "$H/.vnc/passwd" ]; then
    echo "Mantendo a senha VNC existente em $H/.vnc/passwd"
else
    VNC_PASS="${VNC_PASS:-$(head -c 256 /dev/urandom | tr -dc 'A-Za-z0-9' | head -c 8 || true)}"
    mkdir -p "$H/.vnc"
    printf '%s' "$VNC_PASS" | vncpasswd -f > "$H/.vnc/passwd"
    chmod 600 "$H/.vnc/passwd"
    echo "Senha VNC: $VNC_PASS"
fi

step "Sessao XFCE do VNC"
mkdir -p "$H/.vnc"
cat > "$H/.vnc/xstartup" <<'EOF'
#!/data/data/com.termux/files/usr/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
export PATH=/data/data/com.termux/files/usr/bin:$PATH
export XDG_RUNTIME_DIR=$TMPDIR
exec /data/data/com.termux/files/usr/bin/startxfce4
EOF
chmod +x "$H/.vnc/xstartup"

step "noVNC + websockify"
pip3 install --no-deps -q websockify
if [ ! -f "$H/noVNC/vnc.html" ]; then
    rm -rf "$H/noVNC" "$H/noVNC-$NOVNC_VER"
    curl -fsSL "https://github.com/novnc/noVNC/archive/refs/tags/v$NOVNC_VER.tar.gz" -o "$TMPDIR/novnc.tgz"
    tar xzf "$TMPDIR/novnc.tgz" -C "$H"
    mv "$H/noVNC-$NOVNC_VER" "$H/noVNC"
fi

step "Scripts de operacao"
cat > "$H/start-desktop.sh" <<'EOF'
#!/data/data/com.termux/files/usr/bin/sh
termux-wake-lock
pgrep -f "sshd" >/dev/null || setsid sshd
if ! pgrep -f "[X]vnc :1" >/dev/null; then
  rm -f $TMPDIR/.X1-lock $TMPDIR/.X11-unix/X1 $HOME/.vnc/*.pid
fi
vncserver :1 -geometry __GEOMETRY__ -depth 24 -localhost no -SecurityTypes VncAuth 2>/dev/null
sleep 2
for i in 1 2 3 4 5; do
  DISPLAY=:1 xfconf-query -c xsettings -p /Xft/Antialias >/dev/null 2>&1 && break
  sleep 1
done
DISPLAY=:1 xfconf-query -c xsettings -p /Xft/Antialias -n -t int -s 1 2>/dev/null || true
DISPLAY=:1 xfconf-query -c xsettings -p /Xft/Hinting -n -t int -s 1 2>/dev/null || true
DISPLAY=:1 xfconf-query -c xsettings -p /Xft/HintStyle -n -t string -s hintfull 2>/dev/null || true
DISPLAY=:1 xfconf-query -c xsettings -p /Xft/RGBA -n -t string -s rgb 2>/dev/null || true
pgrep -f "[w]ebsockify" >/dev/null || (setsid websockify --web=$HOME/noVNC 6080 localhost:5901 >$TMPDIR/ws.log 2>&1 < /dev/null &)
sleep 2
if [ "__TUNNEL__" = "1" ] && ! pgrep -f "[c]loudflared tunnel" >/dev/null; then
  (setsid cloudflared tunnel --url http://localhost:6080 --no-autoupdate >$TMPDIR/cf.log 2>&1 < /dev/null &)
  sleep 15
  grep -oE "https://[a-z0-9-]+\.trycloudflare\.com" $TMPDIR/cf.log | tail -1 > $HOME/tunnel-url.txt
fi
echo "VNC 5901 | noVNC 6080 | tunel: $(cat $HOME/tunnel-url.txt 2>/dev/null)"
EOF
sed -i "s/__GEOMETRY__/$GEOMETRY/g; s/__TUNNEL__/$TUNNEL/g" "$H/start-desktop.sh"
chmod +x "$H/start-desktop.sh"
ln -sf "$H/start-desktop.sh" "$P/bin/desktop"

cat > "$H/show-access.sh" <<'EOF'
#!/data/data/com.termux/files/usr/bin/sh
IP=$(ifconfig 2>/dev/null | sed -n '/^wlan0/,/^$/s/.*inet \([0-9.]*\).*/\1/p' | head -1)
[ -z "$IP" ] && IP="IP-DO-CELULAR"
echo ""
echo "=== Acesso remoto ==="
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
echo "======================"
echo ""
EOF
chmod +x "$H/show-access.sh"
ln -sf "$H/show-access.sh" "$P/bin/url"

step "Banner e autostart no shell"
touch "$H/.bashrc"
sed -i '/# dextermux-start/,/# dextermux-end/d' "$H/.bashrc"
sed -i '/show-access.sh/d; /start-desktop.sh >\/dev\/null 2>&1/d' "$H/.bashrc"
if ! grep -q 'dextermux-start' "$H/.bashrc"; then
    cat >> "$H/.bashrc" <<'EOF'
# dextermux-start
if ! pgrep -f "[X]vnc :1" >/dev/null 2>&1; then setsid $HOME/start-desktop.sh >/dev/null 2>&1 & fi
[ -f $HOME/show-access.sh ] && . $HOME/show-access.sh
# dextermux-end
EOF
fi

step "Autostart no boot"
mkdir -p "$H/.termux/boot"
cat > "$H/.termux/boot/start-services.sh" <<'EOF'
#!/data/data/com.termux/files/usr/bin/sh
$HOME/start-desktop.sh
EOF
chmod +x "$H/.termux/boot/start-services.sh"

step "Chave SSH"
mkdir -p "$H/.ssh"
chmod 700 "$H/.ssh"
if [ -n "$SSH_PUBKEY" ]; then
    grep -qF "$SSH_PUBKEY" "$H/.ssh/authorized_keys" 2>/dev/null || echo "$SSH_PUBKEY" >> "$H/.ssh/authorized_keys"
    chmod 600 "$H/.ssh/authorized_keys"
    echo "Chave adicionada em ~/.ssh/authorized_keys"
else
    echo "Nenhuma SSH_PUBKEY informada. Use de outro PC: ssh-copy-id -p 8022 <usuario>@<ip>"
fi

step "Subindo servicos"
"$H/start-desktop.sh"

cat <<EOF

==================== RESUMO ====================
Usuario:        $(whoami)
VNC local:      vnc://<ip>:5901
noVNC local:    http://<ip>:6080/vnc.html
Tunel publico:  $(cat "$H/tunnel-url.txt" 2>/dev/null || echo "indisponivel")
Senha VNC:      ${VNC_PASS:-"(a existente em ~/.vnc/passwd)"}

Pendencias manuais (nao da para automatizar):
1. Instalar o app Termux:Boot (F-Droid/GitHub) e abrir uma vez.
2. Samsung: Configuracoes > Aplicativos > Termux > Bateria > Sem restricoes.
   Bateria > Limites de uso em segundo plano > Apps que nunca dormem > Termux.
   Remover Termux de "Apps em suspensao" e "em suspensao profunda".
3. Reservar o IP do celular no roteador para nao mudar.
4. Se quiser senha do usuario: passwd
5. Use 'desktop' para religar tudo e 'url' para ver as URLs.
===============================================
EOF
