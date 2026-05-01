#!/usr/bin/env bash
# 02-gcc-pass1.sh - LFS 12.2 Cap. 5.5: GCC Pass 1 (Bootstrap C/C++)
# Filosofia: explícito, out-of-tree, fail-fast, logging completo, zero magia.

set -euo pipefail

# ──────────────────────────────────────────────────────────────
# CONFIGURAÇÃO EXPLÍCITA
# ──────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
SOURCES_DIR="${WORKSPACE_DIR}/sources"
LOG_DIR="${WORKSPACE_DIR}/logs/build"
mkdir -p "$LOG_DIR"

GCC_VER="14.2.0"
SRC_TAR="gcc-${GCC_VER}.tar.xz"
SRC_DIR="gcc-${GCC_VER}"
BUILD_DIR="gcc-build"

LOG_FILE="${LOG_DIR}/02-gcc-pass1.log"
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
[[ ! -x "$LFS/tools/bin/$LFS_TGT-ld" ]] && { log "❌ ERRO: Binutils Pass 1 não encontrado. Executa 01-binutils-pass1.sh primeiro."; exit 1; }

log "✅ Pré-requisitos validados. Iniciando GCC Pass 1..."

# ──────────────────────────────────────────────────────────────
# PREPARAÇÃO (IDEMPOTENTE)
# ──────────────────────────────────────────────────────────────
cd "$WORKSPACE_DIR"
rm -rf "$SRC_DIR" "$BUILD_DIR"

log "📦 A extrair ${SRC_TAR} (extração completa exigida pelo config.status)..."
tar xf "${SOURCES_DIR}/${SRC_TAR}"

cd "$SRC_DIR"

# Preparar dependências internas do GCC a partir de sources/ pré-baixados
# Nomes exactos que o configure do GCC espera: gmp, mpfr, mpc (sem versão no nome da pasta)
if ! $DRY_RUN; then
    log "📦 A extrair dependências internas do GCC (gmp, mpfr, mpc)..."
    
    # GMP
    if [[ -f "${SOURCES_DIR}/gmp-6.3.0.tar.xz" ]]; then
        tar xf "${SOURCES_DIR}/gmp-6.3.0.tar.xz"
        mv gmp-6.3.0 gmp
        log "✅ GMP extraído"
    else
        log "❌ ERRO: gmp-6.3.0.tar.xz não encontrado em ${SOURCES_DIR}"
        exit 1
    fi
    
    # MPFR
    if [[ -f "${SOURCES_DIR}/mpfr-4.2.1.tar.xz" ]]; then
        tar xf "${SOURCES_DIR}/mpfr-4.2.1.tar.xz"
        mv mpfr-4.2.1 mpfr
        log "✅ MPFR extraído"
    else
        log "❌ ERRO: mpfr-4.2.1.tar.xz não encontrado em ${SOURCES_DIR}"
        exit 1
    fi
    
    # MPC
    if [[ -f "${SOURCES_DIR}/mpc-1.3.1.tar.gz" ]]; then
        tar xf "${SOURCES_DIR}/mpc-1.3.1.tar.gz"
        mv mpc-1.3.1 mpc
        log "✅ MPC extraído"
    else
        log "❌ ERRO: mpc-1.3.1.tar.gz não encontrado em ${SOURCES_DIR}"
        exit 1
    fi
    
    log "✅ Dependências internas prontas (offline, versões controladas)."
fi

cd ..
mkdir "$BUILD_DIR"
cd "$BUILD_DIR"

# ──────────────────────────────────────────────────────────────
# COMPILAÇÃO (LFS 12.2 Cap. 5.5)
# ──────────────────────────────────────────────────────────────
log "⚙️ Configurando GCC Pass 1 (bootstrap C/C++)..."
run ../"$SRC_DIR"/configure \
    --target="$LFS_TGT" \
    --prefix="$LFS/tools" \
    --with-sysroot="$LFS" \
    --with-newlib \
    --without-headers \
    --enable-default-pie \
    --enable-default-ssp \
    --disable-nls \
    --disable-shared \
    --disable-multilib \
    --disable-threads \
    --disable-libatomic \
    --disable-libgomp \
    --disable-libquadmath \
    --disable-libssp \
    --disable-libvtv \
    --disable-libstdcxx \
    --enable-languages=c,c++

log "🔨 A compilar GCC Pass 1 (MAKEFLAGS=$MAKEFLAGS)..."
run make

log "📦 A instalar em $LFS/tools..."
run make install

# Symlink obrigatório: LFS e muitos pacotes esperam `cc`
log "🔗 A criar symlink cc -> gcc..."
if ! $DRY_RUN; then
    ln -sv gcc "$LFS/tools/bin/cc" >> "$LOG_FILE" 2>&1
fi

# ──────────────────────────────────────────────────────────────
# LIMPEZA & VALIDAÇÃO PÓS-BUILD
# ──────────────────────────────────────────────────────────────
if ! $DRY_RUN; then
    log "🧹 A limpar ficheiros temporários..."
    rm -rf "$SRC_DIR" "$BUILD_DIR"

    if [[ -x "$LFS/tools/bin/$LFS_TGT-gcc" ]]; then
        log "✅ GCC Pass 1 instalado com sucesso."
        log "🔍 Validação: $($LFS/tools/bin/$LFS_TGT-gcc --version | head -n1)"
    else
        log "❌ Falha crítica: $LFS_TGT-gcc não encontrado após instalação."
        exit 1
    fi
    log "🎉 GCC Pass 1 concluído. Próximo: 03-linux-headers.sh"
else
    log "✅ Dry-run concluído. Nenhum comando de build foi executado."
    log "💡 Para compilar de verdade, remove a flag --dry-run."
fi