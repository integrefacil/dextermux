# Quickstart: dextermux

## 1. Instalar

No Termux do celular:

```bash
curl -fsSL https://raw.githubusercontent.com/<user>/<repo>/main/setup.sh -o setup.sh
bash setup.sh
```

O instalador mostra os recursos do aparelho, abre os menus e so instala depois da confirmacao.

Sem gravar arquivo:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/<user>/<repo>/main/setup.sh)
```

Pipe direto (interativo se houver terminal, automatico sem terminal):

```bash
curl -fsSL https://raw.githubusercontent.com/<user>/<repo>/main/setup.sh | bash
curl -fsSL https://raw.githubusercontent.com/<user>/<repo>/main/setup.sh \
  | VNC_PASS=MinhaSen bash -s -- --desktop=ubuntu --dev=core,web --no-tunnel
```

Conferir o plano antes de instalar:

```bash
bash setup.sh --dry-run --desktop=all --dev=core,web
bash setup.sh --list
```

## 2. Escolher a sessao grafica

| Opcao | O que e | Disco |
|-------|---------|-------|
| `ubuntu` | XFCE sem menus: barra unica, rofi na tecla Super, dock plank, tema Arc-Dark, apps GNOME | ~817 MB |
| `cinnamon` | Sessao do Linux Mint (experimental) | ~1691 MB |
| `mate` | Visual classico do Ubuntu (experimental) | ~1345 MB |
| `all` | As tres, para comparar | ~2256 MB |
| `none` | Sem desktop, so sshd e ferramentas | ~260 MB |

Recomendacao para avaliar: escolha `all`, teste cada uma e depois mantenha apenas a vencedora.

## 3. Conectar

Apos abrir uma sessao nova no Termux, o banner mostra:

```text
=== Acesso remoto ===
Sessao:       ubuntu
VNC local:    vnc://192.168.0.x:5901
noVNC local:  http://192.168.0.x:6080/vnc.html
Publico:      https://xxxx.trycloudflare.com/vnc.html
======================
```

- Remmina (LAN): protocolo **VNC**, `192.168.0.x:5901`, senha do `VNC_PASS`.
- Navegador (LAN): `http://192.168.0.x:6080/vnc.html`.
- Navegador (externo): URL do tunel + `/vnc.html`.

## 4. Comparar sessoes

```bash
dextermux-session list          # instaladas e qual e a padrao
dextermux-session try mate      # abre o MATE em paralelo no display :2
dextermux-session stop mate     # encerra o :2
dextermux-session set mate      # troca a padrao e reinicia o :1
dextermux-session remove mate   # remove os pacotes exclusivos do MATE
```

Enquanto o `:2` estiver ativo, abra `http://<ip>:6081/vnc.html` em outra aba e compare com a `6080`.
Se uma sessao experimental morrer em menos de 15 segundos, o `xstartup` cai para `ubuntu` e registra
o motivo em `$TMPDIR/session.log`.

## 5. Comandos do dia a dia

| Comando | Efeito |
|---------|--------|
| `desktop` | sobe sshd, Xvnc, websockify e cloudflared (idempotente) |
| `url` | imprime o banner com as URLs e o estado atual |
| `dextermux-theme` | reaplica o visual Ubuntu-like |
| `vncserver -kill :1` | encerra a sessao VNC principal |
| `pkill -x cloudflared` | derruba o tunel atual |
| `tail -f $TMPDIR/cf.log` | log do tunel |
| `tail -f ~/.vnc/localhost:1.log` | log do Xvnc |
| `tail -f ~/dextermux-install.log` | log da ultima instalacao |

## 6. Qualidade e resolucao

noVNC (engrenagem):

- **Scaling Mode**: Remote Resize (ou abra `.../vnc.html?resize=remote`).
- **Quality**: 9.
- **Compression**: 0 ou 1.

Remmina: aba **Advanced** -> qualidade **Best** e **Dynamic resolution update**.

## 7. Pendencias manuais (uma vez por instalacao)

1. Instalar o app **Termux:Boot** (F-Droid/GitHub) e abrir uma vez.
2. Samsung: **Configuracoes -> Aplicativos -> Termux -> Bateria -> Sem restricoes**.
3. **Configuracoes -> Bateria -> Limites de uso em segundo plano -> Apps que nunca dormem** -> Termux.
4. Remover Termux de **Apps em suspensao** e **Apps em suspensao profunda**.
5. Reservar o IP do celular no roteador.
6. `passwd` para definir senha do usuario, se quiser.

## 8. Troubleshooting

| Sintoma | Causa provavel | Acao |
|---------|----------------|------|
| Banner diz "parado" | Android matou os processos | `desktop` |
| `No supported auth types` | cliente nao negociou VncAuth | confirme `-SecurityTypes VncAuth` no `start-desktop.sh` |
| Tela preta / VNC nao sobe | lock `.X1-lock` orfao | `rm -f $TMPDIR/.X1-lock` e `desktop` |
| `Address already in use` na 8022 | sshd zumbi | reiniciar o Termux ou `pkill -x sshd; desktop` |
| URL publica nao abre | tunnel caiu / URL mudou | `url` e `pkill -x cloudflared; desktop` |
| Sessao caiu e voltou para XFCE | sessao experimental falhou | `cat $TMPDIR/session.log` |
| Painel sem os plugins | XML rejeitado pelo XFCE | `dextermux-theme` e reiniciar a sessao |
| Dock nao aparece | `plank` iniciou antes do compositor | `pkill -x plank; setsid plank &` |
| Texto borrado | compressao alta | Quality 9 / Compression 0 no noVNC |
| Resolucao nao acompanha | Remote Resize desligado | ativar em Scaling Mode |

## 9. Seguranca

- O tunel quick expoe o noVNC na internet; a unica barreira e a senha de 8 caracteres do VNC.
- Para exposicao continua, migrar para named tunnel + Cloudflare Access (dominio proprio).
- Nao reutilize a mesma senha do VNC em outros servicos.

## 10. Referencias internas

- `spec.md`: requisitos e criterios.
- `plan.md`: decisoes e estrutura.
- `research.md`: causas e workarounds de cada problema encontrado.
- `tasks.md`: o que ja foi feito e proximos passos.
- `contracts/cli-contract.md`: flags, variaveis, arquivos, portas e logs.
