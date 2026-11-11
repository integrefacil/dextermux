# dextermux Constitution

## Core Principles

### I. Idempotent by Default
O instalador DEVE poder rodar varias vezes sem duplicar configuracao, sem apagar dados do usuario e sem quebrar um ambiente funcional. Toda escrita de configuracao DEVE ser deterministica ou protegida por marcadores.

### II. Interactive When Possible, Never Destructive by Default
Com terminal interativo, o instalador DEVE perguntar o que muda o resultado (ambiente, proot, tunel, senha, reinstalacao) e mostrar um resumo antes de executar. Sem TTY, ou com `--yes`, DEVE usar os padroes sem nenhuma pergunta. Nenhum caminho destrutivo pode rodar sem confirmacao explicita.

### III. Android Constraints First
O ambiente roda em Termux sem root. Solucoes DEVEM respeitar o Android:
- netlink e `/proc/net/*` bloqueados (usar `ifconfig`);
- sem systemd (usar `setsid` e Termux:Boot);
- processos podem ser mortos (usar `termux-wake-lock` e orientar bateria);
- snap, Flatpak e apps que exigem systemd NAO DEVEM fazer parte do fluxo suportado.

### IV. Working Path Only
Nunca manter um caminho conhecido como quebrado no fluxo principal. `xrdp 0.10.6.1` esta fora (bug de autenticacao). O caminho suportado e Xvnc + noVNC.

### V. Modular Source, Verified Artifact
O codigo-fonte DEVE viver em `lib/*.sh`, com `setup.sh` apenas como bootstrap. Rodando do repositorio, os modulos locais DEVEM ser usados. Rodando por pipe, os modulos DEVEM ser baixados de um commit fixo e verificados por SHA256 antes de qualquer execucao. Falha de rede ou checksum DEVE abortar sem executar.

### VI. Security Is Explicit
HTTPS autoassinado na LAN, senha compartilhada limitada a 8 caracteres (VNC Auth) e aviso claro sobre a exposicao do tunel publico. A senha NAO DEVE ser gravada em log.

### VII. Observability for Humans
Toda mudanca relevante DEVE imprimir o bloco de acesso: usuario, SSH, VNC, noVNC, tunel, senha, chaves e comandos. O banner resumido aparece ao abrir o Termux.

### VIII. Diagnose Before Installing
O instalador DEVE medir modelo, Android, nucleos, memoria, disco, rede, processos e instalacao existente antes de baixar pacotes, sem pausar o fluxo.

### IX. Process Budget
O ambiente DEVE mirar 15-25 processos ociosos e manter o alerta do `status` em 23 (atencao) e 27 (critico). O teto real e 32, imposto pelo phantom process killer do Android 12+.

### X. Safe Destruction
Reinstalacao do zero DEVE ter dois escopos explicitos: artefatos do dextermux (B1) e todo o `$HOME` (B2). B1 exige uma confirmacao; B2 exige duas. Sem TTY, nenhum reset executa. O instalador DEVE se copiar para `$TMPDIR` antes de apagar o `$HOME`.

## Additional Constraints

- Plataforma alvo: Termux aarch64, Android 13+.
- Pacotes base: `x11-repo`, `tigervnc`, `openssh`, `openssl-tool`, `python`, `net-tools`, `cloudflared`, `curl`, `tar`, `dbus`, `git`, `nano`.
- Desktops nativos: Cinnamon (~1,7 GB) e XFCE (~690 MB). Sem Xubuntu, Budgie ou GNOME Shell.
- Proot opcional: Ubuntu base + ponte grafica (`ubuntu`, `gui`). Sem ferramentas de dev.
- Portas: 8022 (sshd), 5901 (VNC), 6080 (noVNC/TLS).
- Senha compartilhada: ate 8 caracteres.
- Comandos instalados: `desktop`, `url`, `status`, `session`, `tunnel`, `tls`, `password`, `ubuntu`, `gui`.

## Development Workflow

- Toda mudanca em `lib/` DEVE passar por `bash -n` e `shellcheck`.
- Mudanca em `lib/` com `setup.sh` por pipe DEVE atualizar `LIBS_COMMIT` e os SHA256.
- Falhas conhecidas DEVEM virar item em `research.md`.

## Governance

Esta constitution prevalece sobre preferencias pontuais. Emendas exigem:
1. justificativa no `plan.md`;
2. atualizacao de `spec.md`/`tasks.md` quando mudar comportamento observavel;
3. validacao no dispositivo antes de considerar concluido.

**Version**: 4.0.0 | **Ratified**: 2026-11-09 | **Last Amended**: 2026-11-11

## Emendas

- **4.0.0 (2026-11-11)**: reescrita modular (`lib/` + bootstrap verificado), interatividade com TTY, reset B1/B2, Cinnamon nativo como padrao, remocao de Xubuntu e de qualquer ferramenta de dev. Proot passa a ser opcional e apenas runtime de apps.
- **3.0.0 (2026-11-10)**: Xubuntu experimental e Principio X (Safe Destruction).
- **2.1.0 (2026-11-10)**: Ubuntu proot com ponte grafica.
- **2.0.0 (2026-11-10)**: XFCE4 minimo, sem menus, teto de processos.
