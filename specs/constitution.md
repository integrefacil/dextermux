# dextermux Constitution

## Core Principles

### I. Idempotent by Default
O `setup.sh` DEVE poder rodar varias vezes sem duplicar configuracao, sem apagar dados do usuario e sem quebrar um ambiente ja funcional. Toda escrita em arquivo de configuracao DEVE ser idempotente (marcadores, `grep` de guarda ou sobrescrita deterministica).

### II. One-Command Bootstrap (NON-NEGOTIABLE)
O provisionamento DEVE funcionar como `curl -fsSL <url> | bash`, sem prompts interativos. Toda variacao DEVE vir por variavel de ambiente (`VNC_PASS`, `GEOMETRY`, `NOVNC_VER`, `SSH_PUBKEY`, `TUNNEL`). Nenhum `read` pode bloquear a execucao.

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

## Additional Constraints

- Plataforma alvo: Termux aarch64, Android 13+ (validado em Samsung Galaxy A15, Android 15).
- Pacotes: `x11-repo`, `xfce4`, `tigervnc`, `openssh`, `openssl-tool`, `python`, `net-tools`, `cloudflared`, `git`, `curl`, `tar`.
- Portas: 8022 (sshd), 5901 (VNC), 6080 (noVNC/websocket).
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

**Version**: 1.0.0 | **Ratified**: 2026-11-09 | **Last Amended**: 2026-11-09
