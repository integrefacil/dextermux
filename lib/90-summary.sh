# shellcheck shell=bash
# 90-summary - fluxo, instalacao, reparo e resumo

print_access() {
    if [ -x "$H/show-access.sh" ]; then
        "$H/show-access.sh"
    fi
}

print_summary() {
    local count verdict
    count=$(process_count)
    verdict=$(process_verdict "$count")

    print_access

    section "Resumo"
    row "Desktop" "$(current_desktop)"
    row "Processos" "$count / 32 ($verdict)"
    row "Log" "$LOG"
    if proot_installed; then
        row "Ubuntu" "instalado (ubuntu / gui)"
    fi

    section "Comandos"
    printf '  %-14s %s\n' "desktop" "sobe/religa os servicos"
    printf '  %-14s %s\n' "url" "bloco de acesso"
    printf '  %-14s %s\n' "status" "processos, TLS, tunel e desktop"
    printf '  %-14s %s\n' "session" "mostra ou troca cinnamon/xfce"
    printf '  %-14s %s\n' "tunnel" "on, off, status ou url"
    printf '  %-14s %s\n' "password" "troca a senha de VNC/noVNC/SSH"
    printf '  %-14s %s\n' "tls" "show, renew, enable ou disable"
    if proot_installed; then
        printf '  %-14s %s\n' "ubuntu" "shell no Ubuntu"
        printf '  %-14s %s\n' "gui APP" "app do Ubuntu no desktop"
    fi

    section "Pendencias manuais"
    printf '  1. Instalar o app Termux:Boot e abrir uma vez.\n'
    printf '  2. Samsung: Aplicativos > Termux > Bateria > Sem restricoes.\n'
    printf '  3. Bateria > Apps que nunca dormem > Termux.\n'
    printf '  4. Reservar o IP do celular no roteador.\n'
    if [ "$(cat "$H/.dextermux/tls/mode" 2>/dev/null || echo 0)" = "1" ]; then
        printf '  5. Aceitar o certificado autoassinado no primeiro acesso HTTPS.\n'
    fi
    printf '  6. Um navegador usa 10-15 processos; o Android mata acima de 32.\n'
    rule
}

print_dry_run() {
    section "Plano (dry-run)"
    row "Desktop" "$DESKTOP ($(desktop_size "$DESKTOP") MB)"
    row "Proot" "$([ "$PROOT_WANTED" = "1" ] && echo sim || echo nao)"
    row "Tunel" "$([ "$TUNNEL_MODE" = "1" ] && echo sim || echo nao)"
    row "HTTPS LAN" "$([ "$TLS_MODE" = "1" ] && echo sim || echo nao)"
    row "Geometria" "$GEOMETRY"
    row "Espaco livre" "$DISK_FREE_MB MB"
    printf '\n  Pacotes base: %s\n' "$PKGS_BASE"
    printf '  Pacotes desktop: %s\n' "$(desktop_packages "$DESKTOP")"
    printf '\n  Arquivos gerados: ~/.dextermux/*, ~/.vnc/*, ~/start-desktop.sh,\n'
    printf '  ~/show-access.sh, ~/.termux/boot/start-services.sh, ~/.bashrc (banner)\n\n'
}

run_install() {
    TOTAL_STEPS=19
    mkdir -p "$H/.dextermux"
    : >"$LOG"
    printf 'dextermux %s - %s\n' "$DEXTERMUX_VERSION" "$(date)" >>"$LOG"

    step "Parando servicos"
    pkill -f "[X]vnc :1" 2>/dev/null || true
    pkill -f "[w]ebsockify" 2>/dev/null || true
    pkill -f "[c]loudflared tunnel" 2>/dev/null || true
    sleep 1
    rm -f "$TMPDIR/.X1-lock" "$TMPDIR/.X11-unix/X1" "$H/.vnc/"*:1.pid 2>/dev/null || true

    cleanup_legacy
    update_indexes
    install_x11_repo
    upgrade_packages
    audit_dpkg

    step "Pacotes base"
    # shellcheck disable=SC2086
    install_pkgs $PKGS_BASE

    step "Desktop $DESKTOP"
    # shellcheck disable=SC2086,SC2046
    install_pkgs $(desktop_packages "$DESKTOP")

    install_websockify

    step "noVNC"
    write_novnc

    step "Sessao"
    write_session_mode
    write_xstartup
    write_xfce_session_config
    write_session_command

    step "Acesso remoto"
    write_start_desktop
    write_show_access
    write_tls_helper
    write_tunnel_command

    step "Senha compartilhada"
    write_password_command
    write_shared_password

    step "SSH"
    write_ssh_key

    step "Proot"
    if [ "$PROOT_WANTED" = "1" ]; then
        proot_setup
        write_ubuntu_helpers
    else
        info "proot desativado"
    fi

    step "Tunel"
    write_tunnel_mode

    step "Banner do shell"
    write_bashrc_block

    step "Autostart no boot"
    write_boot_script

    step "Certificado TLS"
    if [ "$TLS_MODE" = "1" ]; then
        "$H/.dextermux/tls.sh" ensure || warn "falha ao gerar o certificado"
    else
        info "HTTPS na LAN desligado"
    fi

    step "Subindo servicos"
    "$H/start-desktop.sh" 2>&1 | tee -a "$LOG" || warn "servicos iniciaram com avisos"
    if [ "$DESKTOP" = "xfce" ]; then
        set_xfce_defaults
    fi

    step "Limpando cache"
    pkg clean >/dev/null 2>&1 || true
    ok "cache do pkg limpo"
}

