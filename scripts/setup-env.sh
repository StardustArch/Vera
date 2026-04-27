#!/usr/bin/env bash
# setup-env.sh - Inicializa ambiente de build para Vëra
# Filosofia: Explícito, reproduzível, falha cedo, zero mágica.

set -euo pipefail

# ──────────────────────────────────────────────────────────────
# CONFIGURAÇÃO EXPLÍCITA (pode ser sobrescrita por variáveis de ambiente)
# ──────────────────────────────────────────────────────────────
VERA_WORKSPACE="${VERA_WORKSPACE:-$HOME/vera-workspace}"
LFS="${LFS:-/mnt/lfs}"  # Padrão LFS Chapter 2.2

# ──────────────────────────────────────────────────────────────
# UTILS
# ──────────────────────────────────────────────────────────────
log()   { echo "[vera-setup] $*"; }
error() { echo "[vera-setup] ERRO: $*" >&2; exit 1; }

# ──────────────────────────────────────────────────────────────
# VERIFICAÇÕES
# ──────────────────────────────────────────────────────────────
check_prereqs() {
    [[ $EUID -eq 0 ]] && error "Não execute como root. Use um usuário comum (LFS Ch. 2.2)."
    command -v bash >/dev/null || error "bash não encontrado no PATH."
    command -v df >/dev/null   || error "df não encontrado. Impossível validar espaço."

    mkdir -p "$VERA_WORKSPACE" 

    log "Verificando espaço em disco..."
    local avail_mb
    avail_mb=$(df -m "$VERA_WORKSPACE" 2>/dev/null | awk 'NR==2 {print $4}')
    if [[ -z "$avail_mb" ]] || (( avail_mb < 10240 )); then
        error "Espaço insuficiente em $VERA_WORKSPACE. Mínimo: 10GB livres."
    fi
}

# ──────────────────────────────────────────────────────────────
# CRIAÇÃO DE ESTRUTURA
# ──────────────────────────────────────────────────────────────
create_structure() {
    log "Criando estrutura de workspace em $VERA_WORKSPACE..."
    mkdir -p "$VERA_WORKSPACE"/{sources,patches,scripts,docs,logs,ports}
    log "Estrutura criada."
}

# ──────────────────────────────────────────────────────────────
# DOCUMENTAÇÃO BASE
# ──────────────────────────────────────────────────────────────
init_docs() {
    log "Gerando documentação inicial..."
    cat > "$VERA_WORKSPACE/docs/NOTES.md" << 'EOF'
# Notas de Desenvolvimento - Vëra
## Decisões de Arquitetura
- [ ] Init system: OpenRC vs runit vs custom?
- [ ] FHS: seguir padrão ou desviar intencionalmente?
- [ ] `$LFS` mount point configurado e persistente?

## LFS - Capítulo por Capítulo
### Cap. 1-2
- [ ] Host system validado (gcc, glibc, bash, coreutils, etc.)
EOF

    cat > "$VERA_WORKSPACE/README.md" << 'EOF'
# Vëra Build Environment
Ambiente de construção explícito e reproduzível.
Não execute como root. Mantenha `$LFS` separado do workspace.
EOF
}

# ──────────────────────────────────────────────────────────────
# EXECUÇÃO PRINCIPAL
# ──────────────────────────────────────────────────────────────
main() {
    check_prereqs
    create_structure
    init_docs

    log "✅ Ambiente inicializado em $VERA_WORKSPACE"
    log "📌 Próximo passo (LFS Ch. 2.2):"
    log "   export LFS=$VERA_WORKSPACE/lfs"
    log "   sudo mkdir -p \$LFS && sudo chown \$USER:\$USER \$LFS"
    log "   mount -v -t ext4 /dev/<partição> \$LFS  # ou tmpfs para testes"
}

main