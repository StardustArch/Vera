#!/usr/bin/env bash
# 03-linux-headers.sh - LFS 12.2 Cap. 5.6: Linux API Headers
# Filosofia: explícito, sanitizado, fail-fast, logging completo.

set -euo pipefail

# ──────────────────────────────────────────────────────────────
# CONFIGURAÇÃO EXPLÍCITA
# ──────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
SOURCES_DIR="${WORKSPACE_DIR}/sources"
LOG_DIR="${WORKSPACE_DIR}/logs/build"
mkdir -p "$LOG_DIR"

LINUX_VER="6.10.5"
SRC_TAR="linux-${LINUX_VER}.tar.xz"
SRC_DIR="linux-${LINUX_VER}"

LOG_FILE="${LOG_DIR}/03-linux-headers.log"
DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

log() { 
    local msg="[vera-build] $(date '+%Y-%m-%d %H:%M:%S') $*"
    echo "$msg" | tee -a "$LOG_FILE"
}

run() {
    if $DRY_RUN; then
        log "🔍 DRY-RUN: $*"
    else
        log "▶ $*"
        "$@" >> "$LOG_FILE" 2>&1 || {
            log "❌ Falha no comando: $*"
            log "📋 Verifica o log completo: $LOG_FILE"
            return 1
        }
    fi
}

# ──────────────────────────────────────────────────────────────
# VALIDAÇÕES PRÉ-BUILD
# ──────────────────────────────────────────────────────────────
[[ -z "${LFS:-}" ]] && { log "❌ ERRO: \$LFS não definido."; exit 1; }
[[ ! -f "${SOURCES_DIR}/${SRC_TAR}" ]] && { log "❌ ERRO: ${SRC_TAR} não encontrado."; exit 1; }

log "✅ Pré-requisitos validados. Instalando Linux API Headers..."

# ──────────────────────────────────────────────────────────────
# PREPARAÇÃO
# ──────────────────────────────────────────────────────────────
cd "$WORKSPACE_DIR"
rm -rf "$SRC_DIR"
log "📦 A extrair ${SRC_TAR}..."
tar xf "${SOURCES_DIR}/${SRC_TAR}"
cd "$SRC_DIR"

# ──────────────────────────────────────────────────────────────
# COMPILAÇÃO & INSTALAÇÃO (LFS 12.2 Cap. 5.6)
# ──────────────────────────────────────────────────────────────
log "🧹 Limpando árvore de fontes..."
run make mrproper

log "📦 Gerando e sanitizando headers..."
run make headers

log "🗑️ Removendo ficheiros não-header da árvore instalada..."
if ! $DRY_RUN; then
    find usr/include -type f ! -name '*.h' -delete
    log "✅ Limpeza concluída."
else
    log "🔍 DRY-RUN: find usr/include -type f ! -name '*.h' -delete"
fi

log "📦 Copiando headers sanitizados para $LFS/usr/include..."
if ! $DRY_RUN; then
    mkdir -p "$LFS/usr"
    cp -rv usr/include "$LFS/usr" >> "$LOG_FILE" 2>&1
    log "✅ Headers instalados."
else
    log "🔍 DRY-RUN: mkdir -p $LFS/usr && cp -rv usr/include $LFS/usr"
fi

# ──────────────────────────────────────────────────────────────
# VALIDAÇÃO PÓS-INSTALAÇÃO
# ──────────────────────────────────────────────────────────────
if ! $DRY_RUN; then
    rm -rf "$SRC_DIR"
    
    if [[ -f "$LFS/usr/include/linux/version.h" ]]; then
        log "✅ Linux API Headers instalados com sucesso."
        log "🔍 Validação: $(ls -1 $LFS/usr/include/ | tr '\n' ' ')"
    else
        log "❌ Falha crítica: version.h não encontrado em $LFS/usr/include/linux/"
        exit 1
    fi
    log "🎉 Linux API Headers concluído. Próximo: 04-glibc.sh"
else
    log "✅ Dry-run concluído. Nenhum comando de build foi executado."
    log "💡 Para instalar de verdade, remove a flag --dry-run."
fi