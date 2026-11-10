# Research: Ambiente remoto no Termux

Registro das investigacoes que levaram ao `setup.sh`. Cada item tem sintoma, causa e decisao.

## 1. sshd nao aceita conexao (timeout)

- **Sintoma**: `ssh user@ip -p 8022` fica "piscando" e termina em `Connection timed out`.
- **Causa real encontrada**: o IP do celular mudou apos reboot (`192.168.0.147` -> `192.168.0.170`); o host antigo respondia ping mas nao tinha sshd. Segundo fator: `sshd -d` atende **uma** conexao e sai, derrubando o servidor.
- **Decisao**: nunca usar `sshd -d` para operacao; subir `sshd` normal e com `setsid`.

## 2. Porta 8022 "em uso"

- **Sintoma**: `sshd -d -p 8022` -> `Address already in use` mesmo com `pgrep -af sshd` vazio.
- **Causa**: socket/lock orfao ou processo invisivel (outro perfil/clone do Termux). `pgrep` nao ve processos de outro usuario Android.
- **Decisao**: reboot limpa sockets orfaos; no setup, `sshd` sobe sem `-d` e com `setsid`.

## 3. Diagnostico de sockets bloqueado no Android

- **Sintoma**: `ss -ltn` -> `Cannot bind netlink socket: Permission denied`; `netstat -ltn` -> `not support for af inet (tcp)`; `ip route get` -> netlink denied.
- **Causa**: Android 10+ restringe netlink e `/proc/net/*` para apps.
- **Decisao**: nao depender desses comandos. Para descobrir IP, usar `ifconfig` **sem argumento** (lista `wlan0`; `ifconfig wlan0` falha em `/proc/net/dev`).

## 4. xrdp quebrado no Termux

- **Sintoma**: login no xrdp -> `General login error`; log `Bugcheck; inconsistent auth result. info=0x... status=5`.
- **Causa**: `xrdp 0.10.6.1` (repo termux-x11) tem patch de autenticacao da era 0.9 (`return 1`) aplicado sobre a API nova (que espera `struct auth_info *` + `errorcode`). Resultado inconsistente.
- **Decisao**: descartar xrdp no fluxo principal. Se necessario no futuro, usar proot com Ubuntu ou aguardar correcao do pacote.

## 5. Certificado TLS do xrdp ausente (historico)

- **Sintoma**: `Cannot read private key file .../key.pem` e `MAC checksum error` no Remmina.
- **Causa**: o pacote remove `cert.pem`/`key.pem` e nao regenera.
- **Decisao**: irrelevante no fluxo VNC, mas registrado caso alguem volte ao xrdp: gerar com `openssl req -x509 -newkey rsa:2048 -nodes -keyout key.pem -out cert.pem -days 3650 -subj "/CN=termux"` (pacote `openssl-tool`, nao `openssl`).

## 6. `pip install websockify` trava o celular

- **Sintoma**: `pip3 install websockify` fica minutos em "Installing backend dependencies" e derruba a responsividade.
- **Causa**: puxa `numpy`, que compila do zero (cmake/ninja/compilador) na CPU do celular.
- **Decisao**: `pip3 install --no-deps websockify`. O aviso `no 'numpy' module, HyBi protocol will be slower` e aceitavel.

## 7. Remmina: "No supported auth types"

- **Sintoma**: VNC conecta mas Remmina aborta com `No supported auth types`.
- **Causa**: Xvnc oferecia `VeNCrypt` + `VncAuth`; o cliente nao negociava.
- **Decisao**: subir Xvnc com `-SecurityTypes VncAuth`.

## 8. VNC nao volta apos queda

- **Sintoma**: `vncserver :1` -> `Warning: localhost:1 is taken because of .../.X1-lock`.
- **Causa**: lock orfao apos processo morto.
- **Decisao**: `start-desktop.sh` remove `$TMPDIR/.X1-lock`, `$TMPDIR/.X11-unix/X1` e `~/.vnc/*.pid` quando `Xvnc :1` nao esta rodando.

