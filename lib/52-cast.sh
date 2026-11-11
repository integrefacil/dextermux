# shellcheck shell=bash
# 52-cast - cast para TV na LAN, controle pelo celular, teclado e status

write_cast_mode() {
    mkdir -p "$H/.dextermux"
    printf '%s\n' "$CAST_MODE" >"$H/.dextermux/cast"
    printf '%s\n' "$CAST_KIND" >"$H/.dextermux/cast-mode"
    printf '%s\n' "$CAST_QUALITY" >"$H/.dextermux/cast-quality"
    printf '%s\n' "$KEYBOARD_LAYOUT" >"$H/.dextermux/keyboard"
    printf '%s\n' "$GEOMETRY" >"$H/.dextermux/geometry"
}

write_cast_pages() {
    mkdir -p "$H/.dextermux"
    if [ ! -d "$H/noVNC" ]; then
        warn "noVNC ausente; paginas de cast nao foram geradas"
        return 0
    fi

    write_tv_page
    write_remote_page
    write_stream_page
    write_dlna_helper
    ok "paginas de cast prontas (tv.html, remote.html, stream.html)"
}

write_tv_page() {
    cat >"$H/noVNC/tv.html" <<'HTMLEOF'
<!DOCTYPE html>
<html lang="pt-BR">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
<title>dextermux tv</title>
<style>
  html, body { margin: 0; padding: 0; background: #000; color: #e8e8e8;
    font-family: system-ui, sans-serif; overflow: hidden; height: 100%; }
  #screen { position: absolute; inset: 0; }
  #screen canvas { image-rendering: auto; }
  #hud { position: fixed; right: 24px; bottom: 24px; display: flex; gap: 8px;
    flex-wrap: wrap; justify-content: flex-end; max-width: 70vw; opacity: 0.18;
    transition: opacity 200ms; z-index: 20; }
  #hud:hover, #hud.show { opacity: 1; }
  #hud button { font-size: 22px; min-width: 64px; min-height: 64px; border-radius: 12px;
    border: 1px solid #444; background: rgba(20,20,20,0.92); color: #eee; }
  #hud button:active { background: #2d5c8a; }
  #hud .wide { min-width: 96px; font-size: 18px; }
  #overlay { position: fixed; inset: 0; display: none; align-items: center;
    justify-content: center; background: rgba(0,0,0,0.85); z-index: 40; }
  #overlay.show { display: flex; }
  #overlay .box { text-align: center; max-width: 80vw; }
  #overlay h1 { font-size: 34px; margin: 0 0 8px; }
  #overlay p { font-size: 22px; color: #bbb; margin: 8px 0 20px; }
  #overlay input { font-size: 28px; padding: 12px 16px; border-radius: 10px;
    border: 1px solid #555; background: #111; color: #fff; text-align: center; }
  #overlay button { font-size: 24px; padding: 12px 24px; margin-left: 8px;
    border-radius: 10px; border: 1px solid #555; background: #1d1d1d; color: #fff; }
</style>
</head>
<body>
<div id="screen"></div>
<div id="hud">
  <button data-key="ArrowLeft">&#9664;</button>
  <button data-key="ArrowUp">&#9650;</button>
  <button data-key="ArrowDown">&#9660;</button>
  <button data-key="ArrowRight">&#9654;</button>
  <button data-key="Enter" class="wide">OK</button>
  <button data-key="Escape" class="wide">Voltar</button>
  <button data-key="Menu" class="wide">Menu</button>
  <button data-action="full" class="wide">Tela cheia</button>
</div>
<div id="overlay"><div class="box">
  <h1 id="ov-title">Conectando</h1>
  <p id="ov-text">Aguardando o servidor dextermux</p>
  <div id="ov-input" style="display:none">
    <input id="ov-pass" type="password" inputmode="text" autocomplete="off" placeholder="senha">
    <button id="ov-send">Entrar</button>
  </div>
</div></div>
<script type="module">
import RFB from './core/rfb.js';

const params = new URLSearchParams(location.search);
const proto = location.protocol === 'https:' ? 'wss' : 'ws';
const url = `${proto}://${location.hostname}:${location.port || (proto === 'wss' ? 443 : 80)}/websockify`;
const screen = document.getElementById('screen');
const overlay = document.getElementById('overlay');
const ovTitle = document.getElementById('ov-title');
const ovText = document.getElementById('ov-text');
const ovInput = document.getElementById('ov-input');
const ovPass = document.getElementById('ov-pass');

const KEYS = {
  ArrowUp: [0xff52, 'ArrowUp'], ArrowDown: [0xff54, 'ArrowDown'],
  ArrowLeft: [0xff51, 'ArrowLeft'], ArrowRight: [0xff53, 'ArrowRight'],
  Enter: [0xff0d, 'Enter'], Escape: [0xff1b, 'Escape'], Tab: [0xff09, 'Tab'],
  Backspace: [0xff08, 'Backspace'], Delete: [0xffff, 'Delete'],
  Home: [0xff50, 'Home'], End: [0xff57, 'End'],
  PageUp: [0xff55, 'PageUp'], PageDown: [0xff56, 'PageDown'],
};

let rfb = null;
let retry = null;

