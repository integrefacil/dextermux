# Contrato CLI: setup.sh (v6)

## Invocacao

```bash
curl -fsSL <url> | bash          # baixa lib/ do commit fixo e verifica SHA256
bash setup.sh                    # usa ./lib local, sem rede
bash setup.sh --yes --desktop=xfce --no-proot --no-tunnel
bash setup.sh --reset=artifacts
bash setup.sh --reset=home
bash setup.sh --proot            # instala apenas o Ubuntu
```

Com TTY, o instalador pergunta ambiente, proot, tunel e senha. Sem TTY ou com
`--yes`, usa os padroes e nunca executa reset.

## Flags

| Flag | Default | Descricao |
|------|---------|-----------|
| `-y`, `--yes` | desligado | nao pergunta; usa padroes e nao apaga |
| `--desktop=NAME` | `cinnamon` | `cinnamon` ou `xfce` |
| `--proot` / `--no-proot` | `--no-proot` | instala Ubuntu base para apps glibc |
| `--tunnel` / `--no-tunnel` | `--no-tunnel` | liga o Cloudflare |
| `--tls` / `--no-tls` | `--tls` | HTTPS autoassinado na LAN |
| `--password=PASS` | aleatoria | senha compartilhada (ate 8, truncada) |
| `--ssh-pubkey=KEY` | vazio | chave em `authorized_keys` |
| `--geometry=WxH` | `1600x900` | resolucao do Xvnc |
| `--reset=artifacts` | desligado | B1: apaga artefatos e proot (1 confirmacao) |
| `--reset=home` | desligado | B2: apaga artefatos, proot e `$HOME` (2 confirmacoes) |
| `--repair` | desligado | regrava configs e reinicia, sem instalar |
| `--dry-run` | desligado | imprime o plano e sai |
| `--version` | | versao |
| `-h`, `--help` | | ajuda |

## Variaveis

`VNC_PASS`, `GEOMETRY`, `NOVNC_VER`, `SSH_PUBKEY`, `TUNNEL`, `TLS`, `DESKTOP`, `PROOT`,
`DEXTERMUX_ASCII=1`, `DEXTERMUX_NO_UPDATE=1`, `DEXTERMUX_NO_UPGRADE=1`.

## Saida

- Banner com versao.
- Painel de recursos (modelo, Android, memoria, disco, rede, processos).
- Menus numerados quando ha TTY.
- Progresso `[NN/NN]`.
- Bloco de acesso: SSH, VNC, noVNC, tunel, senha, chaves.
- Resumo com processos, log, comandos e pendencias.

## Codigos de saida

| Codigo | Significado |
|--------|-------------|
| 0 | concluido |
| 1 | fora do Termux, flag invalida, falha critica, checksum invalido |
| 130 | interrompido |

## Arquivos gerados

| Caminho | Conteudo |
|---------|----------|
| `~/.vnc/xstartup` | `cinnamon-session` ou `startxfce4` |
| `~/.vnc/passwd` | senha VncAuth (600) |
| `~/start-desktop.sh` | sshd, Xvnc, websockify, cloudflared |
| `~/show-access.sh` | bloco de acesso |
| `~/.dextermux/desktop` | `cinnamon` ou `xfce` |
| `~/.dextermux/password` | senha compartilhada (600) |
| `~/.dextermux/tunnel` | `0` ou `1` |
| `~/.dextermux/tls/{server.crt,server.key,mode,sans}` | certificado e modo |
| `~/.dextermux/{session,tunnel,tls,password}.sh` | implementacoes dos comandos |
| `~/.termux/boot/start-services.sh` | boot |
| `~/noVNC/` | noVNC 1.5.0 |
| `~/tunnel-url.txt` | ultima URL publica |
| `~/dextermux-install.log` | log sem senha |
| `~/.bashrc` | bloco `# dextermux-start` com o banner |
| `$PREFIX/bin/{desktop,url,session,tunnel,tls,password}` | comandos basicos |
| `$PREFIX/bin/{ubuntu,gui}` | apenas com proot |

## Comandos

| Comando | Efeito |
|---------|--------|
| `desktop` | sobe/religa sshd, Xvnc, websockify e tunel |
| `url` | imprime o bloco de acesso |
| `status` | processos, top 5, TLS, tunel e desktop |
| `session` | mostra o desktop atual e os instalados |
| `session cinnamon` / `session xfce` | troca e reinicia |
| `tunnel on` / `off` / `status` / `url` | controla o Cloudflare |
| `tls show` / `renew` / `enable` / `disable` / `mode` | certificado |
| `password` | troca a senha de VNC/noVNC/SSH |
| `ubuntu` | shell no Ubuntu (com proot) |
| `gui APP` | app do Ubuntu no desktop nativo |

## Portas

| Porta | Servico |
|-------|---------|
| 8022 | sshd |
| 5901 | Xvnc (VncAuth) |
| 6080 | websockify + noVNC (HTTPS por padrao) |

## Processos e logs

| Processo | Log |
|----------|-----|
| `Xvnc :1` | `~/.vnc/localhost:1.log` |
| `websockify` | `$TMPDIR/ws-6080.log` |
| `cloudflared` | `$TMPDIR/cf.log` |
| instalacao | `~/dextermux-install.log` |

Orcamento: XFCE 15-20; Cinnamon 20-25; navegador +10-15; teto Android 32.

## Idempotencia

- `pkg install` so recebe ausentes.
- Senha preservada se `--password` nao for passado.
- `~/noVNC` so baixa se ausente.
- Bloco do `.bashrc` entre marcadores.
- `start-desktop.sh` nao duplica e corrige o modo TLS.
- `pkg clean` ao final.

## Reset

- B1: remove `~/.dextermux`, `~/.vnc`, `~/start-desktop.sh`, `~/show-access.sh`, `~/noVNC`,
  boot, bloco do `.bashrc`, rootfs do proot e symlinks. Mantem `$HOME`, `.ssh` e projetos.
- B2: remove tudo de `$HOME` e o proot, apos duas confirmacoes; o script se reexecuta de `$TMPDIR`.
- Sem TTY: nenhum reset executa.
