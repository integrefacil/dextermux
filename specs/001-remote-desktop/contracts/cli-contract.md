# Contrato CLI: setup.sh

## Invocacao

```bash
curl -fsSL <url> | bash
curl -fsSL <url> | VAR=valor bash
bash setup.sh
```

## Variaveis de ambiente

| Variavel | Default | Descricao |
|----------|---------|-----------|
| `VNC_PASS` | aleatoria de 8 chars | senha do VNC Auth; se `~/.vnc/passwd` existe e a variavel nao for informada, a senha e preservada |
| `GEOMETRY` | `1600x900` | resolucao inicial do Xvnc |
| `NOVNC_VER` | `1.5.0` | tag do noVNC baixada do GitHub |
| `SSH_PUBKEY` | vazio | chave publica adicionada a `~/.ssh/authorized_keys` |
| `TUNNEL` | `1` | `1` sobe o cloudflared; `0` desliga |

## Saida (stdout)

- Progresso por etapas (`== Pacotes ==`, `== Senha do VNC ==`, ...).
- Senha gerada, quando aplicavel.
- Linha final: `VNC 5901 | noVNC 6080 | tunel: <url>`.
- Bloco `RESUMO` com usuario, URLs, senha e pendencias manuais.

## Codigos de saida

| Codigo | Significado |
|--------|-------------|
| 0 | instalacao concluida e servicos iniciados |
| 1 | nao esta no Termux ou falha de comando critico (`set -e`) |

## Arquivos criados/atualizados

| Caminho | Conteudo |
|---------|----------|
| `~/.vnc/xstartup` | sessao `startxfce4` |
| `~/.vnc/passwd` | senha VncAuth (600) |
| `~/start-desktop.sh` | orquestrador de servicos |
| `~/show-access.sh` | banner de URLs |
| `~/.termux/boot/start-services.sh` | boot |
| `~/noVNC/` | noVNC 1.5.0 |
| `~/tunnel-url.txt` | ultima URL publica |
| `~/.ssh/authorized_keys` | chave, se `SSH_PUBKEY` |
| `~/.bashrc` | bloco `# dextermux-start` ... `# dextermux-end` |
| `$PREFIX/bin/desktop` | symlink para `start-desktop.sh` |
| `$PREFIX/bin/url` | symlink para `show-access.sh` |

## Portas

| Porta | Servico | Escopo |
|-------|---------|--------|
| 8022 | sshd | LAN |
| 5901 | Xvnc (VncAuth) | LAN |
| 6080 | websockify + noVNC | LAN e tunel |
| 3389 | xrdp | nao usado (pacote quebrado) |

## Processes e logs

| Processo | Log |
|----------|-----|
| `Xvnc :1` | `~/.vnc/localhost:1.log` |
| `websockify` | `$TMPDIR/ws.log` |
| `cloudflared` | `$TMPDIR/cf.log` |
| `sshd` | syslog do Termux |

## Idempotencia

- `pkg install -y` pode rodar repetidamente.
- `~/.vnc/passwd` nao e sobrescrito sem `VNC_PASS`.
- `~/noVNC` so e baixado se `vnc.html` estiver ausente.
- O bloco do `.bashrc` e removido/reinserido entre os marcadores.
- `~/start-desktop.sh` detecta processos ativos e nao duplica.
