# shellcheck shell=bash
# 40-session - xstartup, escolha do desktop e comando session

write_xstartup() {
    mkdir -p "$H/.vnc"
    cat >"$H/.vnc/xstartup" <<'EOF'
#!/data/data/com.termux/files/usr/bin/sh
# Gerado por dextermux. Sessao escolhida em ~/.dextermux/desktop.
unset SESSION_MANAGER
export PATH="/data/data/com.termux/files/usr/bin:$PATH"
export XDG_RUNTIME_DIR="$TMPDIR"
export NO_AT_BRIDGE=1
export GTK_A11Y=none

if [ -z "$DBUS_SESSION_BUS_ADDRESS" ] && command -v dbus-launch >/dev/null 2>&1; then
    eval "$(dbus-launch --sh-syntax --exit-with-session)" 2>/dev/null || true
fi

MODE=$(cat "$HOME/.dextermux/desktop" 2>/dev/null || echo cinnamon)
case "$MODE" in
    xfce) exec startxfce4 ;;
    *) exec cinnamon-session ;;
esac
EOF
    chmod +x "$H/.vnc/xstartup"
}

write_session_mode() {
    mkdir -p "$H/.dextermux"
    printf '%s\n' "$DESKTOP" >"$H/.dextermux/desktop"
}

write_xfce_session_config() {
    [ "$DESKTOP" = "xfce" ] || return 0
    local dir="$H/.config/xfce4/xfconf/xfce-perchannel-xml" f
    mkdir -p "$dir" "$H/.config/autostart"
    cat >"$dir/xfce4-session.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>

<channel name="xfce4-session" version="1.0">
  <property name="general" type="empty">
    <property name="FailsafeSessionName" type="string" value="Failsafe"/>
    <property name="LockCommand" type="string" value=""/>
    <property name="TerminalEmulator" type="string" value="xfce4-terminal"/>
    <property name="SaveOnExit" type="bool" value="false"/>
    <property name="LaunchGNOME" type="bool" value="false"/>
  </property>
  <property name="sessions" type="empty">
    <property name="Failsafe" type="empty">
      <property name="IsFailsafe" type="bool" value="true"/>
      <property name="Count" type="int" value="4"/>
      <property name="Client0_Command" type="array">
        <value type="string" value="xfwm4"/>
      </property>
      <property name="Client0_Priority" type="int" value="15"/>
      <property name="Client0_PerScreen" type="bool" value="false"/>
      <property name="Client1_Command" type="array">
        <value type="string" value="xfsettingsd"/>
      </property>
      <property name="Client1_Priority" type="int" value="20"/>
      <property name="Client1_PerScreen" type="bool" value="false"/>
      <property name="Client2_Command" type="array">
        <value type="string" value="xfce4-panel"/>
      </property>
      <property name="Client2_Priority" type="int" value="25"/>
      <property name="Client2_PerScreen" type="bool" value="false"/>
      <property name="Client3_Command" type="array">
        <value type="string" value="xfdesktop"/>
      </property>
      <property name="Client3_Priority" type="int" value="30"/>
      <property name="Client3_PerScreen" type="bool" value="false"/>
    </property>
    <property name="FailsafeWayland" type="empty">
      <property name="IsFailsafe" type="bool" value="true"/>
      <property name="Count" type="int" value="3"/>
      <property name="Client0_Command" type="array">
        <value type="string" value="xfsettingsd"/>
      </property>
      <property name="Client0_Priority" type="int" value="15"/>
      <property name="Client0_PerScreen" type="bool" value="false"/>
      <property name="Client1_Command" type="array">
        <value type="string" value="xfce4-panel"/>
      </property>
      <property name="Client1_Priority" type="int" value="15"/>
      <property name="Client1_PerScreen" type="bool" value="false"/>
      <property name="Client2_Command" type="array">
        <value type="string" value="xfdesktop"/>
      </property>
      <property name="Client2_Priority" type="int" value="15"/>
      <property name="Client2_PerScreen" type="bool" value="false"/>
    </property>
  </property>
</channel>
EOF
    for f in at-spi-dbus-bus gnome-keyring-pkcs11 gnome-keyring-secrets; do
        cat >"$H/.config/autostart/$f.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=$f
Hidden=true
EOF
    done
}

set_xfce_defaults() {
    command -v xfconf-query >/dev/null 2>&1 || return 0
    local _
    for _ in 1 2 3 4 5 6 7 8; do
        if DISPLAY=:1 xfconf-query -c xfce4-session -p /general/TerminalEmulator \
            -s xfce4-terminal 2>/dev/null; then
            break
        fi
        DISPLAY=:1 xfconf-query -c xfce4-session -p /general/TerminalEmulator \
            -n -t string -s xfce4-terminal 2>/dev/null && break
        sleep 1
    done
    DISPLAY=:1 xfconf-query -c xfce4-desktop -p /desktop-icons/style -s 0 2>/dev/null \
        || DISPLAY=:1 xfconf-query -c xfce4-desktop -p /desktop-icons/style -n -t int -s 0 2>/dev/null \
        || true
}

write_session_command() {
    cat >"$H/.dextermux/session.sh" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
# Gerado por dextermux. Mostra ou troca o desktop (cinnamon|xfce).
set -eu
FILE="$HOME/.dextermux/desktop"

installed() {
    case "$1" in
        cinnamon) command -v cinnamon-session >/dev/null 2>&1 ;;
        xfce) command -v startxfce4 >/dev/null 2>&1 ;;
        *) return 1 ;;
    esac
}

show() {
    echo ""
    echo "Desktop atual: $(cat "$FILE" 2>/dev/null || echo cinnamon)"
    for d in cinnamon xfce; do
        if installed "$d"; then
            printf '  %-10s instalado\n' "$d"
        else
            printf '  %-10s ausente\n' "$d"
        fi
    done
    echo ""
}

restart() {
    pkill -f "[X]vnc :1" 2>/dev/null || true
    sleep 1
    rm -f "$TMPDIR/.X1-lock" "$TMPDIR/.X11-unix/X1" "$HOME/.vnc/"*:1.pid 2>/dev/null || true
    "$HOME/start-desktop.sh" >/dev/null 2>&1 || true
    "$HOME/show-access.sh"
}

case "${1:-}" in
    "")
        show
        ;;
    cinnamon|xfce)
        if ! installed "$1"; then
            echo "desktop nao instalado: $1" >&2
            echo "rode: bash setup.sh --desktop=$1" >&2
            exit 1
        fi
        echo "$1" >"$FILE"
        restart
        ;;
    *)
        echo "uso: session [cinnamon|xfce]" >&2
        exit 1
        ;;
esac
EOF
    chmod +x "$H/.dextermux/session.sh"
    ln -sf "$H/.dextermux/session.sh" "$P/bin/session"
}
