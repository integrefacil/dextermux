# Quickstart: dextermux

## 1. Instalar

No Termux do celular:

```bash
curl -fsSL https://raw.githubusercontent.com/<user>/<repo>/main/setup.sh | bash
```

Com senha definida e chave SSH:

```bash
curl -fsSL https://raw.githubusercontent.com/<user>/<repo>/main/setup.sh \
  | VNC_PASS=MinhaSen \
    SSH_PUBKEY="ssh-ed25519 AAAA... usuario@pc" \
    bash
```

Sem tunel publico:

```bash
curl -fsSL https://raw.githubusercontent.com/<user>/<repo>/main/setup.sh | TUNNEL=0 bash
```

## 2. Conectar

Apos abrir uma sessao nova no Termux, o banner mostra:

```text
=== Acesso remoto ===
VNC local:    vnc://192.168.0.x:5901
noVNC local:  http://192.168.0.x:6080/vnc.html
Publico:      https://xxxx.trycloudflare.com/vnc.html
======================
```

- Remmina (LAN): protocolo **VNC**, `192.168.0.x:5901`, senha do `VNC_PASS`.
- Navegador (LAN): `http://192.168.0.x:6080/vnc.html`.
- Navegador (externo): URL do tunel + `/vnc.html`.

## 3. Comandos do dia a dia

| Comando | Efeito |
|---------|--------|
| `desktop` | sobe sshd, Xvnc, websockify e cloudflared (idempotente) |
| `url` | imprime o banner com as URLs e o estado atual |
| `vncserver -kill :1` | encerra a sessao VNC |
| `pkill -x cloudflared` | derruba o tunel atual |
| `tail -f $TMPDIR/cf.log` | log do tunel |
| `tail -f ~/.vnc/localhost:1.log` | log do Xvnc |

## 4. Qualidade e resolucao

noVNC (engrenagem):

- **Scaling Mode**: Remote Resize (ou abra `.../vnc.html?resize=remote`).
- **Quality**: 9.
- **Compression**: 0 ou 1.

Remmina: aba **Advanced** -> qualidade **Best** e **Dynamic resolution update**.

## 5. Pendencias manuais (uma vez por instalacao)

1. Instalar o app **Termux:Boot** (F-Droid/GitHub) e abrir uma vez.
2. Samsung: **Configuracoes -> Aplicativos -> Termux -> Bateria -> Sem restricoes**.
3. **Configuracoes -> Bateria -> Limites de uso em segundo plano -> Apps que nunca dormem** -> Termux.
4. Remover Termux de **Apps em suspensao** e **Apps em suspensao profunda**.
5. Reservar o IP do celular no roteador.
6. `passwd` para definir senha do usuario, se quiser.

## 6. Troubleshooting

| Sintoma | Causa provavel | Acao |
|---------|----------------|------|
| Banner diz "parado" | Android matou os processos | `desktop` |
| `No supported auth types` | cliente nao negociou VncAuth | confirme `-SecurityTypes VncAuth` no `start-desktop.sh` |
| Tela preta / VNC nao sobe | lock `.X1-lock` orfao | `rm -f $TMPDIR/.X1-lock` e `desktop` |
| `Address already in use` na 8022 | sshd zumbi | reiniciar o Termux ou `pkill -x sshd; desktop` |
| URL publica nao abre | tunnel caiu / URL mudou | `url` e `pkill -x cloudflared; desktop` |
| Texto borrado | compressao alta | Quality 9 / Compression 0 no noVNC |
| Resolucao nao acompanha | Remote Resize desligado | ativar em Scaling Mode |

## 7. Seguranca

- O tunel quick expoe o noVNC na internet; a unica barreira e a senha de 8 caracteres do VNC.
- Para exposicao continua, migrar para named tunnel + Cloudflare Access (dominio proprio).
- Nao reutilize a mesma senha do VNC em outros servicos.

## 8. Referencias internas

- `spec.md`: requisitos e criterios.
- `plan.md`: decisoes e estrutura.
- `research.md`: causas e workarounds de cada problema encontrado.
- `tasks.md`: o que ja foi feito e proximos passos.
- `contracts/cli-contract.md`: variaveis, arquivos, portas e logs.
