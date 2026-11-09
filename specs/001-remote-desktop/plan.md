# Implementation Plan: Ambiente remoto no Termux

**Branch**: `001-remote-desktop` | **Date**: 2026-11-09 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification de `specs/001-remote-desktop/spec.md`

## Summary

Um unico `setup.sh`, executa vel por `curl -fsSL <url> | bash`, instala e configura um desktop XFCE acessivel por VNC local, noVNC no navegador e tunel HTTPS do Cloudflare, com banner de URLs ao abrir o Termux, comandos `desktop`/`url` e autostart no boot. O fluxo evita `xrdp` (pacote quebrado no Termux) e reduz o atrito de reinstalacao a um comando.

## Technical Context

**Language/Version**: Shell script (bash/sh do Termux), alvo aarch64.
**Primary Dependencies**: Termux `x11-repo`, `xfce4` (4.20), `tigervnc` (Xvnc 1.16.2), `openssh`, `openssl-tool`, `python` (3.14), `net-tools`, `cloudflared` (2026.10.7), `git`, `curl`, `tar`.
**Storage**: Arquivos de configuracao no `$HOME` do Termux; sem banco de dados.
**Testing**: `bash -n` para sintaxe; execucao real idempotente no dispositivo; verificacao de portas (8022/5901/6080) e HTTP 200 na URL publica.
**Target Platform**: Termux aarch64, Android 13+ (validado em Samsung Galaxy A15, Android 15).
**Project Type**: CLI/installer de ambiente.
**Performance Goals**: desktop utilizavel em 1600x900 via VNC em LAN; custo de setup < 15 min.
**Constraints**: sem root, sem systemd, netlink e `/proc/net/*` bloqueados, processos podem ser mortos pelo Android.
**Scale/Scope**: um dispositivo por instalacao; um usuario.

## Constitution Check

- **Idempotente**: passa. `.bashrc` com marcadores, senha preservada, noVNC baixado so se ausente.
- **One-command**: passa. Sem `read`; configuracao por env vars.
- **Android constraints**: passa. `ifconfig` (sem netlink), `setsid`, Termux:Boot.
- **Working path only**: passa. xrdp removido do fluxo principal.
- **Simplicity**: passa. Um script + dois helpers.
- **Security explicit**: passa. Resumo avisa da exposicao e da senha de 8 caracteres.
- **Observability**: passa. Banner + `url` + logs.

## Project Structure

### Documentation

```text
specs/
├── constitution.md
└── 001-remote-desktop/
    ├── spec.md
    ├── plan.md
    ├── research.md
    ├── tasks.md
    ├── quickstart.md
    └── contracts/
        └── cli-contract.md
```

### Source Code (repository root)

```text
setup.sh                     # instalador unico (curl | bash)
```

Arquivos gerados no dispositivo:

```text
~/.vnc/xstartup              # sessao XFCE do VNC
~/.vnc/passwd                # senha VncAuth (8 chars)
~/start-desktop.sh           # sobe sshd + Xvnc + websockify + cloudflared
~/show-access.sh             # banner de URLs
~/.termux/boot/start-services.sh
~/noVNC/                     # noVNC 1.5.0
~/tunnel-url.txt             # ultima URL publica
$PREFIX/bin/desktop          # atalho -> start-desktop.sh
$PREFIX/bin/url              # atalho -> show-access.sh
```

**Structure Decision**: projeto single-file (installer). Os helpers sao gerados pelo propio instalador para manter um unico artefato distribuivel.

## Componentes e responsabilidades

| Componente | Responsabilidade |
|------------|------------------|
| `setup.sh` | instalar pacotes, gravar configs, criar atalhos, boot, chave SSH, subir servicos |
| `start-desktop.sh` | `termux-wake-lock`, sshd, limpar locks, Xvnc, fontes, websockify, cloudflared |
| `show-access.sh` | calcular IP por `ifconfig`, checar processos e imprimir URLs |
| `~/.bashrc` | autostart em background + banner (bloco com marcadores) |
| `~/.termux/boot/start-services.sh` | chamar `start-desktop.sh` no boot |

## Decisoes tecnicas

1. **VNC em vez de RDP**: `xrdp 0.10.6.1` do Termux tem patch de autenticacao incompativel (`Bugcheck; inconsistent auth result`). VNC evita a camada de login do sistema.
2. **`VncAuth` explicito**: o TigerVNC 1.16 oferece `VeNCrypt` + `VncAuth`; o Remmina recusa o conjunto. Forcar `-SecurityTypes VncAuth` resolve.
3. **`websockify --no-deps`**: instalar com dependencias puxa `numpy`, que compila do zero no celular e trava o setup por minutos.
4. **`setsid`**: garante que os processos sobrevivam ao fim da sessao SSH.
5. **Limpeza de `.X1-lock`**: evita "A VNC server is already running as :1" apos queda.
6. **IP via `ifconfig`**: netlink e `/proc/net/dev` sao bloqueados para apps; `ifconfig` sem argumento ainda lista `wlan0`.
7. **Banner com auto-start**: como o Android mata processos, abrir o Termux religa o ambiente e informa as URLs.
8. **Cloudflare quick tunnel**: gratuito e sem limite pratico de banda; URL efemera. Named tunnel exige dominio e fica como evolucao.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| Banner auto-inicia servicos | Android mata background; sem isso o usuario ve tudo parado | Instruir manualmente gera fricção e o usuario pediu zero memoria |
| Quick tunnel em vez de named | Funciona sem conta/dominio | Named tunnel exige DNS proprio |