function show(title, text, needPass) {
  ovTitle.textContent = title;
  ovText.textContent = text;
  ovInput.style.display = needPass ? 'block' : 'none';
  overlay.classList.add('show');
  if (needPass) { ovPass.value = ''; ovPass.focus(); }
}

function hide() { overlay.classList.remove('show'); }

function keysymFor(ch) {
  if (ch.length === 1) {
    const c = ch.codePointAt(0);
    if (c < 0x100) return c;
    return 0x01000000 | c;
  }
  return null;
}

function sendKey(name, down) {
  if (!rfb) return;
  if (name === 'Menu') {
    if (down) { rfb.sendKey(0xffe1, 'ShiftLeft', true); rfb.sendKey(0xffc7, 'F10', true); }
    else { rfb.sendKey(0xffc7, 'F10', false); rfb.sendKey(0xffe1, 'ShiftLeft', false); }
    return;
  }
  const hit = KEYS[name];
  if (hit) { rfb.sendKey(hit[0], hit[1], down); return; }
  const ks = keysymFor(name);
  if (ks !== null) rfb.sendKey(ks, name.length === 1 ? 'Key' + name.toUpperCase() : name, down);
}

for (const btn of document.querySelectorAll('#hud button[data-key]')) {
  btn.addEventListener('click', () => {
    const key = btn.dataset.key;
    sendKey(key, true);
    setTimeout(() => sendKey(key, false), 60);
  });
}
document.querySelector('#hud button[data-action="full"]').addEventListener('click', () => {
  if (document.fullscreenElement) document.exitFullscreen();
  else document.documentElement.requestFullscreen().catch(() => {});
});
ovPass.addEventListener('keydown', (ev) => {
  if (ev.key === 'Enter') document.getElementById('ov-send').click();
});
document.getElementById('ov-send').addEventListener('click', () => {
  if (!rfb) return;
  rfb.sendCredentials({ password: ovPass.value });
  hide();
});

window.addEventListener('keydown', (ev) => {
  if (overlay.classList.contains('show')) return;
  if (ev.ctrlKey || ev.altKey || ev.metaKey) return;
  if (!rfb) return;
  if (KEYS[ev.key] || ev.key.length === 1) {
    sendKey(ev.key, true);
    if (ev.key === 'Tab' || ev.key === ' ' || ev.key.startsWith('Arrow')) ev.preventDefault();
  }
});
window.addEventListener('keyup', (ev) => {
  if (!rfb) return;
  if (KEYS[ev.key] || ev.key.length === 1) sendKey(ev.key, false);
});

if (navigator.wakeLock) navigator.wakeLock.request('screen').catch(() => {});

function connect() {
  clearTimeout(retry);
  show('Conectando', 'Aguardando o servidor dextermux', false);
  const pass = params.get('password');
  rfb = new RFB(screen, url, {
    credentials: pass ? { password: pass } : undefined,
  });
  rfb.scaleViewport = true;
  rfb.resizeSession = false;
  rfb.clipViewport = false;
  rfb.background = '#000000';
  rfb.addEventListener('connect', () => {
    hide();
    document.getElementById('hud').classList.add('show');
    setTimeout(() => document.getElementById('hud').classList.remove('show'), 4000);
  });
  rfb.addEventListener('credentialsrequired', () => {
    if (params.get('password')) return;
    show('Senha do VNC', 'Digite com o controle remoto', true);
  });
  rfb.addEventListener('securityfailure', (ev) => {
    show('Falha de senha', ev.detail && ev.detail.reason ? ev.detail.reason : 'senha recusada', true);
  });
  rfb.addEventListener('disconnect', () => {
    rfb = null;
    show('Desconectado', 'Reconectando em 2 segundos', false);
    retry = setTimeout(connect, 2000);
  });
}

connect();
</script>
</body>
</html>
HTMLEOF
}

write_stream_page() {
    cat >"$H/noVNC/stream.html" <<'HTMLEOF'
<!DOCTYPE html>
<html lang="pt-BR">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>dextermux stream</title>
<style>
  html, body { margin: 0; height: 100%; background: #000; color: #ddd;
    font-family: system-ui, sans-serif; overflow: hidden; }
  #feed { display: block; width: 100vw; height: 100vh; object-fit: contain; }
  #tip { position: fixed; left: 16px; bottom: 16px; font-size: 18px;
    color: #888; background: rgba(0,0,0,0.6); padding: 8px 12px; border-radius: 8px; }
  #tip.hide { display: none; }
</style>
</head>
<body>
<img id="feed" alt="desktop">
<div id="tip">modo MJPEG: imagem sem controle. Use remote.html no celular.</div>
<script>
  document.getElementById('feed').src = 'http://' + location.hostname + ':6082/live.mjpg';
  document.getElementById('tip').addEventListener('click', (e) => e.target.classList.add('hide'));
</script>
</body>
</html>
HTMLEOF

}

