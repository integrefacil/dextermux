# Feature Specification: Ambiente remoto no Termux (XFCE4 + VNC + SSH)

**Feature Branch**: `001-remote-desktop`
**Created**: 2026-11-09
**Status**: Implemented (instalador v3.0.0)
**Input**: Usuario quer um ambiente remoto leve e previsivel no Termux, focado em SSH, XFCE4, acesso remoto e TLS, sem menus interativos e com teto de processos.

## User Scenarios & Testing

### User Story 1 - Instalar com um comando, sem perguntas (Priority: P1)

O usuario troca de celular, reseta o Termux ou reinstala o app e precisa recuperar o ambiente sem repetir passos manuais e sem responder menus.

**Why this priority**: e o motivo do projeto existir.

**Independent Test**: em um Termux limpo, rodar `curl -fsSL <url> | bash` e obter os servicos ativos e o resumo impresso.

**Acceptance Scenarios**:

1. **Given** um Termux sem XFCE/VNC instalado, **When** o usuario executa o instalador de uma linha, **Then** XFCE4 minimo, TigerVNC, noVNC, sshd e TLS ficam instalados e configurados.
2. **Given** o instalador executado duas vezes seguidas, **When** a segunda execucao termina, **Then** nao ha duplicacao de linhas, a senha existente e preservada e os servicos continuam funcionando.
3. **Given** a instalacao concluida, **When** o usuario abre `https://<ip>:6080/vnc.html` e aceita o certificado, **Then** o desktop XFCE aparece e aceita a senha do VNC.
4. **Given** um terminal sem TTY, **When** o instalador roda, **Then** ele nao bloqueia esperando entrada.

### User Story 2 - Saber as URLs ao abrir o Termux (Priority: P1)

O usuario nao quer memorizar IP, porta ou URL publica.

**Why this priority**: sem o banner o usuario nao consegue acessar apos reinicios ou quedas.

**Independent Test**: abrir uma sessao nova no Termux e ver o bloco "Acesso remoto" com VNC, noVNC e estado do tunel.

**Acceptance Scenarios**:

1. **Given** os servicos ativos, **When** o usuario abre o Termux, **Then** o banner mostra IP real, 5901, 6080 com o esquema correto e o estado do tunel.
2. **Given** os servicos parados, **When** o usuario abre o Termux, **Then** o banner indica `desktop`.
3. **Given** o usuario digitou `url`, **When** o comando termina, **Then** o mesmo banner e impresso.

### User Story 3 - Acessar de fora da rede local (Priority: P2)

O usuario quer acessar o desktop pela internet quando ligar o tunel.

**Why this priority**: valor alto, mas opcional e desligado por padrao.

**Independent Test**: rodar `bash setup.sh --repair --tunnel`, abrir a URL `*.trycloudflare.com/vnc.html` de outra rede e chegar ao login do VNC.

**Acceptance Scenarios**:

1. **Given** o cloudflared ativo, **When** o usuario acessa a URL publica, **Then** a pagina do noVNC carrega sobre HTTPS e conecta no websocket.
2. **Given** o celular reiniciado, **When** o Termux:Boot sobe os servicos, **Then** um novo tunel e criado e a nova URL aparece no banner.

### User Story 4 - HTTPS na LAN e teto de processos (Priority: P2)

O usuario quer trafego criptografado na rede local e um ambiente que nao seja morto pelo Android.

**Why this priority**: seguranca basica e estabilidade em uso continuo.

**Independent Test**: `curl -k https://<ip>:6080/vnc.html` retorna 200; `dextermux-status` mostra a contagem abaixo de 24.

**Acceptance Scenarios**:

1. **Given** TLS ligado, **When** o usuario abre a porta 6080, **Then** a resposta e HTTPS e HTTP em texto claro e recusado.
2. **Given** o IP da LAN mudou, **When** o usuario roda `dextermux-tls renew` e `desktop`, **Then** o novo IP consta nas SANs.
3. **Given** o ambiente ocioso, **When** o usuario roda `dextermux-status`, **Then** a contagem fica em `ok` e o top 5 e listado.
4. **Given** a contagem acima de 30, **When** o status roda, **Then** o veredito e `critico` e os comandos ADB sao exibidos.

### Edge Cases

- O Android mata os processos em segundo plano: o banner indica "parado" e `desktop` religa.
- O Android 12+ mata o app acima de 32 processos (phantom process killer): `dextermux-status` mede e orienta.
- O IP da Wi-Fi muda apos reboot: o banner recalcula e o certificado e regenerado.
- O lock `.X1-lock` fica orfao apos queda: o `start-desktop.sh` remove antes de subir.
- A porta 8022 fica ocupada por sshd zumbi: reiniciar via `desktop`.
- O quick tunnel cai e a URL muda: o banner sempre le a ultima URL do log.
- Cliente Remmina recusa os tipos de seguranca: servidor so oferece `VncAuth`.
- Certificado nao aceito: o navegador nao abre o `wss`; e preciso aceitar a pagina HTTPS antes.

## Requirements

### Functional Requirements

