#!/usr/bin/env bash
# 06.4-bootstrap-readline.sh - Compila readline para $LFS (CORRIGIDO)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
SOURCES_DIR="${WORKSPACE_DIR}/sources"
LOG_DIR="${WORKSPACE_DIR}/logs/build"
mkdir -p "$LOG_DIR"

LOG_FILE="${LOG_DIR}/06.4-bootstrap-readline.log"
log() { echo "[vera-build] $(date '+%Y-%m-%d %H:%M:%S') $*" | tee -a "$LOG_FILE"; }

[[ -z "${LFS:-}" || -z "${LFS_TGT:-}" ]] && { log "❌ ERRO: \$LFS ou \$LFS_TGT não definidos."; exit 1; }
[[ ! -f "$LFS/usr/lib/libncursesw.so.6" ]] && { log "❌ ERRO: ncurses não encontrado."; exit 1; }
[[ ! -f "${SOURCES_DIR}/readline-8.2.13.tar.gz" ]] && { log "❌ ERRO: readline source não encontrado."; exit 1; }

log "✅ Compilando readline para \$LFS..."
cd "$WORKSPACE_DIR"
rm -rf readline-8.2.13 readline-build
tar xf "${SOURCES_DIR}/readline-8.2.13.tar.gz"
cd readline-8.2.13

log "⚙️ Configurando readline (sem --with-curses explícito)..."
./configure \
    --prefix=/usr \
    --host="${LFS_TGT}" \
    --build="$(bash support/config.sub "${LFS_TGT}")" \
    --disable-nls \
    --with-curses \
    CC="${LFS_TGT}-gcc" \
    AR="${LFS_TGT}-ar" \
    RANLIB="${LFS_TGT}-ranlib" \
    CPPFLAGS="-I${LFS}/usr/include" \
    LDFLAGS="-L${LFS}/usr/lib" \
    LIBS="-lncursesw" 2>&1 | tee -a "$LOG_FILE"

log "🔨 Compilando..."
make -j"$(nproc)" 2>&1 | tee -a "$LOG_FILE"

log "📦 Instalando em \$LFS..."
make DESTDIR="$LFS" install 2>&1 | tee -a "$LOG_FILE"

# Validação
if [[ -f "$LFS/usr/lib/libreadline.so.8" ]]; then
    log "✅ Readline instalado: $LFS/usr/lib/libreadline.so.8"
else
    log "❌ Falha: libreadline.so.8 não encontrado"
    exit 1
fi

rm -rf "$WORKSPACE_DIR/readline-8.2.13"
log "🎉 Readline bootstrap concluído."