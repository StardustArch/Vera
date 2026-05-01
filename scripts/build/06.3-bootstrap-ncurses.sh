#!/usr/bin/env bash
# 06.3-bootstrap-ncurses.sh - Compila ncurses para $LFS (base para readline/bash)
# Filosofia: explícito, fail-fast, logging completo.
# CORRECÇÃO: removido bug $DRY_RUN indefinido, symlinks sempre criados.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
SOURCES_DIR="${WORKSPACE_DIR}/sources"
LOG_DIR="${WORKSPACE_DIR}/logs/build"
mkdir -p "$LOG_DIR"

LOG_FILE="${LOG_DIR}/06.3-bootstrap-ncurses.log"
log() { echo "[vera-build] $(date '+%Y-%m-%d %H:%M:%S') $*" | tee -a "$LOG_FILE"; }

[[ -z "${LFS:-}" || -z "${LFS_TGT:-}" ]] && { log "❌ ERRO: \$LFS ou \$LFS_TGT não definidos."; exit 1; }
[[ ! -f "${SOURCES_DIR}/ncurses-6.5.tar.gz" ]] && { log "❌ ERRO: ncurses source não encontrado."; exit 1; }
[[ ! -x "$LFS/tools/bin/${LFS_TGT}-gcc" ]] && { log "❌ ERRO: Toolchain não encontrada. Executa 01→02→03→04→05→06 primeiro."; exit 1; }

log "✅ Compilando ncurses para \$LFS..."
cd "$WORKSPACE_DIR"
rm -rf ncurses-6.5
tar xf "${SOURCES_DIR}/ncurses-6.5.tar.gz"
cd ncurses-6.5

log "⚙️  Configurando ncurses (wide-char, sem docs)..."
./configure \
    --prefix=/usr \
    --host="${LFS_TGT}" \
    --build="$(./config.guess)" \
    --with-manpage-format=normal \
    --with-shared \
    --without-debug \
    --without-normal \
    --with-cxx-shared \
    --without-ada \
    --disable-stripping \
    --enable-widec \
    CC="${LFS_TGT}-gcc" \
    CXX="${LFS_TGT}-g++" \
    AR="${LFS_TGT}-ar" \
    RANLIB="${LFS_TGT}-ranlib" 2>&1 | tee -a "$LOG_FILE"

log "🔨 Compilando ncurses..."
make -j"$(nproc)" 2>&1 | tee -a "$LOG_FILE"

log "📦 Instalando em \$LFS..."
# TIC_PATH aponta para o tic do host — necessário para gerar terminfo
make DESTDIR="$LFS" TIC_PATH="$(which tic)" install 2>&1 | tee -a "$LOG_FILE"

# No final do script 06.3-bootstrap-ncurses.sh, substitui a secção de symlinks por:

log "🔗 Criando symlinks de compatibilidade..."
if ! cd "$LFS/usr/lib" 2>/dev/null; then
    log "❌ Falha ao entrar em $LFS/usr/lib"
    exit 1
fi

for link in libncursesw.so libncurses.so libcurses.so; do
    ln -sfv libncursesw.so.6 "$link"
    # Validar que o symlink resolve para um ficheiro real
    if [[ -L "$link" ]] && [[ -e "$(readlink -f "$link")" ]]; then
        log "✅ $link válido"
    else
        log "❌ $link inválido ou aponta para alvo inexistente"
        exit 1
    fi
done

# Validação: devem ser symlinks, NÃO ficheiros de texto
file libncurses.so
# Deve mostrar: symbolic link to libncursesw.so
# Se mostrar: ASCII text → APAGA E REFAZ O SYMLINK

# Validação
if [[ -f "$LFS/usr/lib/libncursesw.so.6" ]]; then
    log "✅ Ncurses instalado: $LFS/usr/lib/libncursesw.so.6"
else
    log "❌ Falha crítica: libncursesw.so.6 não encontrado"
    exit 1
fi

log "🧹 Limpando fontes temporárias..."
rm -rf "$WORKSPACE_DIR/ncurses-6.5"
log "🎉 Ncurses bootstrap concluído. Próximo: 06.4-bootstrap-readline.sh"