- **FR-001**: O instalador DEVE rodar sem prompts, aceitando configuracao apenas por flags e variaveis de ambiente.
- **FR-002**: O instalador DEVE ser idempotente, preservando senha VNC e chaves SSH existentes.
- **FR-003**: O sistema DEVE instalar apenas XFCE4 minimo (`xfwm4`, `xfce4-panel`, `xfce4-session`, `xfce4-settings`, `xfconf`, `xfdesktop`, `thunar`, `xfce4-terminal`).
- **FR-004**: O sistema DEVE subir o Xvnc com `VncAuth` e resolucao inicial configuravel.
- **FR-005**: O sistema DEVE servir noVNC + websockify na porta 6080.
- **FR-006**: O sistema DEVE oferecer um tunel HTTPS publico opcional via Cloudflare, desligado por padrao.
- **FR-007**: O sistema DEVE iniciar o sshd e permitir chave publica pre-carregada.
- **FR-008**: O sistema DEVE imprimir as URLs e o estado ao abrir o Termux e via comando `url`.
- **FR-009**: O sistema DEVE religar tudo com o comando `desktop`.
- **FR-010**: O sistema DEVE iniciar os servicos no boot via Termux:Boot.
- **FR-011**: O sistema NAO DEVE depender de root, proot, systemd ou pacotes quebrados.
- **FR-012**: O sistema DEVE orientar sobre bateria, IP, porta e riscos de exposicao publica.
- **FR-013**: O instalador DEVE medir recursos (modelo, Android, nucleos, memoria, disco, rede, processos) e imprimir o resultado sem pausar.
- **FR-014**: O sistema DEVE servir o noVNC por HTTPS autoassinado na LAN, com o IP atual nas SANs e regeneracao quando o IP mudar.
- **FR-015**: O sistema DEVE permitir ligar, desligar e renovar o HTTPS local sem reinstalar.
- **FR-016**: O sistema DEVE medir e reportar a contagem de processos, avisando em 23 e marcando critico em 27, sem bloquear.
- **FR-017**: O sistema DEVE registrar log completo da execucao em `~/dextermux-install.log`.
- **FR-018**: O `.bashrc` DEVE apenas imprimir o banner, sem iniciar servicos.
- **FR-019**: O sistema DEVE exibir usuario, IP, porta 8022 e comando SSH no banner e no resumo, e permitir autorizar chaves depois da instalacao via `dextermux-ssh add`.

### Key Entities

- **Servicos remotos**: VNC (5901), noVNC (6080, HTTPS), sshd (8022), tunel publico opcional.
- **Configuracao persistida**: `~/.vnc/xstartup`, `~/.vnc/passwd`, `~/start-desktop.sh`, `~/show-access.sh`, `~/.dextermux/tls.sh`, `~/.dextermux/status.sh`, `~/.dextermux/tunnel`, `~/.dextermux/tls/{server.crt,server.key,mode,sans}`, `~/.termux/boot/start-services.sh`, `~/tunnel-url.txt`.
- **Estado de execucao**: processos `Xvnc`, `websockify`, `cloudflared`; logs em `$TMPDIR/ws-6080.log`, `$TMPDIR/cf.log`, `~/.vnc/localhost:1.log` e `~/dextermux-install.log`.

## Success Criteria

### Measurable Outcomes

- **SC-001**: Um Termux limpo chega ao desktop funcional em menos de 15 minutos com um unico comando.
- **SC-002**: Reexecutar o instalador nao altera a senha existente e nao duplica entradas no `.bashrc`.
- **SC-003**: O banner mostra as URLs corretas em 100% das aberturas com servicos ativos.
- **SC-004**: A URL publica responde HTTP 200 em `vnc.html` apos o tunel registrar a conexao.
- **SC-005**: Apos queda total, `desktop` restabelece 5901 e 6080 sem intervencao manual.
- **SC-006**: `curl -k https://<ip>:6080/vnc.html` responde 200 e a mesma porta recusa HTTP em texto claro.
- **SC-007**: O ambiente ocioso fica com 15-20 processos, abaixo do teto de 23 usado pelo status.
- **SC-008**: `dextermux-status` mostra a contagem e o top 5 em menos de 2 segundos.

## Assumptions

- O usuario tem Termux de F-Droid/GitHub e aceita instalar Termux:Boot.
- O celular tem Android 13+ e acesso a internet para baixar pacotes.
- O uso do tunel publico e pessoal e a rede de saida nao bloqueia Cloudflare.
- A senha do VNC Auth tem no maximo 8 caracteres (limitacao do protocolo).
- O usuario entende que a exposicao publica depende da senha do VNC.
- O Android 12+ limita processos criados por apps; o projeto mira ~11-17 processos.
- `gnome-shell`, `mutter` e `nautilus` nao existem no repositorio do Termux; o alvo e XFCE4.

## Checklist de qualidade

- [x] Nenhum marcador `[NEEDS CLARIFICATION]` restante
- [x] Requisitos testaveis e sem ambiguidade
- [x] Criterios de sucesso mensuraveis