write_remote_page() {
    cat >"$H/noVNC/remote.html" <<'HTMLEOF'
<!DOCTYPE html>
<html lang="pt-BR">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
<title>dextermux controle</title>
<style>
  :root { color-scheme: dark; }
  html, body { margin: 0; background: #101114; color: #e6e6e6; height: 100%;
    font-family: system-ui, sans-serif; overflow: hidden; touch-action: none; }
  #top { display: flex; gap: 8px; padding: 8px; font-size: 13px; color: #9aa0a6; }
  #top .dot { width: 10px; height: 10px; border-radius: 50%; background: #b3261e; margin-top: 4px; }
  #top .dot.on { background: #34a853; }
  #preview { position: fixed; right: 8px; top: 36px; width: 168px; height: 95px;
    border: 1px solid #333; border-radius: 8px; overflow: hidden; opacity: 0.85; }
  #pad { position: absolute; left: 0; right: 0; top: 36px; bottom: 132px;
    touch-action: none; user-select: none; -webkit-tap-highlight-color: transparent;
    background: radial-gradient(circle at 50% 40%, #1b1e23, #0c0d10); }
  #keys { position: absolute; left: 0; right: 0; bottom: 0; padding: 6px; display: grid;
    grid-template-columns: repeat(6, 1fr); gap: 6px; background: #17191d; }
  #keys button { min-height: 38px; font-size: 14px; border-radius: 8px;
    border: 1px solid #333; background: #202329; color: #e8e8e8; }
  #keys button.active { background: #2d5c8a; }
  #keys .on { background: #23405e; }
  #hint { position: absolute; left: 12px; bottom: 150px; font-size: 12px; color: #6b7280; }
</style>
</head>
<body>
<div id="top"><span class="dot" id="dot"></span><span id="state">conectando</span></div>
<div id="preview"><div id="screen"></div></div>
<div id="pad"></div>
<div id="hint">arraste para mover, toque para clicar, segure e arraste para mover janela</div>
<div id="keys"></div>
<script type="module">
import RFB from './core/rfb.js';

const params = new URLSearchParams(location.search);
const proto = location.protocol === 'https:' ? 'wss' : 'ws';
const url = `${proto}://${location.hostname}:${location.port || (proto === 'wss' ? 443 : 80)}/websockify`;
const geom = (window.DEXTERMUX_GEOMETRY || '__GEOMETRY__').split('x');
let fbW = parseInt(geom[0], 10) || 1600;
let fbH = parseInt(geom[1], 10) || 900;

const screen = document.getElementById('screen');
const pad = document.getElementById('pad');
const state = document.getElementById('state');
const dot = document.getElementById('dot');
const keysBar = document.getElementById('keys');

let rfb = null;
let px = Math.round(fbW / 2);
let py = Math.round(fbH / 2);
let dragging = false;
let holdTimer = null;
let startPt = null;
let lastPt = null;
let moved = false;
let scrollLast = null;
let lastTouchAt = 0;

const KEYS = {
  Escape: 0xff1b, Tab: 0xff09, Enter: 0xff0d, BackSpace: 0xff08, Delete: 0xffff,
  ArrowUp: 0xff52, ArrowDown: 0xff54, ArrowLeft: 0xff51, ArrowRight: 0xff53,
  Home: 0xff50, End: 0xff57, PageUp: 0xff55, PageDown: 0xff56,
  ShiftLeft: 0xffe1, ControlLeft: 0xffe3, AltLeft: 0xffe9, MetaLeft: 0xffeb,
};
for (let i = 1; i <= 12; i++) KEYS['F' + i] = 0xffbe + (i - 1);

function setState(text, on) {
  state.textContent = text;
  dot.classList.toggle('on', !!on);
}

function keysymFor(ch) {
  const c = ch.codePointAt(0);
  return c < 0x100 ? c : 0x01000000 | c;
}

function codeFor(name) {
  if (name.length === 1 && /[a-z]/i.test(name)) return 'Key' + name.toUpperCase();
  if (name.length === 1 && /[0-9]/.test(name)) return 'Digit' + name;
  return name;
}

function keyDown(name) { if (rfb) rfb.sendKey(KEYS[name] || keysymFor(name), codeFor(name), true); }
function keyUp(name) { if (rfb) rfb.sendKey(KEYS[name] || keysymFor(name), codeFor(name), false); }

function screenCanvas() { return screen.querySelector('canvas'); }

// noVNC 1.5 nao expoe sendPointer: o caminho e despachar eventos de mouse no
// canvas, que o RFB converte em PointerEvent do protocolo VNC
function canvasClient() {
  const c = screenCanvas();
  if (!c) return null;
  const r = c.getBoundingClientRect();
  if (!r.width || !r.height) return null;
  return {
    c,
    x: r.left + (px / fbW) * r.width,
    y: r.top + (py / fbH) * r.height,
  };
}

function emit(type, extra) {
  const p = canvasClient();
  if (!p) return;
  p.c.dispatchEvent(new MouseEvent(type, Object.assign({
    clientX: p.x, clientY: p.y, bubbles: true, cancelable: true, view: window,
  }, extra || {})));
}

function move(dx, dy) {
  px = Math.min(fbW - 1, Math.max(0, px + dx));
  py = Math.min(fbH - 1, Math.max(0, py + dy));
  emit('mousemove', { buttons: dragging ? 1 : 0 });
}

function click(button) {
  const b = button === 'right' ? 2 : 0;
  emit('mousedown', { button: b, buttons: b === 2 ? 2 : 1 });
  emit('mouseup', { button: b, buttons: 0 });
}

function wheel(dy) { emit('wheel', { deltaY: dy }); }

function isTouchRecent() { return Date.now() - lastTouchAt < 700; }

pad.addEventListener('touchstart', (ev) => {
  lastTouchAt = Date.now();
  if (ev.touches.length === 2) {
    scrollLast = ev.touches[0].clientY;
    lastPt = null;
    return;
  }
  const t = ev.touches[0];
  startPt = { x: t.clientX, y: t.clientY };
  lastPt = { x: t.clientX, y: t.clientY };
  moved = false;
  clearTimeout(holdTimer);
  holdTimer = setTimeout(() => {
    dragging = true;
    emit('mousedown', { button: 0, buttons: 1 });
  }, 450);
}, { passive: true });

pad.addEventListener('touchmove', (ev) => {
  ev.preventDefault();
  lastTouchAt = Date.now();
  if (ev.touches.length === 2) {
    const y = ev.touches[0].clientY;
    if (scrollLast !== null) wheel((scrollLast - y) * 8);
    scrollLast = y;
    return;
  }
  const t = ev.touches[0];
  if (!lastPt) lastPt = { x: t.clientX, y: t.clientY };
  if (startPt && Math.hypot(t.clientX - startPt.x, t.clientY - startPt.y) > 8) {
    moved = true;
    if (!dragging) { clearTimeout(holdTimer); holdTimer = null; }
  }
  const dx = (t.clientX - lastPt.x) * (fbW / Math.max(1, pad.clientWidth));
  const dy = (t.clientY - lastPt.y) * (fbH / Math.max(1, pad.clientHeight));
  lastPt = { x: t.clientX, y: t.clientY };
  move(dx, dy);
}, { passive: false });

pad.addEventListener('touchend', (ev) => {
  lastTouchAt = Date.now();
  clearTimeout(holdTimer);
  holdTimer = null;
  if (ev.touches.length > 0) return;
  if (dragging) { emit('mouseup', { button: 0, buttons: 0 }); dragging = false; }
  else if (!moved) click('left');
  startPt = null;
  lastPt = null;
  scrollLast = null;
}, { passive: true });

pad.addEventListener('mousemove', (ev) => {
  if (isTouchRecent()) return;
  const r = pad.getBoundingClientRect();
  if (!r.width || !r.height) return;
  px = Math.min(fbW - 1, Math.max(0, ((ev.clientX - r.left) / r.width) * fbW));
  py = Math.min(fbH - 1, Math.max(0, ((ev.clientY - r.top) / r.height) * fbH));
  emit('mousemove', { buttons: ev.buttons });
});

pad.addEventListener('mousedown', (ev) => {
  if (isTouchRecent()) return;
  emit('mousedown', { button: ev.button, buttons: ev.buttons });
});

pad.addEventListener('mouseup', (ev) => {
  if (isTouchRecent()) return;
  emit('mouseup', { button: ev.button, buttons: 0 });
});

pad.addEventListener('contextmenu', (ev) => { ev.preventDefault(); });

window.addEventListener('keydown', (ev) => {
  if (ev.key === 'Shift') return keyDown('ShiftLeft');
  if (ev.key === 'Control') return keyDown('ControlLeft');
  if (ev.key === 'Alt') return keyDown('AltLeft');
  if (ev.key === 'Meta') return keyDown('MetaLeft');
  if (KEYS[ev.key] || ev.key.length === 1) {
    keyDown(ev.key);
    if (ev.key === 'Tab' || ev.key.startsWith('Arrow')) ev.preventDefault();
  } else if (KEYS[ev.code]) {
    keyDown(ev.code);
  }
});
window.addEventListener('keyup', (ev) => {
  if (ev.key === 'Shift') return keyUp('ShiftLeft');
  if (ev.key === 'Control') return keyUp('ControlLeft');
  if (ev.key === 'Alt') return keyUp('AltLeft');
  if (ev.key === 'Meta') return keyUp('MetaLeft');
  if (KEYS[ev.key] || ev.key.length === 1) keyUp(ev.key);
  else if (KEYS[ev.code]) keyUp(ev.code);
});

const combos = [
  ['Ctrl', 'ControlLeft'], ['Alt', 'AltLeft'], ['Shift', 'ShiftLeft'],
  ['Super', 'MetaLeft'], ['Esc', 'Escape'], ['Tab', 'Tab'],
  ['Enter', 'Enter'], ['Back', 'BackSpace'], ['Del', 'Delete'],
  ['Up', 'ArrowUp'], ['Down', 'ArrowDown'], ['Left', 'ArrowLeft'], ['Right', 'ArrowRight'],
  ['F1', 'F1'], ['F2', 'F2'], ['F5', 'F5'], ['F10', 'F10'], ['F11', 'F11'],
];
for (const [label, name] of combos) {
  const btn = document.createElement('button');
  btn.textContent = label;
  btn.dataset.name = name;
  btn.addEventListener('touchstart', (ev) => { ev.preventDefault(); btn.classList.add('active'); keyDown(name); }, { passive: false });
  btn.addEventListener('touchend', (ev) => { ev.preventDefault(); btn.classList.remove('active'); keyUp(name); }, { passive: false });
  btn.addEventListener('mousedown', () => { btn.classList.add('active'); keyDown(name); });
  btn.addEventListener('mouseup', () => { btn.classList.remove('active'); keyUp(name); });
  keysBar.appendChild(btn);
}

for (const [label, side] of [['Clique', 'left'], ['Dir', 'right']]) {
  const btn = document.createElement('button');
  btn.textContent = label;
  btn.addEventListener('click', () => click(side));
  keysBar.appendChild(btn);
}

if (navigator.wakeLock) navigator.wakeLock.request('screen').catch(() => {});

function connect() {
  rfb = new RFB(screen, url, {
    credentials: params.get('password') ? { password: params.get('password') } : undefined,
  });
  rfb.scaleViewport = true;
  rfb.resizeSession = false;
  rfb.clipViewport = false;
  rfb.viewOnly = false;
  rfb.focusOnClick = true;
  rfb.addEventListener('connect', () => {
    setState('conectado', true);
    const canvas = screen.querySelector('canvas');
    if (canvas && canvas.width && canvas.height) {
      fbW = canvas.width;
      fbH = canvas.height;
      px = Math.round(fbW / 2);
      py = Math.round(fbH / 2);
    }
  });
  rfb.addEventListener('credentialsrequired', () => {
    const pass = prompt('senha do VNC');
    if (pass) rfb.sendCredentials({ password: pass });
  });
  rfb.addEventListener('disconnect', () => {
    setState('reconectando', false);
    rfb = null;
    setTimeout(connect, 2000);
  });
}

connect();
</script>
</body>
</html>
HTMLEOF

    sed -i "s/__GEOMETRY__/$GEOMETRY/g" "$H/noVNC/remote.html"
}

write_dlna_helper() {
    cat >"$H/.dextermux/dlna.py" <<'PYEOF'
#!/usr/bin/env python3
"""Descoberta SSDP de MediaRenderer para o cast DLNA do dextermux."""
import socket
import sys
import urllib.request
import xml.etree.ElementTree as ET

SEARCH = (
    "M-SEARCH * HTTP/1.1\r\n"
    "HOST: 239.255.255.250:1900\r\n"
    'MAN: "ssdp:discover"\r\n'
    "MX: 2\r\n"
    "ST: urn:schemas-upnp-org:device:MediaRenderer:1\r\n\r\n"
)


def discover(timeout=3.0):
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.settimeout(timeout)
    sock.setsockopt(socket.IPPROTO_IP, socket.IP_MULTICAST_TTL, 2)
    try:
        sock.sendto(SEARCH.encode(), ("239.255.255.250", 1900))
    except OSError:
        return []
    seen = []
    while True:
        try:
            data, addr = sock.recvfrom(4096)
        except socket.timeout:
            break
        text = data.decode("utf-8", "replace")
        location = ""
        for line in text.splitlines():
            if line.lower().startswith("location:"):
                location = line.split(":", 1)[1].strip()
        if location and location not in seen:
            seen.append(location)
    return seen


def describe(location):
    with urllib.request.urlopen(location, timeout=4) as resp:
        root = ET.fromstring(resp.read())
    ns = {"u": "urn:schemas-upnp-org:device-1-0"}
    friendly = (root.findtext(".//u:device/u:friendlyName", default="", namespaces=ns) or "").strip()
    base = (root.findtext(".//u:URLBase", default="", namespaces=ns) or "").strip()
    if not base:
        base = location.rsplit("/", 1)[0] + "/"
    control = ""
    for svc in root.findall(".//u:service", ns):
        if (svc.findtext("u:serviceType", default="", namespaces=ns) or "").startswith(
            "urn:schemas-upnp-org:service:AVTransport:"
        ):
            control = (svc.findtext("u:controlURL", default="", namespaces=ns) or "").strip()
    if not control:
        return None
    if control.startswith("http"):
        url = control
    else:
        url = base.rstrip("/") + "/" + control.lstrip("/")
    return friendly or location, url


def main():
    if len(sys.argv) > 1 and sys.argv[1] == "describe":
        info = describe(sys.argv[2])
        if info:
            print("%s\t%s" % info)
        return
    for location in discover():
        try:
            info = describe(location)
        except Exception:
            continue
        if info:
            print("%s\t%s" % info)


if __name__ == "__main__":
    main()
PYEOF
    chmod +x "$H/.dextermux/dlna.py"
}

write_cast_command() {
    cat >"$H/.dextermux/cast.sh" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
# Gerado por dextermux. Cast para TV na LAN: pagina, controle, MJPEG e DLNA.
set -eu
DIR="$HOME/.dextermux"
PORT=6080
CASTPORT=6081
STREAMPORT=6082
DLNAPORT=6090

ip() {
    ifconfig 2>/dev/null | sed -n '/^wlan0/,/^$/s/.*inet \([0-9.]*\) .*/\1/p' | head -1
}
state() {
    cat "$DIR/$1" 2>/dev/null || echo "$2"
}
tls_on() { [ "$(state tls/mode 0)" = "1" ]; }
cast_on() { [ "$(state cast 0)" = "1" ]; }
quality() { state cast-quality 720p; }
geometry() { state geometry 1600x900; }

tv_url() {
    local host scheme
    host=$(ip)
    [ -z "$host" ] && host="IP-DO-CELULAR"
    if tls_on; then scheme=https; else scheme=http; fi
    printf '%s://%s:%s/tv.html\n' "$scheme" "$host" "$PORT"
}

remote_url() {
    local host scheme
    host=$(ip)
    [ -z "$host" ] && host="IP-DO-CELULAR"
    if tls_on; then scheme=https; else scheme=http; fi
    printf '%s://%s:%s/remote.html\n' "$scheme" "$host" "$PORT"
}

plain_tv_url() {
    local host
    host=$(ip)
    [ -z "$host" ] && host="IP-DO-CELULAR"
    printf 'http://%s:%s/tv.html\n' "$host" "$CASTPORT"
}

stream_url() {
    local host
    host=$(ip)
    [ -z "$host" ] && host="IP-DO-CELULAR"
    printf 'http://%s:%s/stream.html\n' "$host" "$CASTPORT"
}

require_novnc() {
    if [ ! -f "$HOME/noVNC/tv.html" ]; then
        echo "paginas de cast ausentes; rode: bash setup.sh --repair" >&2
        exit 1
    fi
}

restart() {
    pkill -f "[w]ebsockify.*$CASTPORT" 2>/dev/null || true
    "$HOME/start-desktop.sh" >/dev/null 2>&1 || true
}

write_state() { printf '%s\n' "$2" >"$DIR/$1"; }

on() {
    local kind="${1:-}"
    require_novnc
    if [ -n "$kind" ]; then
        case "$kind" in
            novnc|mjpeg) write_state cast-mode "$kind" ;;
            *) echo "modo invalido: $kind (novnc|mjpeg)" >&2; exit 1 ;;
        esac
    fi
    write_state cast 1
    restart
    echo "cast ligado ($(state cast-mode novnc))"
    echo "TV:      $(tv_url)"
    if tls_on; then
        echo "TV http: $(plain_tv_url)"
    fi
    echo "celular: $(remote_url)"
}

