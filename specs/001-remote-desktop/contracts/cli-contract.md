# Contrato CLI: setup.sh

## Invocacao

```bash
curl -fsSL <url> | bash
curl -fsSL <url> | VAR=valor bash
curl -fsSL <url> | bash -s -- --tunnel
bash setup.sh
```

O instalador nao faz perguntas. Nao usa `/dev/tty`, nao consome stdin alem do proprio script e nao
depende de terminal.

## Flags

| Flag | Default | Descricao |
|------|---------|-----------|
| `--geometry=WxH` | `1600x900` | resolucao inicial do Xvnc |
| `--password=PASS` | aleatoria | senha do VncAuth (max. 8 caracteres) |
| `--ssh-pubkey=KEY` | vazio | chave publica adicionada a `~/.ssh/authorized_keys` |
| `--tunnel` / `--no-tunnel` | `--no-tunnel` | liga ou desliga o cloudflared |
| `--tls` / `--no-tls` | `--tls` | HTTPS autoassinado na LAN para o noVNC |
| `--icons` / `--no-icons` | `--no-icons` | icones na area de trabalho (desligado evita gvfs/tumbler) |
| `--ubuntu` / `--no-ubuntu` | `--ubuntu` | instala Ubuntu via proot-distro para ferramentas glibc |
| `--repair` | desligado | nao instala pacotes; regrava configs e reinicia |
| `--dry-run` | desligado | imprime o plano e sai |
| `-h`, `--help` | | ajuda |
| `--version` | | versao do instalador |

`-y`/`--yes`, `--desktop=*` e `--dev=*` sao aceitos e ignorados, por compatibilidade com a versao 2.

## Variaveis de ambiente

| Variavel | Default | Descricao |
|----------|---------|-----------|
| `VNC_PASS` | aleatoria de 8 chars | senha do VNC Auth; se `~/.vnc/passwd` existe e a variavel nao for informada, a senha e preservada |
| `GEOMETRY` | `1600x900` | resolucao inicial do Xvnc |
| `NOVNC_VER` | `1.5.0` | tag do noVNC baixada do GitHub |
| `SSH_PUBKEY` | vazio | chave publica adicionada a `~/.ssh/authorized_keys` |
| `TUNNEL` | `0` | `1` sobe o cloudflared; `0` desliga |
| `TLS` | `1` | `1` liga o HTTPS autoassinado na LAN |
| `DEXTERMUX_ASCII` | `0` | `1` desenha sem caracteres de caixa |
| `DEXTERMUX_NO_UPDATE` | `0` | `1` pula `pkg update` |

## Saida (stdout)

- Banner e versao.
- Painel `Recursos do sistema` (modelo, Android, nucleos, memoria, disco, rede, processos).
- Progresso por etapas no formato `[NN/12] Titulo`.
- Linha de servicos: `VNC 5901 | noVNC 6080 | tunel: desligado`.
- Bloco `Resumo` com usuario, URLs, senha, certificado, processos, log e pendencias manuais.

## Codigos de saida

| Codigo | Significado |
|--------|-------------|
| 0 | instalacao (ou reparo) concluida e servicos iniciados |
| 1 | nao esta no Termux, flag invalida ou falha de comando critico |
| 130 | interrompido pelo usuario (Ctrl+C) |

## Arquivos criados/atualizados

| Caminho | Conteudo |
|---------|----------|
| `~/.vnc/xstartup` | `startxfce4` com dbus, `NO_AT_BRIDGE=1` e `GTK_A11Y=none` |
| `~/.vnc/passwd` | senha VncAuth (600) |
| `~/start-desktop.sh` | sshd, Xvnc, websockify (TLS opcional) e cloudflared (opcional) |
| `~/show-access.sh` | banner de URLs e estado |
| `~/.dextermux/tls.sh` | implementacao de `dextermux-tls` |
| `~/.dextermux/status.sh` | implementacao de `dextermux-status` |
| `~/.dextermux/ssh.sh` | implementacao de `dextermux-ssh` |
| `~/.dextermux/dev.sh` | implementacao de `dextermux-dev` |
| `~/.dextermux/ubuntu.sh` | implementacao de `dextermux-ubuntu` |
| `~/.dextermux/gui.sh` | ponte grafica para apps do Ubuntu |
| `~/.dextermux/tunnel` | `1` liga o cloudflared, `0` desliga |
| `~/.dextermux/tls/server.crt` | certificado autoassinado (SANs: IP da LAN, 127.0.0.1, localhost) |
| `~/.dextermux/tls/server.key` | chave privada (600) |
| `~/.dextermux/tls/mode` | `1` = HTTPS, `0` = HTTP |
| `~/.dextermux/tls/sans` | SANs usadas na ultima geracao |
| `~/.termux/boot/start-services.sh` | boot |
| `~/noVNC/` | noVNC 1.5.0 |
| `~/tunnel-url.txt` | ultima URL publica |
| `~/dextermux-install.log` | log da execucao |
| `~/.ssh/authorized_keys` | chave, se `SSH_PUBKEY` |
| `~/.bashrc` | bloco `# dextermux-start` ... `# dextermux-end` com banner (sem autostart) |
| `$PREFIX/bin/desktop` | symlink para `start-desktop.sh` |
| `$PREFIX/bin/url` | symlink para `show-access.sh` |
| `$PREFIX/bin/dextermux-tls` | symlink para `tls.sh` |
| `$PREFIX/bin/dextermux-status` | symlink para `status.sh` |
| `$PREFIX/bin/dextermux-ssh` | symlink para `ssh.sh` |
| `$PREFIX/bin/dextermux-dev` | symlink para `dev.sh` |
| `$PREFIX/bin/dextermux-ubuntu` | symlink para `ubuntu.sh` |
| `$PREFIX/bin/dextermux-gui` | symlink para `gui.sh` |
| `$PREFIX/bin/opencode` | wrapper que chama `dextermux-dev` |

