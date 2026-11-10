# Feature Specification: Ambiente remoto no Termux (desktop + acesso externo)

**Feature Branch**: `001-remote-desktop`
**Created**: 2026-11-09
**Status**: Implemented (instalador v2.0.0)
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

### User Story 5 - Escolher o que instalar antes de baixar (Priority: P1)

O usuario quer ver os recursos do aparelho e decidir a interface e as ferramentas antes de baixar centenas de megabytes.

**Why this priority**: sem diagnostico o usuario descobre que o aparelho nao comporta o preset depois de gastar espaco e tempo.

**Independent Test**: em um Termux limpo, abrir o instalador, ver o painel de recursos com veredito, escolher `all` no menu de sessoes e `core web` no de desenvolvimento, e obter exatamente esses pacotes.

**Acceptance Scenarios**:

1. **Given** o instalador aberto, **When** a primeira tela aparece, **Then** ela mostra modelo, Android, nucleos, memoria, espaco livre, rede e veredito antes de qualquer download.
2. **Given** o menu de sessoes, **When** o usuario escolhe uma opcao, **Then** o custo em disco e o selo `validado`/`experimental` aparecem na mesma linha.
3. **Given** o menu de desenvolvimento, **When** o usuario digita `1 3`, **Then** apenas os grupos 1 e 3 ficam marcados.
4. **Given** a tela de confirmacao, **When** o usuario escolhe voltar, **Then** as escolhas anteriores sao preservadas ao reabrir os menus.

### User Story 6 - Comparar sessoes graficas antes de decidir (Priority: P2)

O usuario quer instalar mais de uma sessao, testar cada uma e depois manter apenas a escolhida.

**Why this priority**: o visual e uma decisao subjetiva que so se resolve vendo na tela.

**Independent Test**: instalar `all`, rodar `dextermux-session try mate`, abrir a porta 6081 e comparar com a sessao da porta 6080.

**Acceptance Scenarios**:

1. **Given** as tres sessoes instaladas, **When** o usuario roda `dextermux-session list`, **Then** ve quais estao instaladas e qual e a padrao.
2. **Given** `dextermux-session try cinnamon`, **When** o comando termina, **Then** o display `:2` responde em `6081` sem derrubar o `:1`.
3. **Given** uma sessao escolhida, **When** ela morre em menos de 15 segundos, **Then** o `xstartup` registra em `$TMPDIR/session.log` e cai para `xfce`.
4. **Given** `dextermux-session remove cinnamon`, **When** o usuario confirma, **Then** apenas os pacotes exclusivos do Cinnamon sao removidos.

### Edge Cases

- O Android mata os processos em segundo plano: o banner deve indicar "rode: desktop".
- O IP da Wi-Fi muda apos reboot: o banner recalcula o IP atual.
- O lock `.X1-lock` fica orfao apos queda: o `start-desktop.sh` remove antes de subir.
- A porta 8022 fica ocupada por sshd zumbi: reiniciar via `desktop`.
- O quick tunnel cai e a URL muda: o banner sempre le a ultima URL do log.
- Cliente Remmina recusa os tipos de seguranca: servidor so oferece `VncAuth`.

## Requirements

### Functional Requirements

