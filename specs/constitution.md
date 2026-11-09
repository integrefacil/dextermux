# dextermux Constitution

## Core Principles

### I. Idempotent by Default
O `setup.sh` DEVE poder rodar varias vezes sem duplicar configuracao, sem apagar dados do usuario e sem quebrar um ambiente ja funcional. Toda escrita em arquivo de configuracao DEVE ser idempotente (marcadores, `grep` de guarda ou sobrescrita deterministica).

### II. One-Command Bootstrap, Interactive When Possible
O provisionamento DEVE continuar funcionando como `curl -fsSL <url> | bash`, sem quebrar automacao. Quando existir terminal interativo, o instalador DEVE abrir `/dev/tty` para ler respostas, sem consumir o stdin do proprio script, e oferecer menus numerados (sessao grafica, ferramentas de desenvolvimento, acesso remoto). Sem terminal, ou com `--yes`, DEVE usar os padroes sem qualquer prompt. Toda variacao tambem DEVE estar disponivel por flag (`--desktop`, `--dev`, `--geometry`, `--password`, `--ssh-pubkey`, `--tunnel`) e por variavel de ambiente (`VNC_PASS`, `GEOMETRY`, `NOVNC_VER`, `SSH_PUBKEY`, `TUNNEL`). Nenhum `read` pode bloquear a execucao quando nao houver TTY.

### III. Android Constraints First
O ambiente roda em Termux sem root. Solucoes DEVEM respeitar as restricoes do Android:
- netlink e `/proc/net/*` bloqueados para apps (nao usar `ss`, `ip route`, `ifconfig wlan0`);
- sem systemd (usar `setsid`, scripts no boot do Termux:Boot);
- processos em background podem ser mortos (usar `termux-wake-lock` e orientar isencao de bateria).

### IV. Working Path Only
Nunca manter um caminho conhecido como quebrado no fluxo principal. O `xrdp 0.10.6.1` do Termux falha na autenticacao (`Bugcheck; inconsistent auth result`) e por isso NAO faz parte do setup. O caminho oficial e VNC (`Xvnc`) + noVNC.

### V. Simplicity Over Machinery
Um unico script + arquivos pequenos de operacao (`start-desktop.sh`, `show-access.sh`). Sem supervisor, sem container, sem proot. Complexidade so entra com justificativa registrada neste documento.

### VI. Security Is Explicit
Exposicao publica via tunel DEVE ser avisada ao usuario, com recomendacao de senha forte (limitada a 8 caracteres pelo VNC Auth) e caminho para named tunnel + Cloudflare Access quando houver dominio.

### VII. Observability for Humans
Ao abrir o Termux, o usuario DEVE ver as URLs de acesso e o estado dos servicos. Comando `url` reproduz o banner; logs ficam em `$TMPDIR/cf.log`, `$TMPDIR/ws.log` e `~/.vnc/localhost:1.log`.

### VIII. Diagnose Before Installing
O instalador DEVE medir o aparelho antes de qualquer download (modelo, versao do Android, nucleos, memoria total e livre, espaco livre em `$HOME`, alcance de `packages.termux.dev` e `github.com`, instalacao existente) e emitir um veredito explicito (suficiente, com ressalvas ou insuficiente). Toda opcao de menu DEVE exibir o custo estimado em disco e o selo `validado` ou `experimental`.

## Additional Constraints

- Plataforma alvo: Termux aarch64, Android 13+ (validado em Samsung Galaxy A15, Android 15).
- Pacotes base: `x11-repo`, `tigervnc`, `openssh`, `openssl-tool`, `python`, `net-tools`, `cloudflared`, `git`, `curl`, `tar`.
- Sessoes: `cinnamon` (padrao), `xfce` (visual padrao, apenas `xfce4` e `xfdesktop`), `mate`. `cinnamon` e `xfce` sao validadas no aparelho.
- Portas: 8022 (sshd), 5901 (VNC), 6080 (noVNC/websocket), 5902/6081 (sessao de teste no display `:2`).
- Senha do VNC Auth: ate 8 caracteres.
- URL do quick tunnel do Cloudflare e efemera e muda a cada reinicio.

## Development Workflow

- Toda mudanca no `setup.sh` DEVE ser validada com `bash -n` e, quando possivel, com uma execucao real no Termux (idempotente).
- Nenhuma instalacao de dependencia nova sem atualizar `plan.md` e `research.md`.
- Falhas conhecidas DEVEM virar item em `research.md` com causa e workaround.

## Governance

Esta constitution prevalece sobre preferencias pontuais. Emendas exigem:
1. justificativa no `plan.md`;
2. atualizacao de `spec.md`/`tasks.md` quando mudar comportamento observavel;
3. validacao no dispositivo antes de considerar concluido.

**Version**: 1.2.0 | **Ratified**: 2026-11-09 | **Last Amended**: 2026-11-09

## Emendas

- **1.1.0 (2026-11-09)**: Principio II passa a permitir instalador interativo quando ha TTY, mantendo o caminho automatico para pipe e `--yes`. Novo Principio VIII (Diagnose Before Installing). Sessoes graficas e perfis de desenvolvimento entram como escopo configuravel.
- **1.2.0 (2026-11-09)**: preset restilizado (rofi, plank, picom, Arc, apps GNOME) removido a pedido do usuario; `xfce` passa a ser o XFCE padrao e `cinnamon` vira a sessao padrao.
