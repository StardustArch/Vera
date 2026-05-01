#!/usr/bin/env bash
# 05-gcc-pass2.sh - LFS 12.2 Cap. 5.8: GCC Pass 2 (Completo com libstdc++)
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

GCC_VER="14.2.0"
SRC_TAR="gcc-${GCC_VER}.tar.xz"
SRC_DIR="gcc-${GCC_VER}"
BUILD_DIR="gcc-build-pass2"

LOG_FILE="${LOG_DIR}/05-gcc-pass2.log"
DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

log() { echo "[vera-build] $(date '+%Y-%m-%d %H:%M:%S') $*" | tee -a "$LOG_FILE"; }
run() {
    if $DRY_RUN; then log "🔍 DRY-RUN: $*"; else
        log "▶ $*"; "$@" >> "$LOG_FILE" 2>&1 || { log "❌ Falha: $*"; exit 1; }
    fi
}

# ──────────────────────────────────────────────────────────────
# VALIDAÇÕES PRÉ-BUILD
# ──────────────────────────────────────────────────────────────
[[ -z "${LFS:-}" || -z "${LFS_TGT:-}" ]] && { log "❌ ERRO: \$LFS ou \$LFS_TGT não definidos."; exit 1; }
[[ ! -f "${SOURCES_DIR}/${SRC_TAR}" ]] && { log "❌ ERRO: ${SRC_TAR} não encontrado."; exit 1; }
[[ ! -x "$LFS/tools/bin/$LFS_TGT-gcc" ]] && { log "❌ ERRO: GCC Pass 1 não encontrado."; exit 1; }
[[ ! -f "$LFS/usr/lib/libc.a" ]] && { log "❌ ERRO: Glibc não encontrada. Executa 04-glibc.sh primeiro."; exit 1; }

log "✅ Pré-requisitos validados. Iniciando GCC Pass 2 (completo)..."

# ──────────────────────────────────────────────────────────────
# PREPARAÇÃO (IDEMPOTENTE + --no-clean)
# ──────────────────────────────────────────────────────────────
cd "$WORKSPACE_DIR"

# Flag para preservar fontes e build (debug/resume)
NO_CLEAN=false
[[ "${1:-}" == "--no-clean" ]] && NO_CLEAN=true

# 1. Extrair GCC APENAS se a pasta não existir
if [[ ! -d "$SRC_DIR" ]]; then
    log "📦 A extrair ${SRC_TAR}..."
    tar xf "${SOURCES_DIR}/${SRC_TAR}"
    log "✅ ${SRC_DIR} extraído."
else
    log "✅ ${SRC_DIR} já existe. A reutilizar."
fi

# 2. Entrar na árvore do GCC para dependências internas
cd "$SRC_DIR"
if ! $DRY_RUN; then
    log "📦 A validar/criar dependências internas (gmp, mpfr, mpc)..."
    [[ -d "gmp" ]]  || { tar xf "${SOURCES_DIR}/gmp-6.3.0.tar.xz"  && mv gmp-6.3.0 gmp  && log "✅ GMP pronto"; }
    [[ -d "mpfr" ]] || { tar xf "${SOURCES_DIR}/mpfr-4.2.1.tar.xz" && mv mpfr-4.2.1 mpfr && log "✅ MPFR pronto"; }
    [[ -d "mpc" ]]  || { tar xf "${SOURCES_DIR}/mpc-1.3.1.tar.gz"  && mv mpc-1.3.1 mpc  && log "✅ MPC pronto"; }
    log "✅ Dependências internas validadas."
fi

# 3. Voltar ao workspace e preparar build dir
cd "$WORKSPACE_DIR"
if ! $NO_CLEAN; then
    log "🧹 A limpar build directory..."
    rm -rf "$BUILD_DIR"
fi
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"
# ✅ Agora estamos em $BUILD_DIR, prontos para: ../"$SRC_DIR"/configure

# ──────────────────────────────────────────────────────────────
# COMPILAÇÃO (LFS 12.2 Cap. 5.8)
# ──────────────────────────────────────────────────────────────
log "⚙️ Configurando GCC Pass 2 (completo: C, C++, libstdc++)..."

run ../"$SRC_DIR"/configure \
    --target="$LFS_TGT" \
    --prefix="$LFS/tools" \
    --with-sysroot="$LFS" \
    --enable-default-pie \
    --enable-default-ssp \
    --disable-nls \
    --enable-languages=c,c++ \
    --enable-shared \
    --enable-threads=posix \
    --enable-__cxa_atexit \
    --enable-clocale=gnu \
    --disable-libstdcxx-pch \
    --disable-multilib \
    --disable-bootstrap \
    --disable-libmpx \
    --with-system-zlib

log "🔨 A compilar GCC Pass 2 (MAKEFLAGS=$MAKEFLAGS)..."
run make

log "📦 A instalar em $LFS/tools..."
run make install

# Symlink cc (já existe do Pass 1, mas garantimos)
log "🔗 A garantir symlink cc -> gcc..."
if ! $DRY_RUN; then
    ln -sfv gcc "$LFS/tools/bin/cc" >> "$LOG_FILE" 2>&1
fi


# ──────────────────────────────────────────────────────────────
# VALIDAÇÃO PÓS-BUILD (Heredoc + readelf)
# ──────────────────────────────────────────────────────────────
if ! $DRY_RUN; then
    log "🧹 Limpando ficheiros temporários..."
    rm -rf "$SRC_DIR" "$BUILD_DIR"

    log "🔍 Validando compilador C++..."
    cat > dummy.cpp << 'EOCPP'
#include <iostream>
int main() { std::cout << "Vera GCC OK" << std::endl; return 0; }
EOCPP
    $LFS_TGT-g++ -o dummy dummy.cpp 2>> "$LOG_FILE"

    if [[ -x "dummy" ]]; then
        INTERP=$(readelf -l dummy 2>/dev/null | grep interpreter | awk '{print $4}' | tr -d '[]')
        if [[ "$INTERP" == *"/lib/ld-musl-x86_64.so.1" ]]; then
            log "✅ GCC C++ funcional: binário linkado contra musl"
        else
            log "⚠️  GCC C++ compilado (interpreter: $INTERP)"
        fi
    else
        log "❌ Falha crítica: binário dummy não foi gerado"
        exit 1
    fi
    rm -f dummy.cpp dummy

    log "🎉 GCC Pass 2 concluído. Toolchain temporária completa!"
    log "📋 Resumo: $($LFS_TGT-gcc --version | head -n1)"
    log "🚀 Próximo: 06-finalize-toolchain.sh"
else
    log "✅ Dry-run concluído. Nenhum comando de build foi executado."
    log "💡 Para compilar de verdade, remove a flag --dry-run."
fi