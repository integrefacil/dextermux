# Contrato CLI: setup.sh

## Invocacao

```bash
# interativo (recomendado)
curl -fsSL <url> -o setup.sh && bash setup.sh
bash <(curl -fsSL <url>)
bash setup.sh

# automatico
curl -fsSL <url> | bash
curl -fsSL <url> | VAR=valor bash
curl -fsSL <url> | bash -s -- --desktop=cinnamon --dev=core,web
```

Em `curl | bash` o stdin e o proprio script. O instalador abre `/dev/tty` e le as respostas desse
descritor; sem terminal disponivel, ou com `--yes`, segue com os padroes.

## Flags

| Flag | Default | Descricao |
|------|---------|-----------|
| `-y`, `--yes` | desligado | nao pergunta nada, usa os padroes |
| `--desktop=NAME` | `cinnamon` | `cinnamon`, `xfce`, `mate`, `all` ou `none` (`ubuntu` e aceito como alias de `xfce`) |
| `--dev=LIST` | `core web` | grupos separados por virgula: `core`, `web`, `rust`, `go`, `java`, `db`, `browser`, `none` |
| `--geometry=WxH` | `1600x900` | resolucao inicial do Xvnc |
| `--password=PASS` | aleatoria | senha do VncAuth (max. 8 caracteres) |
| `--ssh-pubkey=KEY` | vazio | chave publica adicionada a `~/.ssh/authorized_keys` |
| `--tunnel` / `--no-tunnel` | `--tunnel` | liga ou desliga o cloudflared |
| `--tls` / `--no-tls` | `--tls` | HTTPS autoassinado na LAN para o noVNC |
| `--repair` | desligado | nao instala pacotes; regrava configs e reinicia servicos |
| `--dry-run` | desligado | imprime o plano e sai sem alterar nada |
| `--list` | desligado | lista presets, tamanhos e perfis |
| `-h`, `--help` | | ajuda |
| `--version` | | versao do instalador |

## Variaveis de ambiente

| Variavel | Default | Descricao |
|----------|---------|-----------|
| `VNC_PASS` | aleatoria de 8 chars | senha do VNC Auth; se `~/.vnc/passwd` existe e a variavel nao for informada, a senha e preservada |
| `GEOMETRY` | `1600x900` | resolucao inicial do Xvnc |
| `NOVNC_VER` | `1.5.0` | tag do noVNC baixada do GitHub |
| `SSH_PUBKEY` | vazio | chave publica adicionada a `~/.ssh/authorized_keys` |
| `TUNNEL` | `1` | `1` sobe o cloudflared; `0` desliga |
| `DEXTERMUX_ASCII` | `0` | `1` desenha a interface sem caracteres de caixa |
| `DEXTERMUX_NO_UPDATE` | `0` | `1` pula `pkg update` |

## Saida (stdout)

- Banner e versao.
- Painel `Recursos do sistema` com veredito (suficiente, com ressalvas ou insuficiente).
- Menus numerados: ambiente grafico, ferramentas de desenvolvimento, acesso remoto e confirmacao.
- Progresso por etapas no formato `[NN/15] Titulo`.
- Linha final de servicos: `VNC 5901 | noVNC 6080 | sessao: <nome>`.
- Bloco `Resumo` com usuario, sessao, URLs, senha, log, comandos e pendencias manuais.

## Codigos de saida

| Codigo | Significado |
|--------|-------------|
| 0 | instalacao (ou reparo) concluida e servicos iniciados |
| 1 | nao esta no Termux, flag invalida ou falha de comando critico |
| 130 | interrompido pelo usuario (Ctrl+C) |

## Arquivos criados/atualizados