- **FR-001**: O instalador DEVE rodar sem prompts quando nao houver TTY ou com `--yes`, aceitando configuracao por flags e variaveis de ambiente; com TTY, DEVE abrir `/dev/tty` e oferecer menus numerados sem consumir o stdin do script.
- **FR-002**: O instalador DEVE ser idempotente, preservando senha VNC e chaves SSH existentes.
- **FR-003**: O sistema DEVE instalar e configurar a sessao grafica escolhida: `cinnamon` (padrao), `xfce` (visual padrao), `mate`, `all` ou `none`.
- **FR-004**: O sistema DEVE subir o Xvnc com `VncAuth` e resolucao inicial configuravel.
- **FR-005**: O sistema DEVE servir noVNC + websockify na porta 6080.
- **FR-006**: O sistema DEVE oferecer um tunel HTTPS publico opcional via Cloudflare.
- **FR-007**: O sistema DEVE iniciar o sshd e permitir chave publica pre-carregada.
- **FR-008**: O sistema DEVE imprimir as URLs de acesso ao abrir o Termux e via comando `url`.
- **FR-009**: O sistema DEVE religar tudo com o comando `desktop`.
- **FR-010**: O sistema DEVE iniciar os servicos no boot via Termux:Boot.
- **FR-011**: O sistema NAO DEVE depender de root, proot, systemd ou pacotes quebrados.
- **FR-012**: O sistema DEVE orientar sobre bateria/IP/porta e riscos de exposicao publica.
- **FR-013**: O instalador DEVE medir recursos (modelo, Android, nucleos, memoria total/livre, espaco livre, rede) antes de instalar e emitir veredito.
- **FR-014**: Toda opcao de menu DEVE exibir custo estimado em disco e selo `validado` ou `experimental`.
- **FR-015**: O sistema DEVE permitir trocar a sessao padrao, testar uma sessao em paralelo no display `:2` e remover os pacotes exclusivos de uma sessao.
- **FR-016**: O preset `xfce` DEVE instalar apenas `xfce4` e `xfdesktop`, sem tema, dock, compositor ou apps extras, e `cinnamon` DEVE ser a sessao padrao.
- **FR-017**: O sistema DEVE registrar falha de sessao experimental em log e cair automaticamente para `xfce`.
- **FR-018**: O instalador DEVE gravar log completo da execucao em `~/dextermux-install.log`.
- **FR-019**: O sistema DEVE servir o noVNC por HTTPS com certificado autoassinado na LAN, incluindo o IP atual nas SANs, e regenerar o certificado quando o IP mudar.
- **FR-020**: O sistema DEVE permitir ligar, desligar e renovar o HTTPS local sem reinstalar, mantendo o tunel publico funcionando nos dois modos.

### Key Entities

- **Servicos remotos**: VNC (5901), noVNC (6080), sshd (8022), tunel publico, sessao de teste (5902/6081).
- **Configuracao persistida**: `~/.vnc/xstartup`, `~/.vnc/passwd`, `~/start-desktop.sh`, `~/show-access.sh`, `~/.termux/boot/start-services.sh`, `~/tunnel-url.txt`, `~/.dextermux/session`, `~/.dextermux/session.<display>`, `~/.dextermux/running.<display>`, `~/.dextermux/session-manager.sh`, `~/.dextermux/tls.sh`, `~/.dextermux/tls/{server.crt,server.key,mode,sans}`.
- **Estado de execucao**: processos `Xvnc`, `websockify`, `cloudflared`; logs em `$TMPDIR/{cf,ws}.log`, `$TMPDIR/session.log`, `~/.vnc/localhost:1.log` e `~/dextermux-install.log`.

## Success Criteria

### Measurable Outcomes

- **SC-001**: Um Termux limpo chega ao desktop funcional em menos de 15 minutos com um unico comando.
- **SC-002**: Reexecutar o instalador nao altera a senha existente e nao duplica entradas no `.bashrc`.
- **SC-003**: O banner mostra as tres URLs corretas em 100% das aberturas com servicos ativos.
- **SC-004**: A URL publica responde HTTP 200 em `vnc.html` apos o tunel registrar a conexao.
- **SC-005**: Apos queda total, `desktop` restabelece 5901 e 6080 sem intervencao manual.
- **SC-006**: A primeira tela do instalador mostra os recursos e um veredito em menos de 3 segundos, sem baixar pacotes.
- **SC-007**: `dextermux-session try` sobe a segunda sessao sem derrubar a primeira e sem reiniciar o tunel.
- **SC-008**: O preset `xfce` nao instala tema, dock, compositor ou apps extras, e a sessao padrao e `cinnamon`.
- **SC-009**: `curl -k https://<ip>:6080/vnc.html` responde 200 e a mesma porta recusa HTTP em texto claro.
- **SC-010**: Trocar o IP da LAN e rodar `dextermux-tls renew` faz o novo IP constar nas SANs do certificado.

## Assumptions

- O usuario tem Termux de F-Droid/GitHub e aceita instalar Termux:Boot.
- O celular tem Android 13+ e acesso a internet para baixar pacotes.
- O uso do tunel publico e pessoal e a rede de saida nao bloqueia Cloudflare.
- A senha do VNC Auth tem no maximo 8 caracteres (limitacao do protocolo).
- O usuario entende que a exposicao publica depende da senha do VNC.
- `cinnamon` e `xfce` foram validados no aparelho; `mate` depende de validacao do usuario.
- `gnome-shell`, `mutter` e `nautilus` nao existem no repositorio do Termux, por isso Cinnamon e MATE sao as alternativas mais proximas de um desktop completo.

## Checklist de qualidade

- [x] Nenhum marcador `[NEEDS CLARIFICATION]` restante
- [x] Requisitos testaveis e sem ambiguidade
- [x] Criterios de sucesso mensuraveis
