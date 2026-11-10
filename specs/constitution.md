# dextermux Constitution

## Core Principles

### I. Idempotent by Default
O `setup.sh` DEVE poder rodar varias vezes sem duplicar configuracao, sem apagar dados do usuario e sem quebrar um ambiente ja funcional. Toda escrita em arquivo de configuracao DEVE ser idempotente (marcadores, `grep` de guarda ou sobrescrita deterministica).

### II. One-Command Bootstrap, No Prompts
O provisionamento DEVE funcionar como `curl -fsSL <url> | bash`, sem menus, sem `read` e sem `/dev/tty`. Toda variacao DEVE vir por flag (`--geometry`, `--password`, `--ssh-pubkey`, `--tunnel`, `--tls`, `--repair`, `--dry-run`) ou variavel de ambiente (`VNC_PASS`, `GEOMETRY`, `NOVNC_VER`, `SSH_PUBKEY`, `TUNNEL`, `TLS`). O instalador DEVE terminar sem intervencao do usuario.

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
O instalador DEVE medir o aparelho antes de qualquer download (modelo, versao do Android, nucleos, memoria total e livre, espaco livre em `$HOME`, alcance de `packages.termux.dev` e `github.com`, instalacao existente, contagem de processos) e imprimir o resultado sem pausar.

### IX. Process Budget
O ambiente DEVE permanecer abaixo de 32 processos, teto imposto pelo phantom process killer do Android 12+. O desenho DEVE mirar 15-20 processos ociosos com dbus. O comando `dextermux-status` DEVE medir, avisar a partir de 23 e marcar critico a partir de 27, sem bloquear instalacao ou reparo.

## Additional Constraints

- Plataforma alvo: Termux aarch64, Android 13+ (validado em Samsung Galaxy A15, Android 15).
- Pacotes base: `x11-repo`, `tigervnc`, `openssh`, `openssl-tool`, `python`, `net-tools`, `cloudflared`, `curl`, `tar`, `dbus`.
- Sessao unica: XFCE4 minimo (`xfwm4`, `xfce4-panel`, `xfce4-session`, `xfce4-settings`, `xfconf`, `xfdesktop`, `thunar`, `xfce4-terminal`, `ttf-dejavu`).
- Portas: 8022 (sshd), 5901 (VNC), 6080 (noVNC/websocket em HTTPS autoassinado).
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

**Version**: 2.0.0 | **Ratified**: 2026-11-09 | **Last Amended**: 2026-11-10

## Emendas

- **1.1.0 (2026-11-09)**: Principio II passa a permitir instalador interativo quando ha TTY, mantendo o caminho automatico para pipe e `--yes`. Novo Principio VIII (Diagnose Before Installing). Sessoes graficas e perfis de desenvolvimento entram como escopo configuravel.
- **1.2.0 (2026-11-09)**: preset restilizado (rofi, plank, picom, Arc, apps GNOME) removido a pedido do usuario; `xfce` passa a ser o XFCE padrao e `cinnamon` vira a sessao padrao.
- **1.3.0 (2026-11-10)**: HTTPS autoassinado na LAN para o noVNC, com `dextermux-tls` para gerar, renovar e alternar o modo sem reinstalar.
- **2.0.0 (2026-11-10)**: escopo reduzido a XFCE4 minimo; Cinnamon, MATE, presets, perfis de dev e `dextermux-session` removidos. Principio II volta a exigir instalador sem prompts. Novo Principio IX (Process Budget) para o limite de 32 processos do Android. Tunel desligado por padrao e `.bashrc` sem autostart.