off() {
    write_state cast 0
    pkill -f "[w]ebsockify.*$CASTPORT" 2>/dev/null || true
    pkill -f "[f]fmpeg.*$STREAMPORT" 2>/dev/null || true
    pkill -f "[f]fmpeg.*$DLNAPORT" 2>/dev/null || true
    restart
    echo "cast desligado"
}

status() {
    echo "cast:     $(state cast 0) ($(state cast-mode novnc))"
    echo "qualidade: $(quality)"
    echo "geometria: $(geometry)"
    echo "teclado:  $(state keyboard br)"
    if pgrep -f "[X]vnc :1" >/dev/null; then echo "xvnc:     ativo"; else echo "xvnc:     parado"; fi
    if pgrep -f "[w]ebsockify.*$PORT" >/dev/null; then echo "novnc:    ativo"; else echo "novnc:    parado"; fi
    if pgrep -f "[w]ebsockify.*$CASTPORT" >/dev/null; then echo "novnc http: ativo"; fi
    if pgrep -f "[f]fmpeg.*$STREAMPORT" >/dev/null; then echo "mjpeg:    ativo"; fi
    if pgrep -f "[f]fmpeg.*$DLNAPORT" >/dev/null; then echo "dlna:     ativo"; fi
    echo "TV:       $(tv_url)"
    echo "celular:  $(remote_url)"
}