## Comandos instalados

| Comando | Efeito |
|---------|--------|
| `desktop` | sobe sshd, Xvnc, websockify e o tunel (se ligado) |
| `url` | imprime IP, portas, TLS e estado |
| `dextermux-dev` | opencode no Ubuntu, ou shell se ausente |
| `dextermux-ubuntu` | shell no Ubuntu com `DISPLAY=:1` e XAUTHORITY |
| `dextermux-gui APP` | executa app grafico do Ubuntu no XFCE nativo |
| `dextermux-ssh` | usuario, IP, porta, comando e chaves autorizadas |
| `dextermux-ssh add "<chave>"` | autoriza a chave em `authorized_keys` (700/600) |
| `dextermux-ssh list` | fingerprints das chaves autorizadas |
| `dextermux-status` | contagem de processos, top 5, TLS e tunel |
| `dextermux-tls ensure` | gera o certificado se ausente, IP mudou ou expira em 30 dias |
| `dextermux-tls renew` | regenera o certificado |
| `dextermux-tls enable` / `disable` | liga ou desliga o HTTPS e para websockify/cloudflared |
| `dextermux-tls show` | certificado, SANs e validade |
| `dextermux-tls mode` | imprime `https` ou `http` |

## Ubuntu proot

- Rootfs: `$PREFIX/var/lib/proot-distro/containers/ubuntu/rootfs`.
- Pacotes base instalados dentro: `curl`, `git`, `ca-certificates`.
- Ponte grafica: `--shared-tmp` expoe `$TMPDIR/.X11-unix/X1` como `/tmp/.X11-unix/X1`;
  `~/.Xauthority` e copiado para `/root/.Xauthority` a cada execucao.
- O wrapper `opencode` chama `dextermux-dev`, que executa `/root/.opencode/bin/opencode` se existir.
- `--no-ubuntu` pula a instalacao; `--repair` regenera os wrappers.

## Portas

| Porta | Servico | Escopo |
|-------|---------|--------|
| 8022 | sshd | LAN |
| 5901 | Xvnc (VncAuth) | LAN |
| 6080 | websockify + noVNC (HTTPS autoassinado por padrao) | LAN e tunel |
| 3389 | xrdp | nao usado (pacote quebrado) |

## Processos e logs

| Processo | Log |
|----------|-----|
| `Xvnc :1` | `~/.vnc/localhost:1.log` |
| `websockify` | `$TMPDIR/ws-6080.log` |
| `cloudflared` | `$TMPDIR/cf.log` (origem `https://localhost:6080` com `--no-tls-verify` quando TLS esta ligado) |
| `sshd` | syslog do Termux |
| instalacao | `~/dextermux-install.log` |

Orcamento esperado: ~15 processos ocioso (bash, sshd, Xvnc, websockify, xfce4-session, xfwm4,
xfce4-panel, xfdesktop, xfsettingsd, xfconfd, dbus-daemon, dbus-launch e gvfsd). Thunar, tumbler e
os agentes GNOME ficam desligados e nao entram na conta.

Faixas do `dextermux-status`: ate 22 `ok`, 23-26 `atencao`, 27+ `critico`. A contagem ignora
utilitarios transitorios (`ps`, `head`, `wc`, `tr`, `grep`, `sed`, `awk`, `sort`, `sleep`).

## Idempotencia

- `pkg upgrade -y` roda antes da instalacao para alinhar sonames (ex: `libicuuc` exigido pelo `libvte`).
- `pkg install -y` so recebe pacotes ausentes (`dpkg-query`).
- `~/.vnc/passwd` nao e sobrescrito sem `VNC_PASS`.
- `~/noVNC` so e baixado se `vnc.html` estiver ausente.
- O bloco do `.bashrc` e removido/reinserido entre os marcadores.
- `~/start-desktop.sh` detecta processos ativos e nao duplica; reinicia websockify e cloudflared
  apenas quando o modo TLS muda.
- `pkg clean` roda ao final para liberar o cache de download.
