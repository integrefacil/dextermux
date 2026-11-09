# Feature Specification: Ambiente remoto no Termux (desktop + acesso externo)

**Feature Branch**: `001-remote-desktop`
**Created**: 2026-11-09
**Status**: Implemented
**Input**: Usuario quer reinstalar o ambiente de acesso remoto do celular com um unico comando, sem repetir a investigacao feita manualmente.

## User Scenarios & Testing

### User Story 1 - Reinstalar o ambiente com um comando (Priority: P1)

O usuario troca de celular, reseta o Termux ou reinstala o app e precisa recuperar o desktop remoto sem repetir os passos manuais.

**Why this priority**: e o motivo do projeto existir; sem isso todo o conhecimento se perde.

**Independent Test**: em um Termux limpo, rodar `curl -fsSL <raw> | bash` e obter os servicos ativos e as URLs impressas no terminal.

**Acceptance Scenarios**:

1. **Given** um Termux sem XFCE/VNC instalado, **When** o usuario executa o instalador de uma linha, **Then** XFCE, TigerVNC, noVNC, sshd e cloudflared ficam instalados e configurados.
2. **Given** o instalador executado duas vezes seguidas, **When** a segunda execucao termina, **Then** nao ha duplicacao de linhas, senha existente e preservada e os servicos continuam funcionando.
3. **Given** a instalacao concluida, **When** o usuario abre o navegador no endereco local informado, **Then** o desktop XFCE aparece e aceita a senha do VNC.

### User Story 2 - Saber as URLs ao abrir o Termux (Priority: P1)

O usuario nao quer memorizar IP, porta ou URL publica.

**Why this priority**: sem o banner o usuario nao consegue acessar apos reinicios ou quedas.

**Independent Test**: abrir uma sessao nova no Termux e ver o bloco "Acesso remoto" com VNC local, noVNC local e URL publica.

**Acceptance Scenarios**:

1. **Given** os servicos ativos, **When** o usuario abre o Termux, **Then** o banner mostra IP real, porta 5901, porta 6080 e URL publica vigente.
2. **Given** os servicos parados, **When** o usuario abre o Termux, **Then** o banner indica o comando `desktop` para religar.
3. **Given** o usuario digitou `url`, **When** o comando termina, **Then** o mesmo banner e impresso novamente.

### User Story 3 - Acessar de fora da rede local (Priority: P2)

O usuario quer acessar o desktop pela internet sem depender de estar na mesma Wi-Fi.

**Why this priority**: valor alto, mas depende do noVNC e de um tunel ativo.

**Independent Test**: abrir a URL `*.trycloudflare.com/vnc.html` de uma rede externa e chegar ao login do VNC.

**Acceptance Scenarios**:

1. **Given** o cloudflared ativo, **When** o usuario acessa a URL publica, **Then** a pagina do noVNC carrega sobre HTTPS e conecta no websocket.
2. **Given** o celular reiniciado, **When** o usuario abre o Termux, **Then** um novo tunel e criado e a nova URL aparece no banner.

### User Story 4 - Melhorar nitidez e resolucao dinamica (Priority: P3)

O usuario quer texto nitido e resolucao acompanhando a janela do cliente.

**Why this priority**: usabilidade, nao bloqueia o uso.

**Independent Test**: redimensionar a janela do navegador com "Remote Resize" e ver o desktop acompanhar; texto legivel com qualidade 9.

**Acceptance Scenarios**:

1. **Given** o Xvnc iniciado, **When** o cliente noVNC pede redimensionamento, **Then** a resolucao muda sem reiniciar o servidor.
2. **Given** antialiasing/hinting configurados, **When** o desktop e aberto, **Then** o texto aparece suavizado.

### Edge Cases

- O Android mata os processos em segundo plano: o banner deve indicar "rode: desktop".
- O IP da Wi-Fi muda apos reboot: o banner recalcula o IP atual.
- O lock `.X1-lock` fica orfao apos queda: o `start-desktop.sh` remove antes de subir.
- A porta 8022 fica ocupada por sshd zumbi: reiniciar via `desktop`.
- O quick tunnel cai e a URL muda: o banner sempre le a ultima URL do log.
- Cliente Remmina recusa os tipos de seguranca: servidor so oferece `VncAuth`.

## Requirements

### Functional Requirements

- **FR-001**: O instalador DEVE rodar sem prompts interativos, aceitando configuracao por variaveis de ambiente.
- **FR-002**: O instalador DEVE ser idempotente, preservando senha VNC e chaves SSH existentes.
- **FR-003**: O sistema DEVE instalar e configurar XFCE4 como sessao do VNC.
- **FR-004**: O sistema DEVE subir o Xvnc com `VncAuth` e resolucao inicial configuravel.
- **FR-005**: O sistema DEVE servir noVNC + websockify na porta 6080.
- **FR-006**: O sistema DEVE oferecer um tunel HTTPS publico opcional via Cloudflare.
- **FR-007**: O sistema DEVE iniciar o sshd e permitir chave publica pre-carregada.
- **FR-008**: O sistema DEVE imprimir as URLs de acesso ao abrir o Termux e via comando `url`.
- **FR-009**: O sistema DEVE religar tudo com o comando `desktop`.
- **FR-010**: O sistema DEVE iniciar os servicos no boot via Termux:Boot.
- **FR-011**: O sistema NAO DEVE depender de root, proot, systemd ou pacotes quebrados.
- **FR-012**: O sistema DEVE orientar sobre bateria/IP/porta e riscos de exposicao publica.

### Key Entities

- **Servicos remotos**: VNC (5901), noVNC (6080), sshd (8022), tunel publico.
- **Configuracao persistida**: `~/.vnc/xstartup`, `~/.vnc/passwd`, `~/start-desktop.sh`, `~/show-access.sh`, `~/.termux/boot/start-services.sh`, `~/tunnel-url.txt`.
- **Estado de execucao**: processos `Xvnc`, `websockify`, `cloudflared`; logs em `$TMPDIR/{cf,ws}.log` e `~/.vnc/localhost:1.log`.

## Success Criteria

### Measurable Outcomes

- **SC-001**: Um Termux limpo chega ao desktop funcional em menos de 15 minutos com um unico comando.
- **SC-002**: Reexecutar o instalador nao altera a senha existente e nao duplica entradas no `.bashrc`.
- **SC-003**: O banner mostra as tres URLs corretas em 100% das aberturas com servicos ativos.
- **SC-004**: A URL publica responde HTTP 200 em `vnc.html` apos o tunel registrar a conexao.
- **SC-005**: Apos queda total, `desktop` restabelece 5901 e 6080 sem intervencao manual.

## Assumptions

- O usuario tem Termux de F-Droid/GitHub e aceita instalar Termux:Boot.
- O celular tem Android 13+ e acesso a internet para baixar pacotes.
- O uso do tunel publico e pessoal e a rede de saida nao bloqueia Cloudflare.
- A senha do VNC Auth tem no maximo 8 caracteres (limitacao do protocolo).
- O usuario entende que a exposicao publica depende da senha do VNC.

## Checklist de qualidade

- [x] Nenhum marcador `[NEEDS CLARIFICATION]` restante
- [x] Requisitos testaveis e sem ambiguidade
- [x] Criterios de sucesso mensuraveis