qr() {
    local url
    url=$(tv_url)
    echo "$url"
    if command -v qrencode >/dev/null 2>&1; then
        qrencode -t ANSIUTF8 "$url"
    else
        echo "instale o gerador de QR com: pkg install qrencode"
    fi
}

quality_cmd() {
    local q="${1:-}"
    case "$q" in
        720p|1080p) write_state cast-quality "$q"; echo "qualidade: $q" ;;
        "") quality ;;
        *) echo "uso: cast quality 720p|1080p" >&2; exit 1 ;;
    esac
}

stream_on() {
    require_novnc
    if [ ! -S "$TMPDIR/.X11-unix/X1" ] && ! pgrep -f "[X]vnc :1" >/dev/null; then
        echo "sessao grafica parada; rode: desktop" >&2
        exit 1
    fi
    if ! command -v ffmpeg >/dev/null 2>&1; then
        echo "ffmpeg ausente; rode: pkg install ffmpeg" >&2
        exit 1
    fi
    if ! ffmpeg -hide_banner -devices 2>/dev/null | grep -q x11grab; then
        echo "este ffmpeg nao tem x11grab; use o modo novnc" >&2
        exit 1
    fi
    pkill -f "[f]fmpeg.*$STREAMPORT" 2>/dev/null || true
    local scale
    case "$(quality)" in
        1080p) scale="1920:-2" ;;
        *) scale="1280:-2" ;;
    esac
    setsid ffmpeg -hide_banner -loglevel error -f x11grab -framerate 20 -i :1 \
        -vf "scale=$scale" -c:v mjpeg -q:v 7 -f mpjpeg -listen 1 \
        "http://0.0.0.0:$STREAMPORT/live.mjpg" \
        >"$TMPDIR/cast-mjpeg.log" 2>&1 </dev/null &
    sleep 2
    echo "mjpeg ativo"
    echo "TV: $(stream_url)"
}

