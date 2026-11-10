# Quickstart: dextermux

## 1. Instalar

```bash
curl -fsSL https://integrefacil.github.io/dextermux/setup.sh | bash
```

Com senha e chave SSH:

```bash
curl -fsSL https://integrefacil.github.io/dextermux/setup.sh \
  | VNC_PASS=MinhaSen SSH_PUBKEY="ssh-ed25519 AAAA... usuario@pc" bash
```

Com tunel publico:

```bash
curl -fsSL https://integrefacil.github.io/dextermux/setup.sh | bash -s -- --tunnel
```

Conferir o plano sem instalar:

```bash
bash setup.sh --dry-run
```

O instalador nao pergunta nada. Ele imprime os recursos do aparelho, instala, sobe os servicos e
mostra o resumo.

## 2. Conectar

Apos abrir uma sessao nova no Termux, o banner mostra:

```text
=== Acesso remoto ===
Desktop:      XFCE4
VNC local:    vnc://192.168.0.x:5901
noVNC local:  https://192.168.0.x:6080/vnc.html
Publico:      desligado (rode: desktop com --tunnel)
======================
```

- Remmina (LAN): protocolo **VNC**, `192.168.0.x:5901`, senha do `VNC_PASS`.
- Navegador (LAN): `https://192.168.0.x:6080/vnc.html`; aceite o certificado no primeiro acesso.
- Navegador (externo): so com `--tunnel`, na URL publica + `/vnc.html`.
- SSH: `ssh -p 8022 <usuario>@<ip>`.

## 3. Comandos

| Comando | Efeito |
|---------|--------|
| `desktop` | sobe sshd, Xvnc, websockify e o tunel (se ligado) |
| `url` | imprime o banner com IP, portas e estado |
| `dextermux-ssh` | usuario, IP, porta e chaves autorizadas |
| `dextermux-ssh add "<chave>"` | autoriza uma chave publica |
| `dextermux-status` | processos, top 5, TLS e tunel |
| `dextermux-tls show` | certificado, SANs e validade |
| `dextermux-tls renew` | regenera o certificado |
| `dextermux-tls disable` | volta a LAN para HTTP |
| `vncserver -kill :1` | encerra a sessao VNC |
| `tail -f $TMPDIR/cf.log` | log do tunel |
| `tail -f ~/.vnc/localhost:1.log` | log do Xvnc |
| `tail -f ~/dextermux-install.log` | log da ultima instalacao |

## 4. HTTPS na LAN

O certificado e autoassinado, gerado no aparelho, com o IP da `wlan0` nas SANs.

- Aceite o aviso no navegador uma vez; o noVNC conecta por `wss`.
- Se o IP da LAN mudar: `dextermux-tls renew` e `desktop`.
- Para eliminar o aviso, instale `~/.dextermux/tls/server.crt` como autoridade no cliente.
- Para desligar: `dextermux-tls disable` e `desktop`.

## 5. Processos e o limite de 32

Android 12+ mata com `SIGKILL` os processos criados pelo app acima de 32 no total
(phantom process killer). O ambiente fica em ~11 processos ocioso.

```bash
dextermux-status
```

- `ok` ate 22, `atencao` de 23 a 26, `critico` a partir de 27.
- Para elevar o limite, via PC com ADB:
  ```bash
  adb shell settings put global settings_enable_monitor_phantom_procs false
  adb shell device_config put activity_manager max_phantom_processes 2147483647
  ```

## 6. Qualidade e resolucao

noVNC (engrenagem) ou parametros na URL:

- `?resize=remote` para acompanhar o tamanho da janela.
- `?quality=7&compression=1` para reduzir banda sem borrar texto.

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
| App morre com signal 9 | phantom process killer | `dextermux-status` e os comandos ADB |
| `No supported auth types` | cliente nao negociou VncAuth | confirme `-SecurityTypes VncAuth` no `start-desktop.sh` |
| Tela preta / VNC nao sobe | lock `.X1-lock` orfao | `rm -f $TMPDIR/.X1-lock` e `desktop` |
| `Address already in use` na 8022 | sshd zumbi | reiniciar o Termux ou `pkill -x sshd; desktop` |
| Aviso de certificado | certificado autoassinado | aceite uma vez ou instale o cert no cliente |
| `wss` nao conecta | certificado nao aceito na pagina | abra `https://<ip>:6080/vnc.html` primeiro |
| IP da LAN mudou | SANs antigas | `dextermux-tls renew` e `desktop` |
| `library "libicuuc.so.79" not found` | pacotes desatualizados apos upgrade de soname | `pkg upgrade -y` |
| SSH caiu apos `pkg upgrade` | openssh substituido | `pkill -x sshd; sshd` |
| URL publica nao abre | tunel desligado ou caiu | `desktop` com `--tunnel` |

## 9. Seguranca

- O tunel quick expoe o noVNC na internet; a unica barreira e a senha de 8 caracteres do VNC.
- Para exposicao continua, migrar para named tunnel + Cloudflare Access (dominio proprio).
- Nao reutilize a mesma senha do VNC em outros servicos.

## 10. Referencias internas

- `spec.md`: requisitos e criterios.
- `plan.md`: decisoes e estrutura.
- `research.md`: causas e workarounds.
- `tasks.md`: o que ja foi feito.
- `contracts/cli-contract.md`: flags, arquivos, portas e logs.
