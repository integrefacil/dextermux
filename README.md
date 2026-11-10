# dextermux

XFCE4 remoto no Termux com VNC, noVNC por HTTPS e SSH, instalado com um comando.

```bash
curl -fsSL https://integrefacil.github.io/dextermux/setup.sh | bash
```

A pagina publicada tambem serve o instalador em `/setup.sh`, mantido identico a raiz por CI.

Pagina do projeto: https://integrefacil.github.io/dextermux/

## O que instala

- **XFCE4 minimo**: `xfwm4`, `xfce4-panel`, `xfce4-session`, `xfce4-settings`, `xfconf`, `xfdesktop`, `thunar`, `xfce4-terminal`.
- **TigerVNC** (`Xvnc`) com `VncAuth` na porta 5901.
- **noVNC + websockify** na porta 6080, com HTTPS autoassinado na LAN.
- **sshd** na porta 8022, com chave publica opcional.
- **Cloudflare quick tunnel** opcional, desligado por padrao.
- **Comandos**: `desktop`, `url`, `dextermux-status`, `dextermux-tls`.
- **Banner** ao abrir o Termux e autostart no boot via Termux:Boot.

O instalador nao faz perguntas: tudo vem por flag ou variavel de ambiente.

## Acesso

| Onde | Endereco |
|------|----------|
| VNC (LAN) | `vnc://<ip>:5901` |
| Navegador (LAN) | `https://<ip>:6080/vnc.html` |
| Navegador (externo, com `--tunnel`) | `<url-do-tunel>/vnc.html` |
| SSH | `ssh -p 8022 <usuario>@<ip>` |

O banner e o resumo mostram o comando SSH pronto, com usuario e IP. Para autorizar uma chave depois,
rode `dextermux-ssh add "ssh-ed25519 AAAA... usuario@pc"` no Termux. Sem chave, use a senha do Termux
(defina com `passwd`).

No primeiro acesso HTTPS o navegador mostra um aviso de certificado: aceite uma vez e o noVNC
conecta por `wss`. O IP da LAN entra nas SANs e o certificado e regenerado quando o IP muda.

## Comandos

| Comando | Efeito |
|---------|--------|
| `desktop` | sobe sshd, Xvnc, websockify e o tunel (se ligado) |
| `url` | mostra IP, portas, TLS e estado |
| `dextermux-desktop` | mostra ou troca o modo do desktop (`native`/`xubuntu`) |
| `dextermux-dev` | abre o opencode no Ubuntu, ou um shell se ele nao existir |
| `dextermux-ubuntu` | shell no Ubuntu com o XFCE acessivel |
| `dextermux-gui APP` | roda um app grafico do Ubuntu no XFCE nativo |
| `dextermux-ssh` | usuario, IP, porta, comando e chaves autorizadas |
| `dextermux-ssh add "<chave>"` | autoriza uma chave publica sem editar arquivo |
| `dextermux-status` | processos, top 5 por memoria, TLS e tunel |
| `dextermux-tls show` | certificado, SANs e validade |
| `dextermux-tls renew` | regenera o certificado da LAN |
| `dextermux-tls enable` / `disable` | liga ou desliga o HTTPS local |
| `dextermux-tls mode` | imprime `https` ou `http` |

## Flags

| Flag | Efeito |
|------|--------|
| `--geometry=WxH` | resolucao inicial (default `1600x900`) |
| `--password=PASS` | senha do VNC (max. 8 caracteres) |
| `--ssh-pubkey=KEY` | chave publica para `authorized_keys` |
| `--tunnel` / `--no-tunnel` | liga ou desliga o Cloudflare (default desligado) |
| `--tls` / `--no-tls` | HTTPS autoassinado na LAN (default ligado) |
| `--icons` / `--no-icons` | icones na area de trabalho (default desligado, economiza gvfs/tumbler) |
| `--ubuntu` / `--no-ubuntu` | Ubuntu proot para ferramentas glibc (default ligado) |
| `--xubuntu` | instala Xubuntu completo em rootfs dedicado e usa como desktop |
| `--desktop=MODE` | `native` (XFCE leve) ou `xubuntu` |
| `--reset-proot` | apaga os rootfs do proot (exige `--confirm=APAGAR`) |
| `--reset-all` | apaga rootfs e o `$HOME` do Termux (exige `--confirm=APAGAR`) |
| `--confirm=APAGAR` | libera os dois resets |
| `--repair` | nao instala pacotes; regrava configs e reinicia |
| `--dry-run` | mostra o plano e sai |
| `--version` | versao do instalador |

Variaveis aceitas: `VNC_PASS`, `GEOMETRY`, `NOVNC_VER`, `SSH_PUBKEY`, `TUNNEL`, `TLS`,
`DEXTERMUX_ASCII=1`, `DEXTERMUX_NO_UPDATE=1`.

Exemplos:

```bash
# chave SSH e senha definidas
curl -fsSL https://integrefacil.github.io/dextermux/setup.sh \
  | VNC_PASS=MinhaSen SSH_PUBKEY="ssh-ed25519 AAAA... usuario@pc" bash

# com tunel publico
curl -fsSL https://integrefacil.github.io/dextermux/setup.sh | bash -s -- --tunnel

# aplicar mudancas sem reinstalar
bash setup.sh --repair --no-tls
```