stream_off() {
    pkill -f "[f]fmpeg.*$STREAMPORT" 2>/dev/null || true
    echo "mjpeg parado"
}

soap() {
    local control action body
    control="$1"
    action="$2"
    body="$3"
    curl -fsS -m 8 -X POST "$control" \
        -H 'Content-Type: text/xml; charset="utf-8"' \
        -H "SOAPAction: \"urn:schemas-upnp-org:service:AVTransport:1#$action\"" \
        --data "$body" >/dev/null
}

soap_set_uri() {
    soap "$1" SetAVTransportURI "<?xml version=\"1.0\" encoding=\"utf-8\"?>
<s:Envelope xmlns:s=\"http://schemas.xmlsoap.org/soap/envelope/\" s:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\">
<s:Body><u:SetAVTransportURI xmlns:u=\"urn:schemas-upnp-org:service:AVTransport:1\">
<InstanceID>0</InstanceID><CurrentURI>$2</CurrentURI><CurrentURIMetaData></CurrentURIMetaData>
</u:SetAVTransportURI></s:Body></s:Envelope>"
}

soap_play() {
    soap "$1" Play "<?xml version=\"1.0\" encoding=\"utf-8\"?>
<s:Envelope xmlns:s=\"http://schemas.xmlsoap.org/soap/envelope/\" s:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\">
<s:Body><u:Play xmlns:u=\"urn:schemas-upnp-org:service:AVTransport:1\">
<InstanceID>0</InstanceID><Speed>1</Speed>
</u:Play></s:Body></s:Envelope>"
}