## 9. Android matando o Termux

- **Sintoma**: sshd/VNC/cloudflared somem; as vezes so o sshd.
- **Causa**: gerenciamento de bateria da Samsung (Apps em suspensao / suspensao profunda / "colocar apps nao usados em suspensao") e pressao de memoria.
- **Decisao**: `termux-wake-lock`, `setsid`, Termux:Boot e banner com auto-start. O setup imprime as pendencias manuais de bateria.

## 10. Nitidez e resolucao

- **Sintoma**: texto borrado; desktop 1280x720 em janela maior com faixas.
- **Causa**: compressao do VNC + resolucao fixa.
- **Decisao**: `-geometry 1600x900`, antialiasing/hinting (`/Xft/Antialias=1`, `/Xft/Hinting=1`, `/Xft/HintStyle=hintfull`, `/Xft/RGBA=rgb`) e orientacao para noVNC `Remote Resize` + Quality 9/Compression 0.

## 11. Resolucao dinamica

- **Fato**: Xvnc 1.16 tem `AcceptSetDesktopSize=on` por padrao.
- **Decisao**: noVNC em "Remote Resize" (`?resize=remote`) e Remmina com "Dynamic resolution update".

## 12. Cloudflare tunnel

- **Fato**: `cloudflared` esta no repo principal do Termux (2026.10.7). Quick tunnel gera `https://<random>.trycloudflare.com`, gratuito, sem limite pratico de banda, URL efemera.
- **Limitacao**: apenas HTTP/WebSocket; VNC puro (TCP 5901) nao passa. Por isso o tunel aponta para o noVNC (6080).
- **Decisao**: quick tunnel no `start-desktop.sh`; named tunnel com dominio fica como evolucao.

## 13. Comportamento do `curl | bash`

- **Fato**: stdin e consumido pelo script; qualquer `read` quebra. `set -o pipefail` + `head -c` gera SIGPIPE e aborta.
- **Decisao**: `set -eu` (sem pipefail) e geracao de senha com `|| true`.
- **Atualizacao (v2.0.0)**: interatividade passou a ler de `/dev/tty` (`exec 3</dev/tty`, `read <&3`). Isso preserva o stdin do script, evita o risco de truncar o codigo ao bufferizar o restante e mantem `curl | bash` funcionando com menus. Sem `/dev/tty`, `INTERACTIVE=0` e os padroes entram em acao.

## 14. Disponibilidade de sessoes graficas no Termux (v2.0.0, superado pela v3.0.0)

- **Fato**: `gnome-shell`, `mutter`, `nautilus` e `gnome-control-center` nao existem nos indices `termux-main`/`termux-x11`. Existem `cinnamon` (com `muffin`, `cjs`, `nemo`), `mate`, `lxqt`, `xfce4`, `openbox`, `i3`, `sway`, `labwc`.
- **Fato**: `plank` nao existe; o fork disponivel e `plank-reloaded`.
- **Fato**: `picom` esta no x11-repo com backend `xrender`, suficiente para sombra e cantos arredondados sem GL.
- **Fato**: `muffin` depende de `opengl`, que puxa `mesa` + `libllvm` (169 MB). O TigerVNC ja depende de `opengl`, entao o custo extra de GL para Cinnamon e menor que a soma isolada.
- **Decisao original (descartada)**: restilizar o XFCE com rofi, plank, picom, Arc e apps GNOME. O visual nao agradou o usuario e o preset foi removido na v1.2.0. Ficou o XFCE padrao (`xfce4` + `xfdesktop`) e Cinnamon virou a sessao padrao, com fallback de 15 s para `xfce`.

## 15. Tamanhos medidos (v2.0.0, superado pela v3.0.0)

Resolucao recursiva de `Depends` sobre os indices `termux-main` e `termux-x11` (campo `Installed-Size`), incluindo a base remota (`tigervnc`, `python`, `cloudflared`, `openssh`, `git`, `curl`, `tar`):

