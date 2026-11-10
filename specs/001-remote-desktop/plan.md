# Implementation Plan: Ambiente remoto no Termux

**Branch**: `001-remote-desktop` | **Date**: 2026-11-09 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification de `specs/001-remote-desktop/spec.md`

## Summary

Um unico `setup.sh`, executavel por `curl -fsSL <url> | bash`, instala e configura um desktop Linux acessivel por VNC local, noVNC no navegador e tunel HTTPS do Cloudflare, com banner de URLs ao abrir o Termux, comandos `desktop`/`url`/`dextermux-session` e autostart no boot. A versao 2.0.0 adiciona diagnostico de recursos antes de qualquer download, menus numerados de escolha (sessao grafica e perfis de desenvolvimento), Cinnamon como sessao padrao, XFCE padrao sem restilizacao, suporte a MATE com troca e teste em paralelo e HTTPS autoassinado na LAN para o noVNC. O fluxo evita `xrdp` (pacote quebrado no Termux) e reduz o atrito de reinstalacao a um comando.

## Technical Context

**Language/Version**: Shell script (bash/sh do Termux), alvo aarch64.
**Primary Dependencies**: Termux `x11-repo`, `cinnamon`, `nemo`, `xfce4` (4.20), `xfdesktop`, `tigervnc` (Xvnc 1.16.2), `openssh`, `openssl-tool`, `python` (3.14), `net-tools`, `cloudflared` (2026.10.7), `git`, `curl`, `tar`; opcionais `mate`.
**Storage**: Arquivos de configuracao no `$HOME` do Termux; sem banco de dados.
**Testing**: `bash -n` para sintaxe; `--dry-run` para conferir o plano; `sh -n`/`bash -n` nos scripts gerados; execucao real idempotente no dispositivo; verificacao de portas (8022/5901/6080/6081) e HTTP 200 na URL publica.
**Target Platform**: Termux aarch64, Android 13+ (validado em Samsung Galaxy A15, Android 15).
**Project Type**: CLI/installer de ambiente.
**Performance Goals**: desktop utilizavel em 1600x900 via VNC em LAN; custo de setup < 15 min.
**Constraints**: sem root, sem systemd, netlink e `/proc/net/*` bloqueados, processos podem ser mortos pelo Android.
**Scale/Scope**: um dispositivo por instalacao; um usuario.

## Constitution Check

