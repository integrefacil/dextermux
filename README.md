# dextermux

Desktop remoto no Termux com Cinnamon ou XFCE, VNC, noVNC por HTTPS e SSH.
Instalador modular e interativo.

```bash
curl -fsSL https://integrefacil.github.io/dextermux/setup.sh | bash
```

A pagina publicada serve o instalador em `/setup.sh`. Rodando por pipe, os modulos de `lib/` sao
baixados de um commit fixo e verificados por SHA256 antes de executar. Clonando o repositorio,
`bash setup.sh` usa `./lib` local e funciona sem rede.

## O que instala

- **Desktop nativo**: Cinnamon (padrao, ~1,7 GB) ou XFCE (~690 MB).
- **Remoto**: Xvnc na 5901, noVNC com HTTPS autoassinado na 6080, sshd na 8022.
- **Cloudflare**: opcional, perguntando na instalacao ou por `tunnel on`.
- **CLI**: git, curl, tar, python, openssl-tool, net-tools, nano.
- **Proot**: opcional, Ubuntu base para apps glibc, com `ubuntu` e `gui`.

O instalador nao instala ferramentas de dev, Xubuntu, Budgie ou GNOME Shell.

## Instalacao

```bash
# interativo (recomendado)
curl -fsSL https://integrefacil.github.io/dextermux/setup.sh -o setup.sh
bash setup.sh

# automatico
bash setup.sh --yes --desktop=cinnamon --no-proot --no-tunnel

# repetir com Cinnamon e proot, sem perguntas
bash setup.sh --yes --desktop=cinnamon --proot --no-tunnel
```

Com TTY, o script pergunta:

1. ambiente (Cinnamon/XFCE);
2. proot (Ubuntu para apps glibc);
3. tunel Cloudflare;
4. senha de acesso (ate 8 caracteres);
5. confirmacao com resumo.

Se ja existe instalacao, o menu oferece trocar ambiente, reparar ou reinstalar do zero.

## Acesso

O bloco de acesso aparece no fim da instalacao e em `url`:

```text
=== Acesso remoto ===
Desktop:      cinnamon
SSH:          ssh -p 8022 u0_a331@192.168.0.147
VNC local:    vnc://192.168.0.147:5901
noVNC local:  https://192.168.0.147:6080/vnc.html
Publico:      desligado (rode: tunnel on)
Senha:        8 caracteres definidos na instalacao
==========
```

No primeiro acesso HTTPS, aceite o certificado autoassinado.

## Comandos

| Comando | Efeito |
|---------|--------|
| `desktop` | sobe/religa os servicos |
| `url` | bloco de acesso |
| `status` | processos, top 5, TLS, tunel e desktop |
| `session` | mostra o desktop atual e os instalados |
| `session cinnamon` / `session xfce` | troca sem apagar |
| `tunnel on` / `off` / `status` / `url` | Cloudflare |
| `tls show` / `renew` / `enable` / `disable` | certificado |
| `password` | troca a senha de VNC/noVNC/SSH |
| `ubuntu` | shell no Ubuntu (proot) |
| `gui APP` | app do Ubuntu no desktop nativo |

## Flags

| Flag | Efeito |
|------|--------|
| `-y`, `--yes` | nao pergunta e nunca apaga |
| `--desktop=cinnamon\\|xfce` | ambiente |
| `--proot` / `--no-proot` | Ubuntu opcional |
| `--tunnel` / `--no-tunnel` | Cloudflare |
| `--tls` / `--no-tls` | HTTPS na LAN |
| `--password=PASS` | senha compartilhada (ate 8) |
| `--ssh-pubkey=KEY` | chave publica |
| `--geometry=WxH` | resolucao |
| `--reset=artifacts` | B1: artefatos + proot |
| `--reset=home` | B2: artefatos + proot + `$HOME` |
| `--repair` | regrava configs e reinicia |
| `--proot` | instala apenas o Ubuntu |
| `--dry-run` | mostra o plano |

## Reinstalar do zero

```bash
# B1: mantem projetos, chaves e .ssh
bash setup.sh --reset=artifacts

# B2: apaga todo o HOME (duas confirmacoes)
bash setup.sh --reset=home
```

B1 remove `~/.dextermux`, `~/.vnc`, scripts, noVNC, boot, bloco do `.bashrc` e rootfs do proot.
B2 remove tambem projetos, `.ssh` e configuracoes. Sem TTY, nenhum reset roda.

## Proot (apps glibc)

```bash
bash setup.sh --proot          # instala apenas o Ubuntu
ubuntu                         # shell no Ubuntu
gui firefox                    # app do Ubuntu no desktop nativo
```

- Ubuntu base, sem ferramentas de dev.
- Snap, Flatpak e apps com systemd/GPU nao funcionam.
- AppImage arm64: `gui /caminho/app.AppImage --appimage-extract-and-run`.
- x86_64 nao roda de forma util.

## Limite de 32 processos

Android 12+ mata o app acima de 32 processos. O `status` mede e classifica:
ate 22 `ok`, 23-26 `atencao`, 27+ `critico`. Um navegador usa 10-15 processos.

## Pendencias manuais

1. Instalar o app Termux:Boot e abrir uma vez.
2. Samsung: Aplicativos > Termux > Bateria > Sem restricoes.
3. Bateria > Apps que nunca dormem > Termux.
4. Reservar o IP do celular no roteador.
5. Aceitar o certificado autoassinado no primeiro acesso HTTPS.

## Documentacao

- [Quickstart](specs/001-remote-desktop/quickstart.md)
- [Spec](specs/001-remote-desktop/spec.md)
- [Plano](specs/001-remote-desktop/plan.md)
- [Pesquisa](specs/001-remote-desktop/research.md)
- [Tarefas](specs/001-remote-desktop/tasks.md)
- [Contrato CLI](specs/001-remote-desktop/contracts/cli-contract.md)
- [Constituicao](specs/constitution.md)