run_repair() {
    TOTAL_STEPS=8
    : >"$LOG"
    printf 'dextermux %s - reparo %s\n' "$DEXTERMUX_VERSION" "$(date)" >>"$LOG"

    step "Parando servicos"
    pkill -f "[X]vnc :1" 2>/dev/null || true
    pkill -f "[w]ebsockify" 2>/dev/null || true
    pkill -f "[c]loudflared tunnel" 2>/dev/null || true
    sleep 1
    rm -f "$TMPDIR/.X1-lock" "$TMPDIR/.X11-unix/X1" "$H/.vnc/"*:1.pid 2>/dev/null || true

    cleanup_legacy

    step "Sessao"
    write_session_mode
    write_xstartup
    write_xfce_session_config
    write_session_command

    step "Acesso remoto"
    write_start_desktop
    write_show_access
    write_tls_helper
    write_tunnel_command

    step "Banner do shell"
    write_bashrc_block

    step "Autostart no boot"
    write_boot_script

    step "Certificado TLS"
    if [ "$TLS_MODE" = "1" ]; then
        "$H/.dextermux/tls.sh" ensure || warn "falha ao gerar o certificado"
    fi

    step "Reiniciando servicos"
    "$H/start-desktop.sh" 2>&1 | tee -a "$LOG" || warn "servicos iniciaram com avisos"
    if [ "$DESKTOP" = "xfce" ]; then
        set_xfce_defaults
    fi

    step "Verificacao"
    local n
    n=$(process_count)
    row "Processos" "$n ($(process_verdict "$n"))"
}

run_proot_only() {
    TOTAL_STEPS=2
    : >"$LOG"
    step "Proot"
    proot_setup
    step "Comandos"
    write_ubuntu_helpers
    ok "Ubuntu pronto; use: ubuntu ou gui APP"
}

ask_desktop() {
    local choice
    choice=$(menu "Ambiente grafico" \
        "Cinnamon (~1700 MB, padrao)" \
        "XFCE (~690 MB, leve)")
    case "$choice" in
        2) DESKTOP="xfce" ;;
        *) DESKTOP="cinnamon" ;;
    esac
}

ask_proot() {
    if confirm "Instalar Ubuntu para apps glibc?" n; then
        PROOT_WANTED=1
    else
        PROOT_WANTED=0
    fi
}

ask_tunnel() {
    if confirm "Ativar tunel publico Cloudflare?" n; then
        TUNNEL_MODE=1
    else
        TUNNEL_MODE=0
    fi
}

ask_password() {
    local p
    if [ -n "$SHARED_PASS" ]; then return 0; fi
    p=$(ask_secret "Senha de acesso (ate 8, Enter gera):")
    SHARED_PASS="$p"
}

show_install_plan() {
    section "Confirmar instalacao"
    row "Desktop" "$DESKTOP (~$(desktop_size "$DESKTOP") MB)"
    row "Proot" "$([ "$PROOT_WANTED" = "1" ] && echo sim || echo nao)"
    row "Tunel" "$([ "$TUNNEL_MODE" = "1" ] && echo sim || echo nao)"
    row "Senha" "$([ -n "$SHARED_PASS" ] && echo definida || echo "gerar aleatoria")"
    row "Espaco livre" "$DISK_FREE_MB MB"
    confirm "Confirmar?" y
}