| Caminho | Conteudo |
|---------|----------|
| `~/.vnc/xstartup` | le `~/.dextermux/session.<disp>`, sobe dbus e a sessao com fallback para `xfce` |
| `~/.vnc/passwd` | senha VncAuth (600) |
| `~/start-desktop.sh` | orquestrador de servicos por display |
| `~/show-access.sh` | banner de URLs e sessao |
| `~/.dextermux/session` | sessao padrao |
| `~/.dextermux/session.<display>` | override por display (teste no `:2`) |
| `~/.dextermux/running.<display>` | sessao realmente iniciada no display (usado para detectar troca) |
| `~/.dextermux/session-manager.sh` | implementacao de `dextermux-session` |
| `~/.dextermux/tls.sh` | implementacao de `dextermux-tls` |
| `~/.dextermux/tls/server.crt` | certificado autoassinado (SANs: IP da LAN, 127.0.0.1, localhost) |
| `~/.dextermux/tls/server.key` | chave privada (600) |
| `~/.dextermux/tls/mode` | `1` = HTTPS, `0` = HTTP |
| `~/.dextermux/wallpaper.svg` | papel de parede em gradiente |
| `~/.termux/boot/start-services.sh` | boot |
| `~/noVNC/` | noVNC 1.5.0 |
| `~/tunnel-url.txt` | ultima URL publica |
| `~/dextermux-install.log` | log da execucao |
| `~/.ssh/authorized_keys` | chave, se `SSH_PUBKEY` |
| `~/.bashrc` | bloco `# dextermux-start` ... `# dextermux-end` |
| `$PREFIX/bin/desktop` | symlink para `start-desktop.sh` |
| `$PREFIX/bin/url` | symlink para `show-access.sh` |
| `$PREFIX/bin/dextermux-session` | symlink para `session-manager.sh` |
| `$PREFIX/bin/dextermux-tls` | symlink para `tls.sh` |

## Comandos instalados

| Comando | Efeito |
|---------|--------|
| `desktop` | sobe sshd, Xvnc, websockify e cloudflared no display `:1` |
| `url` | imprime IP, portas, sessao e estado dos servicos |
| `dextermux-session` | mostra a sessao padrao, as instaladas e os displays ativos |
| `dextermux-session list` | lista sessoes com estado |
| `dextermux-session set NOME` | define a sessao padrao e reinicia o `:1` |
| `dextermux-session try NOME [DISPLAY]` | sobe a sessao no display indicado (padrao `:2`), reiniciando-o se estiver ativo com outra sessao |
| `dextermux-session stop [DISPLAY]` | encerra o display indicado (padrao `:2`) |
| `dextermux-session remove NOME` | remove pacotes exclusivos de `xfce`, `cinnamon` ou `mate` |
| `dextermux-tls ensure` | gera o certificado se ausente, IP mudou ou expira em 30 dias |
| `dextermux-tls renew` | regenera o certificado |
| `dextermux-tls enable` / `disable` | liga ou desliga o HTTPS local e para websockify/cloudflared |
| `dextermux-tls show` | certificado, SANs e validade |
| `dextermux-tls mode` | imprime `https` ou `http` |

## Portas

| Porta | Servico | Escopo |
|-------|---------|--------|
| 8022 | sshd | LAN |
| 5901 | Xvnc (VncAuth) | LAN |
| 6080 | websockify + noVNC (HTTPS autoassinado por padrao) | LAN e tunel |
| 5902 | Xvnc da sessao de teste | LAN |
| 6081 | websockify + noVNC da sessao de teste (mesmo esquema do 6080) | LAN |
| 3389 | xrdp | nao usado (pacote quebrado) |

## Processos e logs

| Processo | Log |
|----------|-----|
| `Xvnc :1` / `Xvnc :2` | `~/.vnc/localhost:<disp>.log` |
| `websockify` | `$TMPDIR/ws-<porta>.log` |
| `cloudflared` | `$TMPDIR/cf.log` (origem `https://localhost:6080` com `--no-tls-verify` quando TLS esta ligado) |
| `sshd` | syslog do Termux |
| sessao que falhou | `$TMPDIR/session.log` |
| instalacao | `~/dextermux-install.log` |

## Idempotencia

- `pkg install -y` so recebe pacotes ausentes (`dpkg-query`).
- `~/.vnc/passwd` nao e sobrescrito sem `VNC_PASS`.
- `~/noVNC` so e baixado se `vnc.html` estiver ausente.
- O bloco do `.bashrc` e removido/reinserido entre os marcadores.
- `~/start-desktop.sh` detecta processos ativos e nao duplica.
- `pkg clean` roda ao final para liberar o cache de download.