- **Idempotente**: passa. `.bashrc` com marcadores, senha preservada, noVNC baixado so se ausente, configs sobrescritas de forma deterministica.
- **One-command, interativo quando possivel**: passa na versao 1.1.0 da constitution. `curl | bash` sem TTY usa os padroes; com TTY le de `/dev/tty`.
- **Android constraints**: passa. `ifconfig` (sem netlink), `setsid`, Termux:Boot.
- **Working path only**: passa. xrdp removido do fluxo principal.
- **Simplicity**: passa. Um script + quatro helpers gerados.
- **Security explicit**: passa. Tela de confirmacao avisa do tunel; resumo avisa da senha de 8 caracteres.
- **Observability**: passa. Banner + `url` + logs.
- **Diagnose before installing**: passa. Painel de recursos e veredito antes de qualquer `pkg install`.

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
~/.vnc/xstartup              # escolhe a sessao e sobe com fallback para xfce
~/.vnc/passwd                # senha VncAuth (8 chars)
~/start-desktop.sh           # sobe sshd + Xvnc + websockify + cloudflared (por display)
~/show-access.sh             # banner de URLs e sessao atual
~/.dextermux/session         # sessao padrao (cinnamon|xfce|mate|none)
~/.dextermux/session.<disp>  # override por display (usado no teste :2)
~/.dextermux/session-manager.sh  # atalho dextermux-session
~/.dextermux/tls.sh          # atalho dextermux-tls
~/.dextermux/tls/server.crt  # certificado autoassinado (IP da LAN nas SANs)
~/.dextermux/tls/server.key  # chave privada (600)
~/.dextermux/tls/mode        # 1 = HTTPS, 0 = HTTP
~/.termux/boot/start-services.sh
~/noVNC/                     # noVNC 1.5.0
~/tunnel-url.txt             # ultima URL publica
~/dextermux-install.log      # log da instalacao
$PREFIX/bin/desktop          # atalho -> start-desktop.sh
$PREFIX/bin/url              # atalho -> show-access.sh
$PREFIX/bin/dextermux-session
$PREFIX/bin/dextermux-tls
```

**Structure Decision**: projeto single-file (installer). Os helpers sao gerados pelo propio instalador para manter um unico artefato distribuivel.

## Componentes e responsabilidades

| Componente | Responsabilidade |
|------------|------------------|
| `setup.sh` | diagnosticar recursos, exibir menus, instalar pacotes, gravar configs, criar atalhos, boot, chave SSH, subir servicos |
| `start-desktop.sh` | `termux-wake-lock`, sshd, limpar locks, Xvnc, websockify, cloudflared; aceita display e sessao |
| `show-access.sh` | calcular IP por `ifconfig`, checar processos e imprimir URLs, sessao e display de teste |
| `dextermux-session` | listar, trocar, testar em `:2` e remover sessoes |
| `dextermux-tls` | gerar, renovar, ligar e desligar o certificado da LAN |
| `~/.vnc/xstartup` | dbus, sessao escolhida e fallback de 15 s para `xfce` |
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
9. **Interatividade por `/dev/tty`**: em `curl | bash` o stdin e o proprio script; ler de `/dev/tty` evita bufferizar o codigo e quebrar a execucao. Sem TTY, o instalador segue com os padroes.
10. **Cinnamon como padrao**: a sessao do Mint entrega um desktop completo sem pacotes de tema extras e foi validada no aparelho. O preset `xfce` instala apenas `xfce4` e `xfdesktop`, porque a restilizacao anterior (rofi, plank, picom, Arc, apps GNOME) foi descartada por nao agradar o visual.
11. **Fallback em `xfce`**: o XFCE padrao e o menor conjunto estavel e serve de rede de seguranca para Cinnamon e MATE.
12. **Sessao por display**: `~/.dextermux/session.<display>` permite testar Cinnamon ou MATE no `:2` (VNC 5902, noVNC 6081) sem derrubar o `:1` nem o tunel.
13. **Fallback de 15 s**: sessao experimental roda em background por 15 s antes de assumir o display; se morrer, `exec startxfce4` assume e o erro vai para `$TMPDIR/session.log`.
14. **Tamanhos medidos, nao estimados**: os numeros dos menus vieram da resolucao real de dependencias nos indices `termux-main` e `termux-x11` (Installed-Size), incluindo a base remota.
15. **HTTPS autoassinado na LAN**: o `websockify` tem TLS nativo (`--cert`, `--key`, `--ssl-only`) e o noVNC deriva `wss://` do protocolo da pagina. O certificado e gerado com `openssl-tool` (ja instalado), com o IP da `wlan0` nas SANs, e regenerado quando o IP muda. `VeNCrypt` no VNC foi descartado porque o noVNC nao negocia X509 e o Remmina ja recusou VeNCrypt. O tunel usa `https://localhost:6080 --no-tls-verify` para nao quebrar o origin. Porta 6080 mantida porque portas abaixo de 1024 exigem root.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| Banner auto-inicia servicos | Android mata background; sem isso o usuario ve tudo parado | Instruir manualmente gera fricção e o usuario pediu zero memoria |
| Quick tunnel em vez de named | Funciona sem conta/dominio | Named tunnel exige DNS proprio |
| Tres sessoes no mesmo script | O usuario precisa comparar visual antes de decidir | Instalar uma por vez exigiria reinstalar 1,5 GB a cada teste |
| Script unico com ~1.400 linhas | Preserva `curl \| bash` de um comando | Baixar `lib/*.sh` adiciona pontos de falha de rede e versionamento |
