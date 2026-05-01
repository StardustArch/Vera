#!/usr/bin/env bash
# 01-binutils-pass1.sh - LFS 12.2 Cap. 5.4: Binutils Pass 1
# Filosofia: explícito, out-of-tree, fail-fast, logging completo.

set -euo pipefail

# ──────────────────────────────────────────────────────────────
# CONFIGURAÇÃO EXPLÍCITA
# ──────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
SOURCES_DIR="${WORKSPACE_DIR}/sources"
LOG_DIR="${WORKSPACE_DIR}/logs/build"
mkdir -p "$LOG_DIR"

BINUTILS_VER="2.43.1"
SRC_TAR="binutils-${BINUTILS_VER}.tar.xz"
SRC_DIR="binutils-${BINUTILS_VER}"
BUILD_DIR="binutils-build"

LOG_FILE="${LOG_DIR}/01-binutils-pass1.log"
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
[[ -z "${LFS_TGT:-}" ]] && { log "❌ ERRO: \$LFS_TGT não definido."; exit 1; }
[[ ! -f "${SOURCES_DIR}/${SRC_TAR}" ]] && { log "❌ ERRO: ${SRC_TAR} não encontrado."; exit 1; }

log "✅ Pré-requisitos validados. Iniciando Binutils Pass 1..."

# ──────────────────────────────────────────────────────────────
# PREPARAÇÃO (SEMPRE EXECUTA: é rápido, seguro e idempotente)
# ──────────────────────────────────────────────────────────────
cd "$WORKSPACE_DIR"
rm -rf "$SRC_DIR" "$BUILD_DIR"
log "📦 A extrair ${SRC_TAR}..."
tar xf "${SOURCES_DIR}/${SRC_TAR}"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# ──────────────────────────────────────────────────────────────
# COMPILAÇÃO (RESPEITA --dry-run)
# ──────────────────────────────────────────────────────────────
log "⚙️  Configurando (prefix=$LFS/tools, target=$LFS_TGT)..."
run ../"$SRC_DIR"/configure \
    --prefix="$LFS/tools" \
    --with-sysroot="$LFS" \
    --target="$LFS_TGT" \
    --disable-nls \
    --enable-gprofng=no \
    --disable-werror

log "🔨 A compilar (MAKEFLAGS=$MAKEFLAGS)..."
run make

log "📦 A instalar em $LFS/tools..."
run make install

# ──────────────────────────────────────────────────────────────
# LIMPEZA & VALIDAÇÃO PÓS-BUILD
# ──────────────────────────────────────────────────────────────

if ! $DRY_RUN; then
    log "🧹 A limpar ficheiros temporários..."
    rm -rf "$SRC_DIR" "$BUILD_DIR"

    if [[ -x "$LFS/tools/bin/$LFS_TGT-ld" ]]; then
        log "✅ Binutils Pass 1 instalado com sucesso."
        log "🔍 Validação: $($LFS/tools/bin/$LFS_TGT-ld --version | head -n1)"
    else
        log "❌ Falha crítica: $LFS_TGT-ld não encontrado após instalação."
        exit 1
    fi
    log "🎉 Binutils Pass 1 concluído. Próximo: 02-gcc-pass1.sh"
else
    log "✅ Dry-run concluído. Nenhum comando de build foi executado."
    log "💡 Para compilar de verdade, remove a flag --dry-run e executa novamente."
fi