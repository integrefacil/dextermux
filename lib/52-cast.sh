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
<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no, viewport-fit=cover">
<title>dextermux controle</title>
<style>
  :root { color-scheme: dark; }
  html, body { margin: 0; height: 100%; background: #0f1114; color: #e8e8e8;
    font-family: system-ui, sans-serif; overflow: hidden; touch-action: none;
    -webkit-user-select: none; user-select: none; }
  #top { position: fixed; top: 0; left: 0; right: 0; height: 32px; z-index: 6;
    display: flex; align-items: center; gap: 8px; padding: 0 10px;
    font-size: 12px; color: #9aa0a6; background: #121417; }
  #top .dot { width: 9px; height: 9px; border-radius: 50%; background: #b3261e; }
  #top .dot.on { background: #34a853; }
  #pos { margin-left: auto; font-variant-numeric: tabular-nums; color: #6b7280; }
  #preview { position: fixed; right: 8px; top: 40px; width: 168px; height: 95px;
    border: 1px solid #2c3036; border-radius: 8px; overflow: hidden; z-index: 5; }
  #preview #screen { width: 100%; height: 100%; }
  #pad { position: fixed; left: 0; right: 0; top: 32px; bottom: 68px;
    touch-action: none; -webkit-tap-highlight-color: transparent;
    background: radial-gradient(circle at 50% 40%, #1b1e23, #0b0c0f); }
  body.fn #pad { bottom: 122px; }
  #hint { position: fixed; left: 10px; bottom: 76px; font-size: 11px; color: #5f666f; z-index: 5; }
  body.fn #hint { display: none; }
  #keys { position: fixed; left: 0; right: 0; bottom: 0; z-index: 7;
    background: #15181c; border-top: 1px solid #23272d;
    padding: 6px 8px calc(6px + env(safe-area-inset-bottom)); }
  .row { display: flex; gap: 6px; overflow-x: auto; padding-bottom: 4px;
    touch-action: pan-x; scrollbar-width: none; }
  .row::-webkit-scrollbar { display: none; }
  #row2 { display: none; }
  body.fn #row2 { display: flex; }
  button.k { flex: 0 0 auto; min-width: 46px; height: 44px; padding: 0 12px;
    border-radius: 10px; border: 1px solid #2b3037; background: #1d2126;
    color: #e6e6e6; font-size: 14px; font-family: inherit; }
  button.k:active { background: #2d5c8a; }
  button.k.on { background: #26405c; border-color: #3f6f9e; color: #cfe4ff; }
  button.k.wide { min-width: 76px; }
  #kbd { position: fixed; left: 0; bottom: 0; width: 1px; height: 1px;
    opacity: 0.01; border: 0; padding: 0; resize: none; z-index: 1; }
</style>
</head>
<body>
<div id="top"><span class="dot" id="dot"></span><span id="state">conectando</span><span id="pos"></span></div>
<div id="preview"><div id="screen"></div></div>
<div id="pad"></div>
<div id="hint">arraste para mover, toque para clicar, segure para clique direito, segure e arraste para mover janela</div>
<textarea id="kbd" autocapitalize="off" autocomplete="off" autocorrect="off" spellcheck="false" aria-hidden="true"></textarea>
<div id="keys">
  <div class="row" id="row1"></div>
  <div class="row" id="row2"></div>
</div>
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
const row1 = document.getElementById('row1');
const row2 = document.getElementById('row2');
const kbd = document.getElementById('kbd');

let rfb = null;
let px = Math.round(fbW / 2);
let py = Math.round(fbH / 2);
let dragging = false;
let holdReady = false;
let holdTimer = null;
let startPt = null;
let lastPt = null;
let moved = false;
let scrollLast = null;
let scrollActive = false;
let lastTouchAt = 0;

const KEYS = {
  Escape: 0xff1b, Tab: 0xff09, Enter: 0xff0d, BackSpace: 0xff08, Delete: 0xffff,
  ArrowUp: 0xff52, ArrowDown: 0xff54, ArrowLeft: 0xff51, ArrowRight: 0xff53,
  Home: 0xff50, End: 0xff57, PageUp: 0xff55, PageDown: 0xff56,
  ShiftLeft: 0xffe1, ControlLeft: 0xffe3, AltLeft: 0xffe9, MetaLeft: 0xffeb,
};
for (let i = 1; i <= 12; i++) KEYS['F' + i] = 0xffbe + (i - 1);

const sticky = new Set();
const stickyButtons = new Map();

function setState(text, on) {
  state.textContent = text;
  dot.classList.toggle('on', !!on);
}

function showPos() {
  document.getElementById('pos').textContent = Math.round(px) + ',' + Math.round(py);
}

function codeFor(name) {
  if (name.length === 1 && /[a-z]/i.test(name)) return 'Key' + name.toUpperCase();
  if (name.length === 1 && /[0-9]/.test(name)) return 'Digit' + name;
  return name;
}

function keysymFor(ch) {
  const c = ch.codePointAt(0);
  return c < 0x100 ? c : 0x01000000 | c;
}

function keyDown(name) {
  if (!rfb) return;
  rfb.sendKey(KEYS[name] || keysymFor(name), codeFor(name), true);
}

function keyUp(name) {
  if (!rfb) return;
  rfb.sendKey(KEYS[name] || keysymFor(name), codeFor(name), false);
}

// modificador pegajoso: vale para a proxima tecla e volta ao estado neutro
function releaseSticky() {
  for (const name of sticky) {
    if (rfb) rfb.sendKey(KEYS[name], name, false);
    const btn = stickyButtons.get(name);
    if (btn) btn.classList.remove('on');
  }
  sticky.clear();
}

function keyTap(name) {
  if (!rfb) return;
  for (const mod of sticky) rfb.sendKey(KEYS[mod], mod, true);
  keyDown(name);
  setTimeout(() => {
    keyUp(name);
    releaseSticky();
  }, 45);
}

function toggleSticky(name) {
  const btn = stickyButtons.get(name);
  if (sticky.has(name)) {
    sticky.delete(name);
    if (btn) btn.classList.remove('on');
  } else {
    sticky.add(name);
    if (btn) btn.classList.add('on');
  }
  if (navigator.vibrate) navigator.vibrate(12);
}

function screenCanvas() { return screen.querySelector('canvas'); }

// noVNC 1.5 nao expoe sendPointer e o container do canvas precisa ter tamanho:
// sem isso _scale fica 0 e absX() devolve 0. _sendMouse recebe CSS do canvas e
// converte para o framebuffer, sem passar pelo capture proxy de mousedown.
function pointer(mask) {
  if (!rfb) return;
  const c = screenCanvas();
  if (!c) return;
  const r = c.getBoundingClientRect();
  if (!r.width || !r.height) return;
  const cx = (px / fbW) * r.width;
  const cy = (py / fbH) * r.height;
  if (typeof rfb._sendMouse === 'function') {
    rfb._sendMouse(cx, cy, mask);
    showPos();
    return;
  }
  const box = {
    clientX: r.left + cx, clientY: r.top + cy,
    bubbles: true, cancelable: true, view: window,
  };
  c.dispatchEvent(new MouseEvent(mask === 0 ? 'mousemove' : 'mousedown', box));
  if (mask !== 0) {
    setTimeout(() => c.dispatchEvent(new MouseEvent('mouseup', box)), 60);
  }
  showPos();
}

function maskFromButtons(buttons) {
  let m = 0;
  if (buttons & 1) m |= 1;
  if (buttons & 2) m |= 4;
  if (buttons & 4) m |= 2;
  return m;
}

function move(dx, dy) {
  px = Math.min(fbW - 1, Math.max(0, px + dx));
  py = Math.min(fbH - 1, Math.max(0, py + dy));
  pointer(dragging ? 1 : 0);
}

function click(button) {
  const mask = button === 'right' ? 4 : 1;
  pointer(mask);
  setTimeout(() => pointer(dragging ? 1 : 0), 60);
}

function wheel(dy) {
  if (!dy) return;
  pointer(dy < 0 ? 8 : 16);
  setTimeout(() => pointer(dragging ? 1 : 0), 40);
}

function isTouchRecent() { return Date.now() - lastTouchAt < 700; }

function buzz(ms) { if (navigator.vibrate) navigator.vibrate(ms); }

pad.addEventListener('touchstart', (ev) => {
  lastTouchAt = Date.now();
  if (ev.touches.length === 2) {
    scrollActive = true;
    scrollLast = ev.touches[0].clientY;
    lastPt = null;
    return;
  }
  const t = ev.touches[0];
  startPt = { x: t.clientX, y: t.clientY };
  lastPt = { x: t.clientX, y: t.clientY };
  moved = false;
  dragging = false;
  holdReady = false;
  clearTimeout(holdTimer);
  holdTimer = setTimeout(() => {
    holdReady = true;
    buzz(15);
  }, 500);
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
    if (!holdReady) { clearTimeout(holdTimer); holdTimer = null; }
    else if (!dragging) {
      dragging = true;
      pointer(1);
    }
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
  if (scrollActive) {
    scrollActive = false;
    scrollLast = null;
    startPt = null;
    lastPt = null;
    return;
  }
  if (dragging) {
    pointer(0);
    dragging = false;
  } else if (holdReady) {
    click('right');
  } else if (!moved) {
    click('left');
  }
  holdReady = false;
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
  pointer(maskFromButtons(ev.buttons));
});

pad.addEventListener('mousedown', (ev) => {
  if (isTouchRecent()) return;
  pointer(maskFromButtons(ev.buttons || (ev.button === 2 ? 2 : 1)));
});

pad.addEventListener('mouseup', (ev) => {
  if (isTouchRecent()) return;
  pointer(maskFromButtons(ev.buttons));
});

pad.addEventListener('contextmenu', (ev) => { ev.preventDefault(); });

// teclado virtual: o textarea invisivel levanta o teclado do Android e cada
// caractere confirmado vira keysym no X
function openKeyboard() {
  kbd.value = '';
  kbd.focus();
  buzz(10);
}

kbd.addEventListener('beforeinput', (ev) => {
  if (ev.inputType === 'deleteContentBackward') {
    ev.preventDefault();
    keyTap('BackSpace');
  } else if (ev.inputType === 'insertLineBreak' || ev.inputType === 'insertParagraph') {
    ev.preventDefault();
    keyTap('Enter');
  }
});

kbd.addEventListener('input', () => {
  const text = kbd.value;
  kbd.value = '';
  if (!text || !rfb) return;
  for (const ch of text) {
    const keysym = keysymFor(ch);
    rfb.sendKey(keysym, 'Unidentified', true);
    setTimeout(() => { if (rfb) rfb.sendKey(keysym, 'Unidentified', false); }, 25);
  }
});

kbd.addEventListener('keydown', (ev) => {
  const map = { Enter: 'Enter', Backspace: 'BackSpace', Tab: 'Tab', Escape: 'Escape' };
  if (map[ev.key]) {
    ev.preventDefault();
    keyTap(map[ev.key]);
  }
});

async function pasteClipboard() {
  if (!rfb) return;
  let text = '';
  try {
    text = await navigator.clipboard.readText();
  } catch (err) {
    text = prompt('texto para colar') || '';
  }
  if (text) rfb.clipboardPasteFrom(text);
}

function addButton(row, label, onPress, opts) {
  const btn = document.createElement('button');
  btn.type = 'button';
  btn.className = 'k' + (opts && opts.wide ? ' wide' : '');
  btn.textContent = label;
  btn.addEventListener('click', (ev) => {
    ev.preventDefault();
    onPress(btn);
  });
  row.appendChild(btn);
  return btn;
}

addButton(row1, 'Teclado', () => {
  if (document.activeElement === kbd) kbd.blur();
  else openKeyboard();
}, { wide: true });

for (const [label, name] of [['Ctrl', 'ControlLeft'], ['Alt', 'AltLeft'],
                             ['Shift', 'ShiftLeft'], ['Super', 'MetaLeft']]) {
  const btn = addButton(row1, label, () => toggleSticky(name));
  stickyButtons.set(name, btn);
}

addButton(row1, 'Esc', () => keyTap('Escape'));
addButton(row1, 'Tab', () => keyTap('Tab'));
addButton(row1, 'Enter', () => keyTap('Enter'), { wide: true });
addButton(row1, 'Apagar', () => keyTap('BackSpace'));
addButton(row1, 'Del', () => keyTap('Delete'));
addButton(row1, 'Colar', pasteClipboard, { wide: true });

for (const [label, name] of [['\u25C0', 'ArrowLeft'], ['\u25B2', 'ArrowUp'],
                             ['\u25BC', 'ArrowDown'], ['\u25B6', 'ArrowRight']]) {
  addButton(row1, label, () => keyTap(name));
}

addButton(row1, 'Clique', () => click('left'), { wide: true });
addButton(row1, 'Dir.click', () => click('right'), { wide: true });
addButton(row1, 'Fn', () => document.body.classList.toggle('fn'));

for (let i = 1; i <= 12; i++) addButton(row2, 'F' + i, () => keyTap('F' + i));
for (const [label, name] of [['Home', 'Home'], ['End', 'End'],
                             ['PgUp', 'PageUp'], ['PgDn', 'PageDown']]) {
  addButton(row2, label, () => keyTap(name));
}

window.addEventListener('keydown', (ev) => {
  if (ev.target === kbd) return;
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
  if (ev.target === kbd) return;
  if (ev.key === 'Shift') return keyUp('ShiftLeft');
  if (ev.key === 'Control') return keyUp('ControlLeft');
  if (ev.key === 'Alt') return keyUp('AltLeft');
  if (ev.key === 'Meta') return keyUp('MetaLeft');
  if (KEYS[ev.key] || ev.key.length === 1) keyUp(ev.key);
  else if (KEYS[ev.code]) keyUp(ev.code);
});

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
