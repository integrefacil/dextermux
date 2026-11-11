# Tasks: Ambiente remoto no Termux

**Input**: `specs/001-remote-desktop/` (spec.md, plan.md, research.md)
**Prerequisites**: plan.md e spec.md

**Status**: implementado e validado no dispositivo em 2026-11-09. Tarefas marcadas `[x]` foram concluidas.

## Phase 1: Setup

- [x] T001 Criar `setup.sh` na raiz do projeto
- [x] T002 Validar sintaxe com `bash -n`
- [x] T003 Definir variaveis de ambiente (`VNC_PASS`, `GEOMETRY`, `NOVNC_VER`, `SSH_PUBKEY`, `TUNNEL`)
- [x] T004 Garantir compatibilidade com `curl -fsSL <url> | bash` (leitura de respostas por `/dev/tty`, sem consumir o stdin do script)

## Phase 2: Foundational

- [x] T005 Instalar `x11-repo`, `xfce4`, `tigervnc`, `openssh`, `openssl-tool`, `git`, `python`, `net-tools`, `cloudflared`, `curl`, `tar`
- [x] T006 Configurar `~/.vnc/xstartup` com `startxfce4`
- [x] T007 Gerar `~/.vnc/passwd` (8 chars), preservando senha existente em reexecucao
- [x] T008 Instalar `websockify` com `--no-deps`
- [x] T009 Baixar noVNC 1.5.0 para `~/noVNC` (somente se ausente)

## Phase 3: US1 - Reinstalar com um comando (P1)

- [x] T010 Gravar `~/start-desktop.sh`
- [x] T011 Criar atalho `$PREFIX/bin/desktop`
- [x] T012 Subir servicos ao final do setup e imprimir resumo
- [x] T013 Testar reexecucao idempotente no Termux (senha preservada, sem duplicar `.bashrc`)

## Phase 4: US2 - Banner e URLs (P1)

- [x] T014 Gravar `~/show-access.sh` com IP via `ifconfig`
- [x] T015 Criar atalho `$PREFIX/bin/url`
- [x] T016 Inserir bloco no `~/.bashrc` com marcadores `# dextermux-start` / `# dextermux-end`
- [x] T017 Autostart em background quando `Xvnc :1` nao estiver rodando
- [x] T018 Validar banner em sessao nova (`bash -i -c true`)

## Phase 5: US3 - Tunel publico (P2)

- [x] T019 Integrar `cloudflared tunnel --url http://localhost:6080` no `start-desktop.sh`
- [x] T020 Salvar URL em `~/tunnel-url.txt` e ler do `$TMPDIR/cf.log`
- [x] T021 Verificar `HTTP 200` em `<url>/vnc.html` de outra rede
- [ ] T022 (evolucao) Named tunnel com dominio + Cloudflare Access

## Phase 6: US4 - Nitidez e resolucao (P3)

- [x] T023 Subir Xvnc em 1600x900
- [x] T024 Aplicar antialiasing/hinting/RGBA no `start-desktop.sh`
- [x] T025 Documentar `Remote Resize` no noVNC e `Dynamic resolution update` no Remmina

## Phase 7: Boot e seguranca

- [x] T026 Criar `~/.termux/boot/start-services.sh`
- [x] T027 Suportar `SSH_PUBKEY` no `authorized_keys`
- [x] T028 Avisar sobre senha de 8 caracteres e exposicao publica
- [x] T029 Instruir Termux:Boot, isencao de bateria e reserva de IP no resumo

## Phase 8: Documentacao

- [x] T030 `specs/constitution.md`
- [x] T031 `specs/001-remote-desktop/spec.md`
- [x] T032 `specs/001-remote-desktop/plan.md`
- [x] T033 `specs/001-remote-desktop/research.md`
- [x] T034 `specs/001-remote-desktop/tasks.md`

## Phase 9: Instalador interativo (v2.0.0)

- [x] T035 Diagnostico de recursos (modelo, Android, nucleos, memoria, disco, rede, instalacao existente) com veredito
- [x] T036 TUI numerada em bash puro, sem emojis, com fallback ASCII e `NO_COLOR`
- [x] T037 Leitura de respostas por `/dev/tty` para nao consumir o stdin de `curl | bash`
- [x] T038 Modo automatico por `--yes`, flags e variaveis de ambiente
- [x] T039 Menu de sessao grafica com custo em disco e selo `validado`/`experimental`
- [x] T040 Menu multi-select de perfis de desenvolvimento
- [x] T041 Tela de confirmacao com estimativa total e retorno as escolhas
- [x] T042 `--dry-run` e `--list`
- [x] T043 Log completo em `~/dextermux-install.log` e `pkg clean` ao final

## Phase 10: Sessoes e visual (v2.0.0)

