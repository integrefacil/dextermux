# Implementation Plan: Ambiente remoto no Termux (XFCE4)

**Branch**: `001-remote-desktop` | **Date**: 2026-11-10 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification de `specs/001-remote-desktop/spec.md`

## Summary

Um unico `setup.sh`, executavel por `curl -fsSL <url> | bash`, instala e configura um XFCE4 minimo acessivel por VNC local, noVNC com HTTPS autoassinado na LAN e sshd, com tunel Cloudflare opcional, banner de URLs, comandos `desktop`/`url`/`dextermux-tls`/`dextermux-status` e autostart no boot. O instalador nao faz perguntas. O desenho mira 12-16 processos ociosos para conviver com o phantom process killer do Android 12+, que mata o app acima de 32 processos. Um Ubuntu via proot, por padrao, cobre binarios glibc com ponte grafica para o XFCE nativo.

## Technical Context

**Language/Version**: Shell script (bash/sh do Termux), alvo aarch64.
**Primary Dependencies**: Termux `x11-repo`, `tigervnc` (Xvnc 1.16.2), `openssh`, `openssl-tool`, `python` (3.14), `net-tools`, `cloudflared` (2026.10.7), `curl`, `tar`, `dbus`, `xfwm4`, `xfce4-panel`, `xfce4-session`, `xfce4-settings`, `xfconf`, `xfdesktop`, `thunar`, `xfce4-terminal`, `ttf-dejavu`.
**Storage**: Arquivos de configuracao no `$HOME` do Termux; sem banco de dados.
**Testing**: `bash -n`; `shellcheck` no script e nos gerados; `--dry-run`; execucao real idempotente; `curl -k https://<ip>:6080/vnc.html`; `dextermux-status` para contagem de processos.
**Target Platform**: Termux aarch64, Android 13+ (validado em Samsung Galaxy A15, Android 15).
**Project Type**: CLI/installer de ambiente.
**Performance Goals**: desktop utilizavel em 1600x900 via VNC; 11-13 processos ociosos; setup abaixo de 15 minutos.
**Constraints**: sem root, sem systemd, netlink e `/proc/net/*` bloqueados, processos podem ser mortos pelo Android (phantom process killer, teto 32).
**Scale/Scope**: um dispositivo por instalacao; um usuario.

## Constitution Check

- **Idempotente**: passa. `.bashrc` com marcadores, senha preservada, noVNC baixado so se ausente.
- **One-command, sem prompts**: passa na versao 2.0.0 da constitution. Sem `read`, sem `/dev/tty`.
- **Android constraints**: passa. `ifconfig` (sem netlink), `setsid`, Termux:Boot.
- **Working path only**: passa. xrdp fora do fluxo; VNC + noVNC.
- **Simplicity**: passa. Um script + quatro helpers gerados, ~870 linhas.
- **Security explicit**: passa. HTTPS na LAN e aviso de exposicao do tunel.
- **Observability**: passa. Banner + `url` + `status` + logs.
- **Diagnose before installing**: passa. Painel de recursos sem pausa.
- **Process budget**: passa. ~11 ociosos, status avisa em 24 e marca critico em 30.

## Project Structure

### Source Code (repository root)

```text
setup.sh                     # instalador unico (curl | bash)
docs/index.html              # pagina do projeto (GitHub Pages)
docs/setup.sh                # copia servida pela pagina (sincronizada por CI)
.github/workflows/sync-setup.yml
```

Arquivos gerados no dispositivo:

```text
~/.vnc/xstartup              # startxfce4 com dbus, NO_AT_BRIDGE=1 e GTK_A11Y=none
~/.vnc/passwd                # senha VncAuth (8 chars)
~/start-desktop.sh           # sshd + Xvnc + websockify (TLS) + cloudflared (opcional)
~/show-access.sh             # banner de URLs e estado
~/.dextermux/tls.sh          # atalho dextermux-tls
~/.dextermux/status.sh       # atalho dextermux-status
~/.dextermux/tunnel          # 1 liga o cloudflared
~/.dextermux/tls/server.crt  # certificado autoassinado
~/.dextermux/tls/server.key  # chave privada (600)
~/.dextermux/tls/mode        # 1 = HTTPS, 0 = HTTP
~/.termux/boot/start-services.sh
~/noVNC/                     # noVNC 1.5.0
~/tunnel-url.txt             # ultima URL publica
~/dextermux-install.log      # log da instalacao
$PREFIX/bin/desktop          # atalho -> start-desktop.sh
$PREFIX/bin/url              # atalho -> show-access.sh
$PREFIX/bin/dextermux-tls
$PREFIX/bin/dextermux-status
```

**Structure Decision**: projeto single-file (installer). Os helpers sao gerados pelo proprio instalador para manter um unico artefato distribuivel.

