# Feature Specification: dextermux v6 (desktop remoto modular)

**Feature Branch**: `001-remote-desktop`
**Created**: 2026-11-09
**Status**: Implemented (v6.0.0)
**Input**: Usuario quer um instalador modular e interativo, com desktop remoto nativo (Cinnamon padrao ou XFCE), proot opcional para apps glibc, reinstalacao do zero em dois escopos e dados de acesso sempre visiveis.

## User Scenarios & Testing

### User Story 1 - Instalar com perguntas objetivas (Priority: P1)

O usuario roda o instalador, responde cinco perguntas e recebe o ambiente pronto.

**Why this priority**: e o fluxo principal; sem isso nada existe.

**Independent Test**: em um Termux limpo, rodar `bash setup.sh`, escolher Cinnamon, nao proot, nao tunel, definir senha e obter os servicos ativos.

**Acceptance Scenarios**:

1. **Given** um Termux sem instalacao, **When** o usuario executa o instalador, **Then** ele pergunta ambiente, proot, tunel e senha, mostra um resumo e instala.
2. **Given** a instalacao concluida, **When** o usuario abre o navegador na URL HTTPS e aceita o certificado, **Then** o desktop aparece e aceita a senha.
3. **Given** o instalador rodando duas vezes, **When** a segunda termina, **Then** senha, chaves e configs existentes sao preservadas.
4. **Given** execucao sem TTY, **When** o instalador roda, **Then** usa os padroes e nao apaga nada.

### User Story 2 - Ver os dados de acesso (Priority: P1)

O usuario quer SSH, VNC, noVNC, tunel e senha visiveis sem memorizar nada.

**Why this priority**: sem isso o acesso depende de anotacoes.

**Independent Test**: rodar `url` e conferir o bloco com usuario, SSH, VNC, noVNC, tunel e senha.

**Acceptance Scenarios**:

1. **Given** os servicos ativos, **When** o usuario abre o Termux, **Then** o banner mostra o resumo.
2. **Given** o comando `url`, **When** ele termina, **Then** o bloco completo e impresso.
3. **Given** `session`, `tunnel on/off` ou `password`, **When** terminam, **Then** o bloco e impresso.

### User Story 3 - Trocar o ambiente sem apagar (Priority: P2)

O usuario quer alternar Cinnamon e XFCE sem reinstalar.

**Why this priority**: o visual muda de ideia, os dados nao.

**Independent Test**: `session xfce` reinstala apenas o necessario, reinicia o VNC e imprime o bloco.

**Acceptance Scenarios**:

1. **Given** Cinnamon instalado e XFCE ausente, **When** o usuario roda `session xfce`, **Then** o XFCE e instalado e ativado.
2. **Given** os dois instalados, **When** o usuario alterna, **Then** nada e apagado.
3. **Given** o instalador reexecutado, **When** escolhe "trocar ambiente", **Then** o fluxo faz o mesmo.

### User Story 4 - Reinstalar do zero em dois escopos (Priority: P2)

O usuario quer limpar sem risco de apagar projetos por engano.

**Why this priority**: reinstalar e comum; apagar `$HOME` nao pode ser acidental.

**Independent Test**: escolher reinstalar, confirmar B1 (`y/N`) e obter o sistema limpo mantendo projetos e chaves.

**Acceptance Scenarios**:

1. **Given** B1, **When** confirmado, **Then** artefatos do dextermux e rootfs do proot sao removidos; `$HOME` permanece.
2. **Given** B2, **When** as duas confirmacoes sao aceitas, **Then** `$HOME` e rootfs sao removidos e o script se reexecuta de `$TMPDIR`.
3. **Given** qualquer reset sem TTY, **When** invocado, **Then** nada e apagado.

### User Story 5 - Proot opcional para apps glibc (Priority: P3)

O usuario quer instalar apps do Ubuntu depois, sem dev no instalador.

**Why this priority**: cobre binarios glibc, mas nao e necessario para o desktop.

**Independent Test**: marcar proot na instalacao, rodar `ubuntu` e `gui xterm`.

**Acceptance Scenarios**:

1. **Given** proot instalado, **When** o usuario roda `ubuntu`, **Then** abre um shell no Ubuntu.
2. **Given** proot instalado, **When** roda `gui xterm`, **Then** a janela abre no desktop nativo.
3. **Given** proot ausente, **When** o usuario roda `setup.sh --proot`, **Then** apenas o Ubuntu e instalado.

### Edge Cases