## Ferramentas glibc (Ubuntu proot)

O Termux usa Bionic e nao executa binarios glibc, como o opencode. O instalador cria um Ubuntu
via `proot-distro` (por padrao) e integra com o desktop:

```bash
dextermux-dev                 # opencode (ou shell, se ainda nao instalado)
dextermux-ubuntu              # shell no Ubuntu
dextermux-gui libreoffice     # app grafico do Ubuntu no XFCE nativo
```

Dentro do Ubuntu, instale o que precisar com `apt`. A ponte grafica usa o mesmo Xvnc do XFCE:
o socket X11 em `$TMPDIR/.X11-unix/X1` e compartilhado com `--shared-tmp`, e o cookie e copiado
para `/root/.Xauthority`. Nao existe um segundo desktop.

- Disco: ~500 MB para o rootfs; `apt` adiciona o que voce instalar.
- O `opencode` fica em `/root/.opencode/bin` dentro do Ubuntu; o wrapper `opencode` do Termux
  chama o `dextermux-dev`.
- Apps que exigem systemd, polkit ou GPU dedicada nao funcionam.
- Para pular o Ubuntu: `--no-ubuntu`.
- O binario antigo em `~/.opencode/bin` (glibc, nao executa no Termux) pode ser removido:
  `rm -rf ~/.opencode`.

## Xubuntu no proot (experimental)

`--xubuntu` cria um rootfs dedicado `xubuntu`, instala `xubuntu-desktop` completo, `tigervnc` e
`dbus-x11`, e passa a usar esse desktop. O XFCE nativo fica como fallback.

```bash
bash setup.sh --xubuntu              # instala e ativa
dextermux-desktop native             # volta ao XFCE leve
dextermux-desktop xubuntu            # retorna ao Xubuntu
```

- Disco: ~3 GB (rootfs + desktop completo).
- Tempo: 20-40 minutos no aparelho.
- **Risco**: Xubuntu completo sobe ~25-30 processos ocioso. Sem ADB, qualquer navegador pode
  disparar o signal 9 do Android. Use com essa expectativa.
- Se o Xubuntu nao subir em 20 segundos, o script cai automaticamente para o XFCE nativo.

## Reset (destrutivo)

```bash
# apagar apenas os rootfs do proot
bash setup.sh --reset-proot --confirm=APAGAR

# apagar rootfs + todo o $HOME do Termux e reinstalar do zero
curl -fsSL https://integrefacil.github.io/dextermux/setup.sh -o setup.sh
bash setup.sh --reset-all --confirm=APAGAR
```

`--reset-all` apaga projetos, chaves SSH, `.vnc`, TLS e configuracoes do Termux. Nunca roda sem
`--confirm=APAGAR`, e so funciona com o script em arquivo (nao por pipe).

## Limite de 32 processos (Android 12+)

O Android 12 introduziu o **phantom process killer**: processos criados por apps fora do ciclo de
componentes sao mortos com `SIGKILL` (signal 9) acima de 32 no total. Nao e um limite do Termux e
nao aparece como mensagem no terminal.

O stack deste projeto fica em ~15 processos ocioso e ~20 com terminal e SSH abertos. O daemon do Thunar e os agentes do GNOME (ssh-agent/gpg-agent) ficam desligados.
Para medir:

```bash
dextermux-status
```

Faixas: ate 22 `ok`, 23-26 `atencao`, 27+ `critico`. A contagem ignora utilitarios transitorios (`ps`, `grep`, `wc`).

Um navegador sozinho usa 10-15 processos (um por aba/renderer). Se a contagem subir, feche abas e
apps pesados; o `dextermux-status` mostra a contagem e o top 5.

Se o SSH cair depois de um `pkg upgrade` (o openssh e substituido), rode no Termux:

```bash
pkill -x sshd; sshd
```

## Pendencias manuais

1. Instalar o app Termux:Boot e abrir uma vez.
2. Samsung: Aplicativos -> Termux -> Bateria -> Sem restricoes.
3. Bateria -> Limites de uso em segundo plano -> Apps que nunca dormem -> Termux.
4. Remover o Termux de Apps em suspensao e suspensao profunda.
5. Reservar o IP do celular no roteador.
6. No primeiro acesso HTTPS, aceitar o certificado autoassinado.

## Documentacao

- [Quickstart](specs/001-remote-desktop/quickstart.md)
- [Spec](specs/001-remote-desktop/spec.md)
- [Plano](specs/001-remote-desktop/plan.md)
- [Pesquisa e causas](specs/001-remote-desktop/research.md)
- [Tarefas](specs/001-remote-desktop/tasks.md)
- [Contrato CLI](specs/001-remote-desktop/contracts/cli-contract.md)

## Nao usa xrdp

O pacote `xrdp 0.10.6.1` do Termux tem bug de autenticacao (`Bugcheck; inconsistent auth result`).
O caminho suportado e VNC + noVNC.
