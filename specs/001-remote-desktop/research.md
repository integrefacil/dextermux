# Research: Ambiente remoto no Termux

Registro das investigacoes que levaram ao `setup.sh`. Cada item tem sintoma, causa e decisao.

## 1. sshd nao aceita conexao (timeout)

- **Sintoma**: `ssh user@ip -p 8022` fica "piscando" e termina em `Connection timed out`.
- **Causa real encontrada**: o IP do celular mudou apos reboot (`192.168.0.147` -> `192.168.0.170`); o host antigo respondia ping mas nao tinha sshd. Segundo fator: `sshd -d` atende **uma** conexao e sai, derrubando o servidor.
- **Decisao**: nunca usar `sshd -d` para operacao; subir `sshd` normal e com `setsid`.

## 2. Porta 8022 "em uso"

- **Sintoma**: `sshd -d -p 8022` -> `Address already in use` mesmo com `pgrep -af sshd` vazio.
- **Causa**: socket/lock orfao ou processo invisivel (outro perfil/clone do Termux). `pgrep` nao ve processos de outro usuario Android.
- **Decisao**: reboot limpa sockets orfaos; no setup, `sshd` sobe sem `-d` e com `setsid`.

## 3. Diagnostico de sockets bloqueado no Android

- **Sintoma**: `ss -ltn` -> `Cannot bind netlink socket: Permission denied`; `netstat -ltn` -> `not support for af inet (tcp)`; `ip route get` -> netlink denied.
- **Causa**: Android 10+ restringe netlink e `/proc/net/*` para apps.
- **Decisao**: nao depender desses comandos. Para descobrir IP, usar `ifconfig` **sem argumento** (lista `wlan0`; `ifconfig wlan0` falha em `/proc/net/dev`).

## 4. xrdp quebrado no Termux

- **Sintoma**: login no xrdp -> `General login error`; log `Bugcheck; inconsistent auth result. info=0x... status=5`.
- **Causa**: `xrdp 0.10.6.1` (repo termux-x11) tem patch de autenticacao da era 0.9 (`return 1`) aplicado sobre a API nova (que espera `struct auth_info *` + `errorcode`). Resultado inconsistente.
- **Decisao**: descartar xrdp no fluxo principal. Se necessario no futuro, usar proot com Ubuntu ou aguardar correcao do pacote.

## 5. Certificado TLS do xrdp ausente (historico)

- **Sintoma**: `Cannot read private key file .../key.pem` e `MAC checksum error` no Remmina.
- **Causa**: o pacote remove `cert.pem`/`key.pem` e nao regenera.
- **Decisao**: irrelevante no fluxo VNC, mas registrado caso alguem volte ao xrdp: gerar com `openssl req -x509 -newkey rsa:2048 -nodes -keyout key.pem -out cert.pem -days 3650 -subj "/CN=termux"` (pacote `openssl-tool`, nao `openssl`).

## 6. `pip install websockify` trava o celular

- **Sintoma**: `pip3 install websockify` fica minutos em "Installing backend dependencies" e derruba a responsividade.
- **Causa**: puxa `numpy`, que compila do zero (cmake/ninja/compilador) na CPU do celular.
- **Decisao**: `pip3 install --no-deps websockify`. O aviso `no 'numpy' module, HyBi protocol will be slower` e aceitavel.

## 7. Remmina: "No supported auth types"

- **Sintoma**: VNC conecta mas Remmina aborta com `No supported auth types`.
- **Causa**: Xvnc oferecia `VeNCrypt` + `VncAuth`; o cliente nao negociava.
- **Decisao**: subir Xvnc com `-SecurityTypes VncAuth`.

## 8. VNC nao volta apos queda

- **Sintoma**: `vncserver :1` -> `Warning: localhost:1 is taken because of .../.X1-lock`.
- **Causa**: lock orfao apos processo morto.
- **Decisao**: `start-desktop.sh` remove `$TMPDIR/.X1-lock`, `$TMPDIR/.X11-unix/X1` e `~/.vnc/*.pid` quando `Xvnc :1` nao esta rodando.

## 9. Android matando o Termux

- **Sintoma**: sshd/VNC/cloudflared somem; as vezes so o sshd.
- **Causa**: gerenciamento de bateria da Samsung (Apps em suspensao / suspensao profunda / "colocar apps nao usados em suspensao") e pressao de memoria.
- **Decisao**: `termux-wake-lock`, `setsid`, Termux:Boot e banner com auto-start. O setup imprime as pendencias manuais de bateria.

## 10. Nitidez e resolucao

- **Sintoma**: texto borrado; desktop 1280x720 em janela maior com faixas.
- **Causa**: compressao do VNC + resolucao fixa.
- **Decisao**: `-geometry 1600x900`, antialiasing/hinting (`/Xft/Antialias=1`, `/Xft/Hinting=1`, `/Xft/HintStyle=hintfull`, `/Xft/RGBA=rgb`) e orientacao para noVNC `Remote Resize` + Quality 9/Compression 0.

## 11. Resolucao dinamica

- **Fato**: Xvnc 1.16 tem `AcceptSetDesktopSize=on` por padrao.
- **Decisao**: noVNC em "Remote Resize" (`?resize=remote`) e Remmina com "Dynamic resolution update".

## 12. Cloudflare tunnel

- **Fato**: `cloudflared` esta no repo principal do Termux (2026.10.7). Quick tunnel gera `https://<random>.trycloudflare.com`, gratuito, sem limite pratico de banda, URL efemera.
- **Limitacao**: apenas HTTP/WebSocket; VNC puro (TCP 5901) nao passa. Por isso o tunel aponta para o noVNC (6080).
- **Decisao**: quick tunnel no `start-desktop.sh`; named tunnel com dominio fica como evolucao.

## 13. Comportamento do `curl | bash`

- **Fato**: stdin e consumido pelo script; qualquer `read` quebra. `set -o pipefail` + `head -c` gera SIGPIPE e aborta.
- **Decisao**: `set -eu` (sem pipefail) e geracao de senha com `|| true`.

## Versoes validadas (2026-11-09)

| Componente | Versao |
|------------|--------|
| XFCE | 4.20 |
| TigerVNC (Xvnc) | 1.16.2 |
| noVNC | 1.5.0 |
| websockify | sem numpy |
| cloudflared | 2026.10.7 |
| OpenSSH | 10.6 |
| Termux | aarch64, Android 15 (Samsung A15) |