| Preset | Pacotes | Instalado |
|--------|---------|-----------|
| xfce | 191 | ~739 MB |
| cinnamon | 311 | ~1691 MB |
| mate | 269 | ~1345 MB |
| all | 387 | ~2224 MB |
| none | - | ~260 MB |

Perfis: core ~255 MB, web ~270 MB, rust ~1104 MB, go ~725 MB, java ~1365 MB, db ~296 MB, browser ~1278 MB.

## 16. HTTPS autoassinado na LAN (v1.3.0)

- **Fato**: o `websockify` suporta `--cert`, `--key` e `--ssl-only`; o noVNC escolhe `ws://` ou `wss://` pelo protocolo da pagina.
- **Fato**: navegador nao mostra prompt de certificado para `wss`; e preciso abrir a pagina HTTPS e aceitar o certificado antes.
- **Fato**: `openssl-tool` (OpenSSL 3.6.5) ja esta na base e aceita `-addext "subjectAltName=..."`.
- **Fato**: portas abaixo de 1024 exigem root no Android, entao o HTTPS fica na 6080.
- **Fato**: `cloudflared tunnel --url https://localhost:6080 --no-tls-verify` aceita origin com certificado autoassinado.
- **Decisao**: certificado autoassinado por padrao, regenerado quando o IP da `wlan0` muda ou quando faltam 30 dias para expirar. `dextermux-tls` controla o modo sem reinstalar. `VeNCrypt`/X509 no VNC foi descartado porque o noVNC nao negocia X509 e o Remmina ja recusou VeNCrypt.
- **Limitacao**: o aviso do navegador so desaparece instalando o certificado como autoridade no cliente (equivalente a opcao `mkcert`, nao implementada).

## 17. Phantom process killer do Android (v3.0.0)

- **Fato**: Android 12+ mata com `SIGKILL` (signal 9) processos criados por apps fora do ciclo de componentes acima de 32 no total. Nao e `ulimit` do Termux; o limite e do `ActivityManager` e compartilhado entre apps.
- **Sintoma**: "Process completed (signal 9)", sem mensagem no terminal, e o app inteiro morre.
- **Como medir**: `ps -u "$(id -u)" -o pid= | wc -l` no Termux; `dumpsys activity settings | grep max_phantom_processes` via ADB.
- **Como elevar (opcional, sem root, via PC)**:
  ```bash
  adb shell settings put global settings_enable_monitor_phantom_procs false
  adb shell device_config put activity_manager max_phantom_processes 2147483647
  ```
- **Decisao**: mirar 11-13 processos ociosos; `dextermux-status` avisa em 24 e marca critico em 30; nunca falhar instalacao por contagem.

## 18. Stack minimo de XFCE e orcamento de processos (v3.0.0)

- **Fato**: o metapacote `xfce4` puxa `xfce4-notifyd` e `xfce4-power-manager`, que criam daemons extras.
- **Fato**: `at-spi` pode adicionar ate 2 processos; `NO_AT_BRIDGE=1` e `GTK_A11Y=none` evitam.
- **Fato**: `gvfsd` so sobe quando o Thunar precisa (dbus presente).
- **Decisao**: instalar `xfwm4 xfce4-panel xfce4-session xfce4-settings xfconf xfdesktop thunar xfce4-terminal ttf-dejavu` em vez do metapacote. Resultado medido nos indices: 161 pacotes, ~684 MB.
- **Orcamento ocioso**: bash 1, sshd 1, Xvnc 1, websockify 1, xfce4-session 1, xfwm4 1, xfce4-panel 1, xfdesktop 1, xfsettingsd 1, xfconfd 1, dbus-daemon 1 = 11.
- **Uso real**: terminal 12; cada sessao SSH +2; Thunar/gvfs 15-17; tunel +1.
- **Decisao**: `.bashrc` apenas imprime o banner; o desktop sobe por `desktop` ou no boot.