soap_stop() {
    soap "$1" Stop "<?xml version=\"1.0\" encoding=\"utf-8\"?>
<s:Envelope xmlns:s=\"http://schemas.xmlsoap.org/soap/envelope/\" s:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\">
<s:Body><u:Stop xmlns:u=\"urn:schemas-upnp-org:service:AVTransport:1\">
<InstanceID>0</InstanceID>
</u:Stop></s:Body></s:Envelope>"
}

dlna_find() {
    local renderer="$1" out
    if [ -n "$renderer" ]; then
        out=$(python3 "$DIR/dlna.py" describe "$renderer" 2>/dev/null || true)
    else
        out=$(python3 "$DIR/dlna.py" 2>/dev/null | head -1 || true)
    fi
    if [ -z "$out" ]; then
        echo "nenhum MediaRenderer respondeu ao SSDP" >&2
        echo "informe a URL do descritor: cast dlna http://IP:PORTA/desc.xml" >&2
        exit 1
    fi
    printf '%s\n' "$out"
}

dlna_on() {
    local renderer="${1:-}" name control host url
    if ! command -v ffmpeg >/dev/null 2>&1; then
        echo "ffmpeg ausente; rode: pkg install ffmpeg" >&2
        exit 1
    fi
    if ! ffmpeg -hide_banner -devices 2>/dev/null | grep -q x11grab; then
        echo "este ffmpeg nao tem x11grab; use o modo novnc" >&2
        exit 1
    fi
    read -r name control < <(dlna_find "$renderer" | awk -F'\t' '{print $1" "$2}')
    host=$(ip)
    [ -z "$host" ] && host="IP-DO-CELULAR"
    url="http://$host:$DLNAPORT/live.ts"
    pkill -f "[f]fmpeg.*$DLNAPORT" 2>/dev/null || true
    local scale
    case "$(quality)" in
        1080p) scale="1920:-2" ;;
        *) scale="1280:-2" ;;
    esac
    setsid ffmpeg -hide_banner -loglevel error -f x11grab -framerate 20 -i :1 \
        -vf "scale=$scale" -c:v libx264 -preset ultrafast -tune zerolatency \
        -g 20 -b:v 4M -pix_fmt yuv420p -f mpegts -listen 1 \
        "http://0.0.0.0:$DLNAPORT/live.ts" >"$TMPDIR/cast-dlna.log" 2>&1 </dev/null &
    sleep 3
    soap_set_uri "$control" "$url" || { echo "falha no SOAP SetAVTransportURI" >&2; exit 1; }
    soap_play "$control" || true
    echo "dlna: $name"
    echo "stream: $url"
    echo "aviso: DLNA tem buffer de 1 a 5 segundos e nao aceita input"
}

dlna_off() {
    local renderer="${1:-}" name control
    read -r name control < <(dlna_find "$renderer" | awk -F'\t' '{print $1" "$2}')
    soap_stop "$control" 2>/dev/null || true
    pkill -f "[f]fmpeg.*$DLNAPORT" 2>/dev/null || true
    echo "dlna parado"
}

usage() {
    cat <<'TXT'
uso: cast [on [novnc|mjpeg] | off | status | url | qr | quality [720p|1080p]]
          cast stream on|off
          cast dlna [URL-DO-DESCRITOR] | dlna off
TXT
}

