# dextermux

Desktop Linux no Termux com acesso remoto por VNC, noVNC no navegador e tunel HTTPS do Cloudflare, instalado com um comando e configurado por um instalador interativo.

```bash
curl -fsSL https://integrefacil.github.io/dextermux/setup.sh | bash
```

A pagina publicada tambem serve o instalador em `/setup.sh`, mantido identico a raiz por CI.

Pagina do projeto: https://integrefacil.github.io/dextermux/

## O que o instalador faz

1. Le os recursos do aparelho (modelo, Android, nucleos, memoria, espaco livre, rede) e mostra um veredito antes de baixar qualquer coisa.
2. Abre um menu numerado para escolher a sessao grafica e as ferramentas de desenvolvimento, com o tamanho estimado de cada opcao.
3. Instala e configura tudo, com progresso por etapa e log em `~/dextermux-install.log`.
4. Imprime um resumo com URLs, senha, comandos e pendencias manuais.

Nao usa emojis, nao depende de `dialog`/`whiptail` e funciona sem terminal interativo quando rodado por pipe ou com `--yes`.

## Sessoes graficas

| Opcao | Descricao | Disco | Estado |
|-------|-----------|-------|--------|
| `cinnamon` | Sessao Cinnamon (linha do Linux Mint), padrao | ~1691 MB | validado |
| `xfce` | XFCE4 padrao, sem restilizacao | ~739 MB | validado |
| `mate` | Sessao MATE (visual classico do Ubuntu) | ~1345 MB | experimental |
| `all` | As tres, para comparar antes de decidir | ~2224 MB | comparacao |
| `none` | Sem desktop, apenas sshd e ferramentas | ~260 MB | validado |

O preset `xfce` instala apenas `xfce4` e `xfdesktop`, sem tema, dock, compositor ou apps extras. A sessao padrao e `cinnamon`.

MATE ainda nao foi validado no aparelho. O `~/.vnc/xstartup` detecta sessao que morre em menos de 15 segundos, registra em `$TMPDIR/session.log` e cai para `xfce`.

## Acesso

- Remmina/VNC: `vnc://<ip-do-celular>:5901`
- Navegador local: `http://<ip-do-celular>:6080/vnc.html`
- Navegador externo: `<url-do-tunel>/vnc.html`
- Sessao de teste em paralelo: `http://<ip-do-celular>:6081/vnc.html`

## Comandos

| Comando | Efeito |
|---------|--------|
| `desktop` | sobe sshd, Xvnc, websockify e cloudflared |
| `url` | imprime as URLs e o estado dos servicos |
| `dextermux-session` | mostra a sessao atual, as instaladas e os displays ativos |
| `dextermux-session set cinnamon` | troca a sessao padrao e reinicia o VNC |
| `dextermux-session try mate` | sobe a sessao no display `:2` (noVNC 6081), reiniciando-o se preciso |
| `dextermux-session try mate 3` | sobe a sessao em outro display (`:3`, noVNC 6082) |
| `dextermux-session stop` | encerra o display `:2` |
| `dextermux-session stop 3` | encerra o display `:3` |
| `dextermux-session remove cinnamon` | remove os pacotes exclusivos da sessao (`xfce`, `cinnamon` ou `mate`) |

## Flags do instalador

| Flag | Efeito |
|------|--------|
| `-y`, `--yes` | nao pergunta nada, usa os padroes |
| `--desktop=NAME` | `cinnamon` (padrao), `xfce`, `mate`, `all` ou `none` |
| `--dev=LIST` | `core`, `web`, `rust`, `go`, `java`, `db`, `browser` ou `none` |
| `--geometry=WxH` | resolucao inicial (default `1600x900`) |
| `--password=PASS` | senha do VNC (max. 8 caracteres) |
| `--ssh-pubkey=KEY` | chave publica para `authorized_keys` |
| `--tunnel` / `--no-tunnel` | liga ou desliga o Cloudflare (default ligado) |
| `--repair` | nao instala pacotes, apenas regrava configs e reinicia |
| `--dry-run` | mostra o plano e sai sem alterar nada |
| `--list` | lista presets, tamanhos e perfis |