## 19. Sonames do Termux e `pkg upgrade` (v3.2.0)

- **Fato**: o Termux nao mantem compatibilidade de soname entre versoes. O `libvte` 0.84.1 exige `libicuuc.so.79`; com `libicu` antigo, o `xfce4-terminal` falha com `CANNOT LINK EXECUTABLE`.
- **Sintoma**: `Failed to execute default Terminal Emulator. I/O error.` no XFCE, mesmo com o binario presente.
- **Diagnostico**: `DISPLAY=:1 XAUTHORITY=$HOME/.Xauthority xfce4-terminal --version` mostra a biblioteca faltante.
- **Decisao**: o instalador roda `pkg upgrade -y` antes de instalar, com `--force-confold`.
- **Efeito colateral**: o `openssh` e substituido e o `sshd` em execucao morre. Rodar `pkill -x sshd; sshd` restaura. Documentado no README.
- **Nunca** instalar XFCE sobre um Termux com pacotes pendentes: os sonames podem nao casar.

## 20. Processos ocultos do XFCE (v3.4.0)

- **Fato**: a sessao failsafe do XFCE (`$PREFIX/etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-session.xml`) inclui `Thunar --daemon`, que sobe `gvfsd`, `gvfsd-trash`, `gvfsd-metadata`, `dconf-service` e `tumblerd` (6 processos).
- **Fato**: `LaunchGNOME` (padrao true) faz o `xfce4-session` iniciar `ssh-agent` e `gpg-agent`; eles acumulam um por sessao e nunca sao colhidos.
- **Fato**: os icones da area de trabalho fazem o `xfdesktop` consultar o gvfs e acionar o tumbler.
- **Sintoma**: 27-31 processos mesmo sem uso.
- **Solucao**: XML de sessao proprio sem Thunar, `LaunchGNOME=false`, autostart de at-spi/gnome-keyring com `Hidden=true` e icones desligados por padrao (`--icons` religa).
- **Cuidado**: `pkill -x ssh-agent` nao funciona porque o `comm` e o caminho completo; use `pkill -f "[s]sh-agent -s"`.
- **Efeito**: stack ocioso cai para ~12-16 processos.

## 21. Ubuntu proot e ponte grafica (v4.0.0)

- **Fato**: o opencode oficial e um binario glibc (`/lib/ld-linux-aarch64.so.1`); no Termux falha com "required file not found".
- **Fato**: `proot-distro` instala em `$PREFIX/var/lib/proot-distro/containers/<nome>/rootfs`.
- **Fato**: o socket X11 do Xvnc fica em `$TMPDIR/.X11-unix/X1`; `proot-distro login --shared-tmp` o expoe em `/tmp/.X11-unix/X1`.
- **Teste**: `xterm` do Ubuntu abriu no XFCE nativo com `DISPLAY=:1` e `XAUTHORITY=/root/.Xauthority`, apos copiar `~/.Xauthority`.
- **Decisao**: Ubuntu por padrao (`--no-ubuntu` pula), wrappers `dextermux-dev`/`dextermux-ubuntu`/`dextermux-gui`, atalhos no menu e `opencode` no `$PREFIX/bin`.
- **Cuidado**: o instalador do opencode adiciona `~/.opencode/bin` no PATH; como o binario e glibc, o `write_bashrc_block` remove essa linha e o wrapper passa a valer.
- **Limite**: proot nao tem systemd/GPU; apps com sandbox ou aceleracao falham.

## Versoes validadas (2026-11-09)

| Componente | Versao |
|------------|--------|
| XFCE | 4.20 |
| TigerVNC (Xvnc) | 1.16.2 |
| noVNC | 1.5.0 |
| websockify | sem numpy |
| cloudflared | 2026.10.7 |
| OpenSSH | 10.6 |
| Termux | aarch64, Android 15 (Samsung A15) |
