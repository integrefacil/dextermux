# Quickstart: dextermux v6

## 1. Instalar

```bash
curl -fsSL https://integrefacil.github.io/dextermux/setup.sh -o setup.sh
bash setup.sh
```

O script pergunta ambiente (Cinnamon/XFCE), proot, tunel e senha; mostra um resumo e instala.

Automatico:

```bash
bash setup.sh --yes --desktop=cinnamon --no-proot --no-tunnel
```

Conferir o plano:

```bash
bash setup.sh --dry-run --desktop=xfce --proot
```

## 2. Conectar

O bloco de acesso e impresso no fim:

```text
=== Acesso remoto ===
Desktop:      cinnamon
SSH:          ssh -p 8022 <usuario>@<ip>
VNC local:    vnc://<ip>:5901
noVNC local:  https://<ip>:6080/vnc.html
Publico:      desligado (rode: tunnel on)
Senha:        a definida na instalacao
==========
```

- Remmina: VNC em `<ip>:5901` com a senha definida.
- Navegador: HTTPS na 6080; aceite o certificado.
- Externo: `tunnel on` e use a URL publica.

## 3. Trocar ambiente

```bash
session                 # mostra o atual e os instalados
session xfce            # instala se faltar e reinicia
session cinnamon
```

Nada e apagado.

## 4. Tunel

```bash
tunnel on
tunnel status
tunnel url
tunnel off
```

## 5. Senha

```bash
password
```

Pede a nova senha (ate 8), aplica no VNC e tenta no SSH. Se o `passwd` pedir, digite a mesma.

## 6. Proot (opcional)

```bash
bash setup.sh --proot
ubuntu
gui xterm
```

Sem dev, sem snap. AppImage arm64: `gui /caminho/app.AppImage --appimage-extract-and-run`.

## 7. Reinstalar

```bash
bash setup.sh --reset=artifacts   # B1: mantem projetos, chaves e .ssh
bash setup.sh --reset=home        # B2: apaga todo o HOME (2 confirmacoes)
```

## 8. Certificado

```bash
tls show
tls renew
tls disable
tls enable
```

## 9. Processos

```bash
status
```

- ok ate 22; atencao 23-26; critico 27+.
- Navegador 10-15 processos; Android mata acima de 32.

## 10. Troubleshooting

| Sintoma | Causa | Acao |
|---------|-------|------|
| Banner diz "parado" | processos mortos | `desktop` |
| Certificado invalido | certificado autoassinado | aceite ou `tls show` |
| IP mudou | SANs antigas | `tls renew` |
| Sessao nao troca | DE ausente | `session` mostra; rode o setup |
| `gui` falha | proot ausente | `bash setup.sh --proot` |
| AppImage nao abre | FUSE/arch | use `--appimage-extract-and-run` e arm64 |
| Snap/Flatpak | systemd ausente | nao suportado |

## 11. Referencias

- `spec.md`, `plan.md`, `research.md`, `tasks.md`
- `contracts/cli-contract.md`
- `specs/constitution.md`