- Android mata processos: o banner indica "parado" e `desktop` religa.
- 32 processos: o `status` conta e classifica; navegador consome 10-15.
- IP muda: o certificado e regenerado com `tls renew`.
- Sessao escolhida ausente: `session` orienta instalar.
- Proot nao instalado: `gui`/`ubuntu` orientam `--proot`.
- `passwd` exige terminal: o instalador orienta, nao forca.

## Requirements

### Functional Requirements

- **FR-001**: O instalador DEVE ser interativo quando houver TTY e nao interativo com `--yes`.
- **FR-002**: O instalador DEVE ser idempotente, preservando senha, chaves e configs.
- **FR-003**: O sistema DEVE instalar Cinnamon (padrao) ou XFCE como desktop nativo.
- **FR-004**: O sistema DEVE subir Xvnc com `VncAuth` e geometria configuravel.
- **FR-005**: O sistema DEVE servir noVNC + websockify na porta 6080.
- **FR-006**: O tunel Cloudflare DEVE ser perguntado na instalacao e controlavel por `tunnel`.
- **FR-007**: O sistema DEVE iniciar sshd e aceitar chave publica.
- **FR-008**: O sistema DEVE imprimir o bloco de acesso no fim da instalacao e nos comandos relevantes.
- **FR-009**: O sistema DEVE religar tudo com `desktop`.
- **FR-010**: O sistema DEVE iniciar no boot via Termux:Boot.
- **FR-011**: O sistema NAO DEVE depender de root, systemd, xrdp, snap ou Flatpak.
- **FR-012**: O sistema DEVE orientar sobre bateria, IP e exposicao publica.
- **FR-013**: O instalador DEVE medir recursos e estado antes de instalar.
- **FR-014**: O noVNC DEVE usar HTTPS autoassinado com SANs do IP atual.
- **FR-015**: `tls` DEVE permitir show, renew, enable e disable.
- **FR-016**: `status` DEVE medir processos, avisar em 23 e marcar critico em 27.
- **FR-017**: A instalacao DEVE gravar log em `~/dextermux-install.log`, sem senha.
- **FR-018**: A senha DEVE ser unica para VNC/noVNC/SSH, com ate 8 caracteres, e alteravel por `password`.
- **FR-019**: `session` DEVE mostrar e trocar o ambiente sem apagar dados.
- **FR-020**: A reinstalacao DEVE ter B1 (uma confirmacao) e B2 (duas confirmacoes), nunca sem TTY.
- **FR-021**: O codigo DEVE ser modular em `lib/`, com bootstrap e SHA256 no modo pipe.
- **FR-022**: O proot DEVE ser opcional, com Ubuntu base e ponte grafica, sem ferramentas de dev.
- **FR-023**: `tunnel` DEVE permitir on, off, status e url depois da instalacao.
- **FR-024**: O conjunto CLI padrao DEVE incluir git, curl, tar, python, openssl-tool, net-tools e nano.

## Key Entities

- **Servicos**: VNC (5901), noVNC (6080, HTTPS), sshd (8022), tunel opcional.
- **Configuracao**: `~/.dextermux/{desktop,tunnel,password,tls/,*.sh}`, `~/.vnc/{xstartup,passwd}`, `~/start-desktop.sh`, `~/show-access.sh`, `~/.termux/boot/start-services.sh`, `~/tunnel-url.txt`.
- **Proot**: `$PREFIX/var/lib/proot-distro/containers/ubuntu/rootfs`.
- **Estado**: processos `Xvnc`, `websockify`, `cloudflared`; logs em `$TMPDIR/{ws-6080,cf}.log`, `~/.vnc/localhost:1.log`.

## Success Criteria

- **SC-001**: XFCE instalado e acessivel em menos de 15 minutos; Cinnamon em menos de 30.
- **SC-002**: Reexecutar preserva senha e nao duplica o `.bashrc`.
- **SC-003**: O bloco de acesso mostra as URLs corretas com servicos ativos.
- **SC-004**: `curl -k https://<ip>:6080/vnc.html` responde 200.
- **SC-005**: `session` troca o desktop em menos de 30 segundos sem apagar dados.
- **SC-006**: B1 remove apenas artefatos; B2 remove `$HOME` apos duas confirmacoes.
- **SC-007**: `gui xterm` abre janela no desktop nativo com proot instalado.
- **SC-008**: Sem TTY, o instalador nao apaga e usa defaults.

## Assumptions

- Termux de F-Droid/GitHub, Android 13+, internet para pacotes.
- Senha VNC de ate 8 caracteres.
- Proot nao roda systemd, snap ou GPU.
- Navegador consome 10-15 processos.
- `passwd` pode exigir terminal.

## Checklist

- [x] Sem `[NEEDS CLARIFICATION]`
- [x] Requisitos testaveis
- [x] Criterios mensuraveis