## Componentes e responsabilidades

| Componente | Responsabilidade |
|------------|------------------|
| `setup.sh` | diagnosticar, instalar pacotes, gravar configs, criar atalhos, boot, chave SSH, subir servicos |
| `start-desktop.sh` | `termux-wake-lock`, sshd, limpar locks, Xvnc, websockify (TLS), cloudflared opcional, auto-correcao de modo |
| `show-access.sh` | IP por `ifconfig`, esquema TLS, estado dos servicos |
| `dextermux-tls` | gerar, renovar, ligar e desligar o certificado da LAN |
| `dextermux-status` | contagem de processos, top 5, TLS, tunel e Ubuntu |
| `dextermux-dev` | opencode no Ubuntu ou shell |
| `dextermux-ubuntu` | shell no Ubuntu |
| `dextermux-gui` | app grafico do Ubuntu no XFCE |
| `~/.vnc/xstartup` | dbus e `startxfce4` com acessibilidade desligada |
| `~/.bashrc` | apenas o banner (sem autostart) |
| `~/.termux/boot/start-services.sh` | chamar `start-desktop.sh` no boot |

## Decisoes tecnicas

1. **VNC em vez de RDP**: `xrdp 0.10.6.1` do Termux tem patch de autenticacao incompativel (`Bugcheck; inconsistent auth result`).
2. **`VncAuth` explicito**: o TigerVNC 1.16 oferece `VeNCrypt` + `VncAuth`; o Remmina recusa o conjunto. Forcar `-SecurityTypes VncAuth` resolve.
3. **`websockify --no-deps`**: instalar com dependencias puxa `numpy`, que compila do zero no celular.
4. **`setsid`**: garante que os processos sobrevivam ao fim da sessao SSH.
5. **Limpeza de `.X1-lock`**: evita "A VNC server is already running as :1" apos queda.
6. **IP via `ifconfig`**: netlink e `/proc/net/dev` sao bloqueados para apps.
7. **Banner sem autostart**: o Android mata processos; abrir o Termux nao deve criar 11 processos para uma consulta rapida. O desktop sobe por `desktop` ou no boot.
8. **Cloudflare quick tunnel**: gratuito, URL efemera, desligado por padrao por custo de rede e exposicao.
9. **XFCE minimo**: instalar componentes em vez do metapacote `xfce4` evita `xfce4-notifyd` e `xfce4-power-manager`, que criam daemons extras.
10. **`NO_AT_BRIDGE=1` e `GTK_A11Y=none`**: impedem o at-spi (ate 2 processos) de subir.
11. **dbus mantido**: `xfce4-session` nao declara dependencia, mas o Thunar usa gvfs e notificacoes; o custo e 1 processo.
12. **HTTPS autoassinado**: `websockify --cert/--key/--ssl-only`, SANs com o IP da `wlan0`, regeneracao quando o IP muda. `VeNCrypt` no VNC foi descartado porque o noVNC nao negocia X509.
13. **Tunel com origem TLS**: `cloudflared --url https://localhost:6080 --no-tls-verify` para nao quebrar quando o websockify esta em HTTPS.
14. **Porta 6080**: portas abaixo de 1024 exigem root no Android.
15. **Tamanhos medidos**: ~684 MB instalados (161 pacotes) para base + XFCE minimo, pela resolucao real de dependencias nos indices `termux-main` e `termux-x11`.
16. **Phantom process killer**: Android 12+ mata o app acima de 32 processos. O status mede, avisa em 23 e marca critico em 27; navegador e apps pesados tambem contam.
17. **Ubuntu proot como runtime**: binarios glibc (opencode, SDKs) nao rodam no Termux. O instalador cria o rootfs com `proot-distro` e instala `curl`, `git` e `ca-certificates`; `--no-ubuntu` pula.
18. **Ponte grafica sem segundo desktop**: `proot-distro --shared-tmp` expoe `$TMPDIR/.X11-unix/X1` em `/tmp`; o cookie `~/.Xauthority` e copiado para `/root/.Xauthority` a cada chamada. Testado com `xterm` no XFCE nativo.
19. **Wrappers**: `dextermux-dev` detecta o opencode e cai para shell; `opencode` chama o `dextermux-dev`; `dextermux-gui` executa qualquer comando do Ubuntu no display `:1`. Atalhos em `~/.local/share/applications`.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| Banner sem autostart | Android mata processos e abrir o app nao deve custar 11 processos | Autostart gera desperdicio em uso majoritariamente por SSH |
| Script unico com ~870 linhas | Preserva `curl \| bash` de um comando | Baixar `lib/*.sh` adiciona pontos de falha de rede |
| dbus mesmo com custo de 1 processo | Thunar e apps GTK dependem de gvfs/notificacoes | Sem dbus o gerenciador de arquivos perde funcoes |
