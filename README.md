# dextermux

Desktop XFCE no Termux com acesso remoto por VNC, noVNC no navegador e tunel HTTPS do Cloudflare, instalado com um comando.

```bash
curl -fsSL https://raw.githubusercontent.com/integrefacil/dextermux/main/setup.sh | bash
```

Pagina do projeto: https://integrefacil.github.io/dextermux/

## O que instala e configura

- XFCE4 (via `x11-repo`)
- TigerVNC (`Xvnc`) com sessao XFCE, `VncAuth`, 1600x900 e redimensionamento remoto
- noVNC + websockify (navegador, porta 6080)
- Cloudflare quick tunnel (HTTPS publico, opcional)
- sshd com chave publica opcional
- Banner com as URLs ao abrir o Termux, comandos `desktop` e `url`
- Autostart no boot via Termux:Boot

## Acesso

- Remmina/VNC: `vnc://<ip-do-celular>:5901`
- Navegador local: `http://<ip-do-celular>:6080/vnc.html`
- Navegador externo: `<url-do-tunel>/vnc.html`

## Comandos

| Comando | Efeito |
|---------|--------|
| `desktop` | sobe sshd, Xvnc, websockify e cloudflared |
| `url` | imprime as URLs e o estado dos servicos |

## Variaveis do instalador

| Variavel | Default | Descricao |
|----------|---------|-----------|
| `VNC_PASS` | aleatoria | senha do VNC (max. 8 caracteres) |
| `GEOMETRY` | `1600x900` | resolucao inicial |
| `NOVNC_VER` | `1.5.0` | versao do noVNC |
| `SSH_PUBKEY` | vazio | chave publica para `authorized_keys` |
| `TUNNEL` | `1` | `0` desliga o Cloudflare |

Exemplo:

```bash
curl -fsSL https://raw.githubusercontent.com/integrefacil/dextermux/main/setup.sh \
  | VNC_PASS=MinhaSen SSH_PUBKEY="ssh-ed25519 AAAA... usuario@pc" bash
```

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