case "${1:-status}" in
    on) shift; on "${1:-}" ;;
    off) off ;;
    status) status ;;
    url) echo "TV:      $(tv_url)"; echo "celular: $(remote_url)"; [ "$(state cast 0)" = "1" ] && tls_on && echo "TV http: $(plain_tv_url)" ;;
    qr) qr ;;
    quality) shift; quality_cmd "${1:-}" ;;
    stream) shift
        if [ "${1:-on}" = "off" ]; then stream_off; else stream_on; fi ;;
    dlna) shift
        if [ "${1:-}" = "off" ]; then dlna_off "${2:-}"; else dlna_on "${1:-}"; fi ;;
    *) usage; exit 1 ;;
esac
EOF
    chmod +x "$H/.dextermux/cast.sh"
    ln -sf "$H/.dextermux/cast.sh" "$P/bin/cast"
}

write_keyboard_command() {
    cat >"$H/.dextermux/keyboard.sh" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
# Gerado por dextermux. Aplica o layout do teclado fisico/Bluetooth no X.
set -eu
DIR="$HOME/.dextermux"

apply() {
    local layout="$1" variant=""
    case "$layout" in
        abnt2) layout="br"; variant=" -variant abnt2" ;;
        br|us|es) variant="" ;;
        *) echo "layout invalido: $1 (br|us|es|abnt2)" >&2; exit 1 ;;
    esac
    if ! command -v setxkbmap >/dev/null 2>&1; then
        if command -v pkg >/dev/null 2>&1; then
            echo "instalando xorg-setxkbmap"
            pkg install -y xorg-setxkbmap >/dev/null 2>&1 || true
        fi
    fi
    if ! command -v setxkbmap >/dev/null 2>&1; then
        echo "setxkbmap ausente; rode: pkg install xorg-setxkbmap" >&2
        exit 1
    fi
    if ! pgrep -f "[X]vnc :1" >/dev/null; then
        echo "sessao grafica parada; rode: desktop" >&2
        exit 1
    fi
    # shellcheck disable=SC2086
    DISPLAY=:1 setxkbmap -layout "$layout" $variant
    printf '%s\n' "$1" >"$DIR/keyboard"
    echo "layout do X: $1"
    DISPLAY=:1 setxkbmap -query 2>/dev/null || true
}

show() {
    echo "configurado: $(cat "$DIR/keyboard" 2>/dev/null || echo br)"
    if command -v setxkbmap >/dev/null 2>&1 && pgrep -f "[X]vnc :1" >/dev/null; then
        DISPLAY=:1 setxkbmap -query 2>/dev/null || true
    fi
}

case "${1:-show}" in
    show|"") show ;;
    *) apply "$1" ;;
esac
EOF
    chmod +x "$H/.dextermux/keyboard.sh"
    ln -sf "$H/.dextermux/keyboard.sh" "$P/bin/keyboard"
}

write_status_command() {
    cat >"$H/.dextermux/status.sh" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
# Gerado por dextermux. Estado dos servicos, memoria e acesso.
set -eu
DIR="$HOME/.dextermux"

count() {
    # shellcheck disable=SC2009
    ps -u "$(id -u)" -o comm= 2>/dev/null \
        | grep -vcE '^(ps|head|tail|wc|tr|grep|sed|awk|sort|sleep)$' || echo 0
}

IP=$(ifconfig 2>/dev/null | sed -n '/^wlan0/,/^$/s/.*inet \([0-9.]*\) .*/\1/p' | head -1)
[ -z "$IP" ] && IP="IP-DO-CELULAR"
TLS=$(cat "$DIR/tls/mode" 2>/dev/null || echo 0)
[ "$TLS" = "1" ] && SCHEME=https || SCHEME=http

echo ""
echo "=== dextermux ==="
echo "desktop:   $(cat "$DIR/desktop" 2>/dev/null || echo cinnamon)"
echo "teclado:   $(cat "$DIR/keyboard" 2>/dev/null || echo br)"
echo "processos: $(count) / 32"
if pgrep -f "[X]vnc :1" >/dev/null; then echo "xvnc:      ativo (vnc://$IP:5901)"; else echo "xvnc:      parado"; fi
if pgrep -f "[w]ebsockify.*6080" >/dev/null; then echo "novnc:     $SCHEME://$IP:6080/vnc.html"; else echo "novnc:     parado"; fi
if pgrep -f "[c]loudflared tunnel" >/dev/null; then
    echo "tunel:     $(cat "$HOME/tunnel-url.txt" 2>/dev/null || echo ativo)"
else
    echo "tunel:     desligado"
fi
echo "https:     $([ "$TLS" = "1" ] && echo ligado || echo desligado)"
if [ -x "$DIR/cast.sh" ]; then
    bash "$DIR/cast.sh" status
fi
echo ""
echo "top 5 por memoria:"
ps -u "$(id -u)" -o rss=,comm= 2>/dev/null | sort -rn | head -5 \
    | awk '{printf "  %5.1f MB  %s\n", $1/1024, $2}'
echo "=== fim ==="
echo ""
EOF
    chmod +x "$H/.dextermux/status.sh"
    ln -sf "$H/.dextermux/status.sh" "$P/bin/status"
}

write_cast_commands() {
    write_cast_command
    write_keyboard_command
    write_status_command
    ok "comandos cast, keyboard e status prontos"
}
