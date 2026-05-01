#!/usr/bin/env bash
# 04-musl.sh - Musl libc (substituto da glibc)
# Filosofia: explícito, minimal, zero magia.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
SOURCES_DIR="${WORKSPACE_DIR}/sources"
LOG_DIR="${WORKSPACE_DIR}/logs/build"
mkdir -p "$LOG_DIR"

LOG_FILE="${LOG_DIR}/04-musl.log"
log() { echo "[vera-build] $(date '+%Y-%m-%d %H:%M:%S') $*" | tee -a "$LOG_FILE"; }

[[ -z "${LFS:-}" || -z "${LFS_TGT:-}" ]] && { log "❌ ERRO: \$LFS ou \$LFS_TGT não definidos."; exit 1; }
[[ ! -f "${SOURCES_DIR}/musl-1.2.5.tar.gz" ]] && { log "❌ ERRO: musl source não encontrado."; exit 1; }

log "✅ Pré-requisitos validados. Compilando musl..."

cd "$WORKSPACE_DIR"
rm -rf musl-1.2.5
tar xf "${SOURCES_DIR}/musl-1.2.5.tar.gz"
cd musl-1.2.5

log "⚙️ Configurando musl..."
./configure \
    --prefix=/usr \
    --target="$LFS_TGT" \
    --disable-werror

log "🔨 Compilando musl..."
make -j$(nproc)

log "📦 Instalando em \$LFS..."
make DESTDIR="$LFS" install

# Validação mínima
if [[ -f "$LFS/usr/lib/libc.so" ]]; then
    log "✅ Musl instalado: $LFS/usr/lib/libc.so"
else
    log "❌ ERRO CRÍTICO: libc.so não encontrado"
    exit 1
fi

rm -rf "$WORKSPACE_DIR/musl-1.2.5"
log "🎉 Musl concluído. Próximo: 05-gcc-pass2.sh"