flow_fresh() {
    ask_desktop
    ask_proot
    ask_tunnel
    ask_password
    if show_install_plan; then
        run_install
        print_summary
    else
        info "cancelado"
    fi
}

flow_switch() {
    ask_desktop
    if ! desktop_installed "$DESKTOP"; then
        info "instalando o desktop escolhido"
        # shellcheck disable=SC2086,SC2046
        install_pkgs $(desktop_packages "$DESKTOP")
    fi
    write_session_mode
    write_xstartup
    write_xfce_session_config
    pkill -f "[X]vnc :1" 2>/dev/null || true
    sleep 1
    rm -f "$TMPDIR/.X1-lock" "$TMPDIR/.X11-unix/X1" "$H/.vnc/"*:1.pid 2>/dev/null || true
    "$H/start-desktop.sh" >/dev/null 2>&1 || true
    if [ "$DESKTOP" = "xfce" ]; then
        set_xfce_defaults
    fi
    print_summary
}

flow_reinstall() {
    local b1=0 b2=0
    if confirm "Reinstalar apagando os artefatos do dextermux?" y; then b1=1; fi
    if [ "$b1" = "0" ]; then
        info "nada sera apagado"
        return 0
    fi
    if confirm "Apagar tambem TODO o \$HOME (projetos, chaves, configs)?" n; then
        if confirm "Tem certeza? Essa acao e irreversivel." n; then
            b2=1
        fi
    fi

    ask_desktop
    ask_proot
    ask_tunnel
    ask_password
    if ! show_install_plan; then
        info "cancelado"
        return 0
    fi

    if [ "$b2" = "1" ]; then
        export DESKTOP PROOT="$PROOT_WANTED" TUNNEL="$TUNNEL_MODE"
        export VNC_PASS="$SHARED_PASS" SSH_PUBKEY GEOMETRY DEXTERMUX_PREFILLED=1
        reset_home "$@"
        return 0
    fi

    reset_artifacts
    run_install
    print_summary
}

flow_interactive() {
    if [ "$MODE" = "repair" ]; then
        run_repair
        print_summary
        return 0
    fi
    if [ "$MODE" = "proot" ]; then
        run_proot_only
        print_summary
        return 0
    fi

    if [ "${DEXTERMUX_PREFILLED:-0}" = "1" ]; then
        run_install
        print_summary
        return 0
    fi

    if [ "$EXISTING" = "sim" ]; then
        local choice
        choice=$(menu "Instalacao detectada" \
            "Trocar ambiente (sem apagar)" \
            "Reparar" \
            "Reinstalar do zero" \
            "Sair")
        case "$choice" in
            1) DESKTOP=$(current_desktop); flow_switch ;;
            2) run_repair; print_summary ;;
            3) flow_reinstall "$@" ;;
            *) exit 0 ;;
        esac
        return 0
    fi

    flow_fresh
}

main() {
    parse_args "$@"
    open_tty

    is_termux || die "rode este script dentro do Termux"

    detect_resources
    print_resources

    if [ "$DRY_RUN" = "1" ]; then
        print_dry_run
        exit 0
    fi

    if [ "$RESET_SCOPE" = "home" ] && [ "${DEXTERMUX_RESET_DONE:-0}" != "1" ]; then
        if [ "$INTERACTIVE" != "1" ]; then
            die "--reset=home exige confirmacao interativa"
        fi
        if ! confirm "Apagar TODO o \$HOME e o proot?" n; then
            info "cancelado"
            exit 0
        fi
        if ! confirm "Tem certeza? Irreversivel." n; then
            info "cancelado"
            exit 0
        fi
        reset_home "$@"
        exit 0
    fi

    if [ "$RESET_SCOPE" = "artifacts" ] && [ "$INTERACTIVE" = "1" ]; then
        if confirm "Apagar os artefatos do dextermux e o proot?" y; then
            reset_artifacts
        else
            info "cancelado"
            exit 0
        fi
        if [ "$MODE" = "install" ]; then
            flow_fresh
        fi
        exit 0
    fi

    if [ "$INTERACTIVE" = "1" ]; then
        flow_interactive "$@"
    else
        if [ "$MODE" = "repair" ]; then
            run_repair
        elif [ "$MODE" = "proot" ]; then
            run_proot_only
        else
            run_install
        fi
        print_summary
    fi
}