Variaveis de ambiente continuam aceitas: `VNC_PASS`, `GEOMETRY`, `NOVNC_VER`, `SSH_PUBKEY`, `TUNNEL`, `DEXTERMUX_ASCII=1`, `DEXTERMUX_NO_UPDATE=1`.

## Perfis de desenvolvimento

| Grupo | Pacotes | Disco |
|-------|---------|-------|
| `core` | git, gh, neovim, tmux, zsh, starship, ripgrep, fd, fzf, jq, lazygit, eza, bat, zoxide, htop, micro, rsync | ~255 MB |
| `web` | nodejs-lts, php, composer, python-pip | ~270 MB |
| `rust` | rust | ~1104 MB |
| `go` | golang | ~725 MB |
| `java` | openjdk-17, gradle, kotlin, clang, make, cmake, android-tools | ~1365 MB |
| `db` | mariadb, postgresql, sqlite, redis, nginx | ~296 MB |
| `browser` | chromium | ~1278 MB |

## Modos de execucao

```bash
# interativo, recomendado (URL curta da pagina)
curl -fsSL https://integrefacil.github.io/dextermux/setup.sh | bash

# interativo sem gravar arquivo
bash <(curl -fsSL https://integrefacil.github.io/dextermux/setup.sh)

# pipe direto (interativo se houver terminal, automatico sem terminal)
curl -fsSL https://integrefacil.github.io/dextermux/setup.sh | bash

# automatico com escolhas
curl -fsSL https://integrefacil.github.io/dextermux/setup.sh \
  | VNC_PASS=MinhaSen bash -s -- --desktop=cinnamon --dev=core,web
```

A pagina publicada serve o instalador em `/setup.sh`. O arquivo `docs/setup.sh` e uma copia
sincronizada automaticamente por CI (`.github/workflows/sync-setup.yml`) a cada push em `setup.sh`.
A fonte canonica continua sendo o `setup.sh` da raiz.

Em `curl | bash` o stdin e o proprio script, entao o instalador abre `/dev/tty` para ler as respostas sem consumir o codigo. Sem terminal disponivel, ele usa os padroes.

## Limpeza do preset antigo

Se voce instalou a versao com XFCE restilizado (rofi, plank, picom, Arc, apps GNOME), o script nao
remove nada sozinho. Para limpar o aparelho:

```bash
rm -f ~/.dextermux/theme.sh ~/.dextermux/wallpaper.svg "$PREFIX/bin/dextermux-theme"
rm -rf ~/.config/rofi ~/.config/plank
rm -f ~/.config/picom.conf ~/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml
rm -f ~/.local/share/fonts/Ubuntu-*.ttf
pkg uninstall -y rofi plank-reloaded picom arc-gtk-theme xfce4-whiskermenu-plugin
pkg autoremove -y
pkg clean
```

`gnome-terminal` fica instalado de proposito: e o terminal padrao do Cinnamon. `gsettings-desktop-schemas`
tambem fica, porque e dependencia do Cinnamon. O `autoremove` remove apenas o que ninguem mais usa.

A sessao `ubuntu` antiga passa a ser lida como `xfce`, entao nao e preciso mexer em `~/.dextermux/session`.

## Pendencias manuais

1. Instalar o app Termux:Boot e abrir uma vez.
2. Samsung: Aplicativos -> Termux -> Bateria -> Sem restricoes.
3. Bateria -> Limites de uso em segundo plano -> Apps que nunca dormem -> Termux.
4. Remover o Termux de Apps em suspensao e suspensao profunda.
5. Reservar o IP do celular no roteador.

## Documentacao

- [Quickstart](specs/001-remote-desktop/quickstart.md)
- [Spec](specs/001-remote-desktop/spec.md)
- [Plano](specs/001-remote-desktop/plan.md)
- [Pesquisa e causas](specs/001-remote-desktop/research.md)
- [Tarefas](specs/001-remote-desktop/tasks.md)
- [Contrato CLI](specs/001-remote-desktop/contracts/cli-contract.md)

## Nao usa xrdp

O pacote `xrdp 0.10.6.1` do Termux tem bug de autenticacao (`Bugcheck; inconsistent auth result`). O caminho suportado e VNC + noVNC.
