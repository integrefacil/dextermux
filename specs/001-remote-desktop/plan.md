# Implementation Plan: dextermux v6

**Branch**: `001-remote-desktop` | **Date**: 2026-11-11 | **Spec**: [spec.md](./spec.md)

**Input**: `specs/001-remote-desktop/spec.md` (v6.0.0)

## Summary

Instalador modular: `setup.sh` e um bootstrap que carrega `lib/*.sh` (locais no repositorio ou baixadas de um commit fixo com SHA256 no modo pipe). O fluxo e interativo quando ha TTY e automatizado com `--yes`. O padrao e Cinnamon nativo, com XFCE como opcao e troca sem apagar. O acesso remoto combina Xvnc, noVNC com HTTPS autoassinado, sshd e tunel Cloudflare opcional. Proot Ubuntu e opcional, apenas para apps glibc, com ponte grafica para o desktop nativo. O bloco de acesso (SSH, VNC, noVNC, tunel, senha) e impresso no fim e nos comandos relevantes.

## Technical Context

**Language**: Shell (bash/sh do Termux), aarch64.
**Dependencias**: `x11-repo`, `tigervnc`, `openssh`, `openssl-tool`, `python`, `net-tools`, `cloudflared`, `curl`, `tar`, `dbus`, `git`, `nano`; Cinnamon (`cinnamon`, `gnome-terminal`) ou XFCE minimo; `proot-distro` opcional.
**Testing**: `bash -n` e `shellcheck` por modulo; harness local que gera todos os scripts e valida; execucao real no aparelho.
**Target**: Termux aarch64, Android 13+.
**Performance**: XFCE ~690 MB e 15-20 processos; Cinnamon ~1,7 GB e 20-25; proot so quando usado.
**Constraints**: sem root, sem systemd, sem xrdp, sem snap/Flatpak, teto de 32 processos.
**Scale**: um dispositivo, um usuario.

## Constitution Check

- **Idempotente**: passa. Configs determinísticas e senha preservada.
- **Interativo com TTY**: passa. `--yes` desliga e nunca apaga.
- **Android constraints**: passa. `ifconfig`, `setsid`, Termux:Boot.
- **Working path**: passa. Sem xrdp/snap/Flatpak.
- **Modular verificado**: passa. `lib/` + commit fixo + SHA256.
- **Security explicit**: passa. TLS, senha de 8 e aviso do tunel.
- **Observability**: passa. Bloco de acesso + banner + logs.
- **Diagnose**: passa. Recursos antes de baixar.
- **Process budget**: passa. Status 23/27; alvo 15-25.
- **Safe destruction**: passa. B1 (1 confirmacao) e B2 (2), so com TTY.

## Project Structure

```text
setup.sh                     # bootstrap (nao editar a mao)
lib/00-common.sh             # constantes, UI, log, processos
lib/10-ui.sh                 # TTY, perguntas, menus, flags
lib/20-detect.sh             # recursos e estado
lib/30-packages.sh           # pacotes, upgrade, cleanup legado
lib/40-session.sh            # xstartup, modo, comando session
lib/50-remote.sh             # Xvnc, noVNC, TLS, banner, boot
lib/52-cast.sh               # cast para TV, controle, teclado e status
lib/60-ssh.sh                # chave, senha compartilhada, password
lib/70-proot.sh              # Ubuntu opcional + gui
lib/75-tunnel.sh             # comando tunnel
lib/80-reset.sh              # B1/B2
lib/90-summary.sh            # fluxo, instalacao, reparo, resumo
docs/index.html              # pagina
docs/setup.sh                # copia publicada (sincronizada por CI)
.github/workflows/           # sync da pagina e lint
specs/                       # constitution, spec, plano, tasks, research, contrato
```

Arquivos gerados no dispositivo:

```text
~/.vnc/xstartup              # cinnamon-session ou startxfce4
~/.vnc/passwd                # VncAuth
~/start-desktop.sh           # sshd + Xvnc + websockify + cloudflared
~/show-access.sh             # bloco de acesso
~/.dextermux/desktop         # cinnamon|xfce
~/.dextermux/password        # senha compartilhada (600)
~/.dextermux/tunnel          # 0|1
~/.dextermux/tls/            # cert, key, mode, sans
~/.dextermux/{session,tunnel,tls,password}.sh
~/.termux/boot/start-services.sh
~/noVNC/                     # noVNC 1.5.0
~/tunnel-url.txt
$PREFIX/bin/{desktop,url,session,tunnel,tls,password,ubuntu,gui}
```

## Componentes

| Componente | Responsabilidade |
|------------|------------------|
| `setup.sh` | resolver libs, verificar SHA256, source e chamar `main` |
| `90-summary` | fluxo interativo, instalacao, reparo, resumo |
| `40-session` | xstartup, modo, troca de desktop |
| `50-remote` | Xvnc, noVNC, TLS, banner e bloco de acesso |
| `60-ssh` | authorized_keys, senha compartilhada, `password` |
| `75-tunnel` | `tunnel on/off/status/url` |
| `70-proot` | Ubuntu base e ponte `gui` |

## Decisoes tecnicas

1. **VNC em vez de RDP**: `xrdp` quebrado no Termux.
2. **`VncAuth`**: compatibilidade com noVNC e Remmina.
3. **Cinnamon padrao**: escolha do usuario; XFCE fica como alternativa leve.
4. **Cinnamon e pesado por dependencia**: `cinnamon` exige nemo/mint-themes/ibus (~1,7 GB); nao ha como enxugar sem quebrar o pacote.
5. **Modular com SHA256**: A2/C1; o pipe baixa do commit fixo e verifica antes de executar.
6. **Interativo com TTY**: E1; `--yes` para automacao.
7. **B1/B2**: um reset para artefatos e outro para `$HOME`, com duas confirmacoes no segundo.
8. **Senha unica**: 8 caracteres por limitacao do VncAuth; SSH tenta `passwd`, com fallback orientado.
9. **Proot opcional**: Ubuntu base + `--shared-tmp`/cookie X11; sem dev.
10. **Tunel sob demanda**: `cloudflared` instalado, desligado por padrao, controlado por `tunnel`.
11. **Bloco de acesso**: `show-access.sh` unico, chamado pelos comandos.
12. **Sem dev**: nenhum opencode, perfil ou Xubuntu no instalador.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| `lib/` com download no pipe | legibilidade sem perder o `curl \| bash` | arquivo unico dificulta manutencao |
| Cinnamon ~1,7 GB | dependencia dura do pacote | enxugar quebra o apt |
| Senha de 8 no SSH | mesma senha do VNC | senha separada contraria o pedido |
| Proot opcional | apps glibc | sem proot, apps glibc nao rodam |