- [x] T044 ~~Preset `ubuntu` restilizado~~ (removido na v1.2.0; virou `xfce` padrao com `xfce4` e `xfdesktop`)
- [x] T045 Presets `cinnamon` e `mate` marcados como experimentais
- [x] T046 Preset `all` com as tres sessoes e default `cinnamon`
- [x] T047 `~/.dextermux/session` e override por display
- [x] T048 `dextermux-session` com `list`, `set`, `try`, `stop` e `remove`
- [x] T049 ~~`dextermux-theme`~~ (removido na v1.2.0 junto com o preset restilizado)
- [x] T050 Fallback de 15 s para sessao que falha, com log em `$TMPDIR/session.log`
- [x] T051 `start-desktop.sh` parametrizado por display (6080/6081, 5901/5902)
- [x] T052 Atualizar README, quickstart, contrato CLI, spec, plano e constitution 1.1.0
- [x] T053 Validar Cinnamon no aparelho (aprovado pelo usuario)
- [ ] T054 Validar MATE no aparelho e promover ou remover o preset
- [x] T055 Trocar o padrao para `cinnamon` e remover o preset restilizado
- [x] T056 Gerar certificado autoassinado com `openssl` e SANs do IP da LAN
- [x] T057 Subir `websockify` com `--cert`, `--key` e `--ssl-only`
- [x] T058 Apontar o tunel para `https://localhost:6080 --no-tls-verify`
- [x] T059 Criar `dextermux-tls` (`ensure`, `renew`, `enable`, `disable`, `mode`, `show`)
- [x] T060 Atualizar banner, `url`, README, quickstart, contrato, spec, plano e pagina
- [x] T035 `specs/001-remote-desktop/quickstart.md`
- [x] T036 `specs/001-remote-desktop/contracts/cli-contract.md`

## Pendencias sugeridas (proximo agente)

- [ ] T037 Publicar o repositorio e fixar URL raw no `quickstart.md`
- [ ] T038 Opcional: empacotar como repo Termux (`.deb`) em vez de script
- [ ] T039 Opcional: named tunnel com dominio proprio e token do Cloudflare
- [ ] T040 Opcional: checar dependencias do `xrdp` quando o pacote for corrigido
- [ ] T041 Opcional: teste automatizado de fumaca (portas + HTTP 200) via script `smoke.sh`

## Dependencies & Execution Order

- Setup e Foundational bloqueiam as user stories.
- US1 e US2 sao o MVP (desktop + descoberta de URL).
- US3 depende de US1 (noVNC) e de rede externa para validar.
- US4 e melhoria sobre US1.
- Boot/seguranca e documentacao dependem do fluxo funcional.

## Notes

- Toda tarefa concluida foi validada no dispositivo real (Termux aarch64, Android 15).
- Nao reintroduzir `xrdp` sem antes confirmar correcao do pacote (ver `research.md` item 4).

## Phase 11: Foco em XFCE4 e teto de processos (v3.0.0)

- [x] T061 Remover Cinnamon, MATE, presets `all`/`none` e `dextermux-session`
- [x] T062 Remover todos os menus e leituras interativas (`read`, `/dev/tty`)
- [x] T063 Instalar XFCE minimo (sem `xfce4-notifyd` e `xfce4-power-manager`)
- [x] T064 Desligar o tunel por padrao (`--tunnel` para ligar)
- [x] T065 `.bashrc` apenas com banner, sem autostart de servicos
- [x] T066 `dextermux-status` com contagem de processos, top 5 e comandos ADB
- [x] T067 Avisos em 24 processos e critico em 30, sem bloquear instalacao
- [x] T068 Atualizar README, quickstart, contrato, spec, plano, research e constitution 2.0.0
- [x] T070 `dextermux-ssh` com status, add e list; banner e resumo com o comando SSH
- [x] T071 `pkg upgrade -y` antes da instalacao para alinhar sonames (libicu/libvte)
- [x] T072 Faixas do status: ok ate 22, atencao 23-26, critico 27+, ignorando utilitarios transitorios
- [x] T069 Validar no aparelho: `curl -k https://<ip>:6080/vnc.html` funcionando
- [x] T073 Instalar Ubuntu via proot-distro por padrao (`--no-ubuntu` para pular)
- [x] T074 Ponte grafica com `--shared-tmp` e cookie X11
- [x] T075 `dextermux-dev`, `dextermux-ubuntu`, `dextermux-gui`, wrapper `opencode` e atalhos no menu
- [x] T076 Remover o PATH do opencode glibc do `.bashrc`
- [x] T077 `--xubuntu` com rootfs dedicado, `xubuntu-desktop` e VNC interno
- [x] T078 Modo `native|xubuntu` com `dextermux-desktop` e fallback de 20 s
- [x] T079 `--reset-proot` e `--reset-all` com `--confirm=APAGAR`
- [ ] T080 Validar Xubuntu no aparelho e medir a contagem de processos

## Phase 12: v6 modular (2026-11-11)

- [x] T081 Reescrever o instalador em `lib/` com `setup.sh` bootstrap
- [x] T082 Bootstrap com `LIBS_COMMIT` fixo e SHA256 por modulo no modo pipe
- [x] T083 Fluxo interativo com TTY, `--yes` e resumo antes de executar
- [x] T084 Cinnamon padrao, XFCE opcional e comando `session` sem apagar
- [x] T085 Reset B1 (uma confirmacao) e B2 (duas) com reexecucao de `$TMPDIR`
- [x] T086 Comando `tunnel` (on/off/status/url) e pergunta na instalacao
- [x] T087 Senha compartilhada (ate 8) e comando `password`
- [x] T088 Bloco de acesso no fim e em `url`, `session`, `tunnel`, `password`, `desktop`
- [x] T089 Proot opcional (Ubuntu base + `ubuntu`/`gui`) sem ferramentas de dev
- [ ] T090 Validar no aparelho: instalar, trocar ambiente, tunel, senha e reset
