#!/usr/bin/env bash
# 06.5-bootstrap-bash.sh - Vëra Bootstrap: Bash nativo + Loader correcto
# Filosofia: explícito, zero cópia do host, symlinks relativos, fail-fast, self-contained.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
SOURCES_DIR="${WORKSPACE_DIR}/sources"
LOG_DIR="${WORKSPACE_DIR}/logs/build"
mkdir -p "$LOG_DIR"

LOG_FILE="${LOG_DIR}/06.5-bootstrap-bash.log"
log() { echo "[vera-build] $(date '+%Y-%m-%d %H:%M:%S') $*" | tee -a "$LOG_FILE"; }

# ──────────────────────────────────────────────────────────────
# 1. VALIDAÇÃO INICIAL (Fail-fast)
# ──────────────────────────────────────────────────────────────
[[ -z "${LFS:-}" || -z "${LFS_TGT:-}" ]] && { log "❌ ERRO: \$LFS ou \$LFS_TGT não definidos."; exit 1; }
[[ ! -x "$LFS/tools/bin/${LFS_TGT}-gcc" ]] && { log "❌ Toolchain ausente. Executa 01→05 primeiro."; exit 1; }
[[ ! -f "${SOURCES_DIR}/bash-5.2.32.tar.gz" ]] && { log "❌ Source bash não encontrado."; exit 1; }

log "✅ Pré-requisitos validados."

# ──────────────────────────────────────────────────────────────
# 2. SYMLINKS NCURSES (Requisito para readline/bash)
# ──────────────────────────────────────────────────────────────
NCURSES_LIB="$LFS/usr/lib/libncursesw.so.6"
if [[ ! -f "$NCURSES_LIB" ]]; then
    log "❌ ERRO: $NCURSES_LIB ausente. Executa 06.3-bootstrap-ncurses.sh primeiro."
    exit 1
fi

log "🔗 Criando symlinks ncurses..."
ln -sfv libncursesw.so.6 "$LFS/usr/lib/libncursesw.so"
ln -sfv libncursesw.so "$LFS/usr/lib/libncurses.so"
ln -sfv libncursesw.so "$LFS/usr/lib/libcurses.so"
log "✅ Symlinks ncurses válidos."

# ──────────────────────────────────────────────────────────────
# 3. LOADER/INTERPRETER (CRÍTICO - VALIDAÇÃO MUSL)
# ──────────────────────────────────────────────────────────────
log "🔍 Validando dynamic linker (musl)..."
# Musl usa path fixo: /lib/ld-musl-ARCH.so.1
MUSL_LD="$LFS/lib/ld-musl-x86_64.so.1"

if [[ -e "$MUSL_LD" ]]; then
    log "✅ Loader musl encontrado: $MUSL_LD"
elif [[ -L "$MUSL_LD" && -e "$(readlink -f "$MUSL_LD" 2>/dev/null)" ]]; then
    log "✅ Loader musl (symlink) válido: $MUSL_LD"
else
    log "❌ ERRO CRÍTICO: Loader musl não encontrado em $MUSL_LD"
    log "💡 Verifica se 04-musl.sh instalou correctamente"
    exit 1
fi
log "✅ Loader válido: $MUSL_LD"

# ──────────────────────────────────────────────────────────────
# 4. COMPILAÇÃO
# ──────────────────────────────────────────────────────────────
cd "$WORKSPACE_DIR"
rm -rf bash-5.2.32
tar xf "${SOURCES_DIR}/bash-5.2.32.tar.gz"
cd bash-5.2.32

log "⚙️ Configurando bash..."
./configure \
    CFLAGS="-O2 -std=gnu89" \
    CFLAGS_FOR_BUILD="-O2 -std=gnu89" \
    CC_FOR_BUILD=gcc \
    --prefix=/usr \
    --host="$LFS_TGT" \
    --without-bash-malloc \
    --disable-nls \
    CC="$LFS_TGT-gcc" \
    AR="$LFS_TGT-ar" \
    RANLIB="$LFS_TGT-ranlib" \
    LDFLAGS="-L$LFS/usr/lib -Wl,-rpath-link=$LFS/usr/lib" \
    CPPFLAGS="-I$LFS/usr/include" 2>&1 | tee -a "$LOG_FILE"

log "🔨 Compilando..."
make -j"$(nproc)" 2>&1 | tee -a "$LOG_FILE"

log "📦 Instalando em \$LFS..."
make DESTDIR="$LFS" install 2>&1 | tee -a "$LOG_FILE"

# Symlink FHS: /bin/bash -> /usr/bin/bash
mkdir -p "$LFS/bin"
ln -sfv /usr/bin/bash "$LFS/bin/bash"
log "✅ Bash instalado e symlink FHS criado."

# ──────────────────────────────────────────────────────────────
# 5. VALIDAÇÃO AUTOMÁTICA (readelf + path resolution)
# ──────────────────────────────────────────────────────────────
log "🔍 Validando interpreter do bash compilado..."
INTERP=$(readelf -l "$LFS/usr/bin/bash" 2>/dev/null | grep interpreter | awk '{print $4}' | tr -d '[]')
if [[ -z "$INTERP" ]]; then
    log "❌ Não foi possível ler o interpreter do ELF."
    exit 1
fi

log "📖 Bash interpreter: $INTERP"
# Validar que o interpreter é o esperado do musl
if [[ "$INTERP" == *"/lib/ld-musl-x86_64.so.1" ]] && [[ -e "$LFS$INTERP" ]]; then
    log "✅ Interpreter musl válido e resolvido"
elif [[ -n "$INTERP" ]] && [[ -e "$LFS$INTERP" ]]; then
    log "⚠️  Interpreter detectado: $INTERP (validar manualmente se é musl)"
else
    log "❌ ERRO: Interpreter $INTERP não existe em \$LFS"
    exit 1
fi

# ──────────────────────────────────────────────────────────────
# 6. TESTE CHROOT (Seguro e explícito)
# ──────────────────────────────────────────────────────────────
log "🧪 Testando chroot mínimo..."

# Teste principal
if sudo chroot "$LFS" /usr/bin/bash --norc -c 'echo "[vera] chroot OK"' >/dev/null 2>&1; then
    log "✅ Chroot validado. Pronto para 07-enter-chroot.sh"
else
    # Fallback com LD_LIBRARY_PATH
    if sudo chroot "$LFS" env LD_LIBRARY_PATH=/lib:/usr/lib /usr/bin/bash --norc -c 'echo "[vera] chroot OK"' >/dev/null 2>&1; then
        log "✅ Chroot validado (com LD_LIBRARY_PATH). Pronto para 07-enter-chroot.sh"
    else
        log "⚠️  Chroot falhou no teste automatizado."
        log "💡 Entra manualmente: sudo ~/vera-workspace/scripts/build/08-enter-chroot.sh"
    fi
fi

# Limpeza
rm -rf "$WORKSPACE_DIR/bash-5.2.32"
log "🎉 Bootstrap bash concluído."