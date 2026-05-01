#!/usr/bin/env bash
# 09-bootstrap-tools.sh
# Cross-compila utilitários essenciais para $LFS/usr/bin
# Corre no HOST antes de entrar no chroot.
# Filosofia: compilado para o target musl, zero cópia do host, substituídos pelo sistema final.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
SOURCES_DIR="${WORKSPACE_DIR}/sources"
BUILD_DIR="${WORKSPACE_DIR}/bootstrap-build"
LOG_DIR="${WORKSPACE_DIR}/logs/build"
mkdir -p "$LOG_DIR" "$BUILD_DIR"
# Garantir que o utilizador actual tem permissões (pode ter sido criado pelo sudo)
chown -R "$(id -u):$(id -g)" "$BUILD_DIR" 2>/dev/null || true

LOG_FILE="${LOG_DIR}/09-bootstrap-tools.log"
log()  { echo "[vera-build] $(date '+%Y-%m-%d %H:%M:%S') $*" | tee -a "$LOG_FILE"; }
ok()   { log "✅ $*"; }
fail() { log "❌ $*"; exit 1; }

# ──────────────────────────────────────────────────────────────
# VALIDAÇÕES
# ──────────────────────────────────────────────────────────────
[[ -z "${LFS:-}"     ]] && fail "\$LFS não definido."
[[ -z "${LFS_TGT:-}" ]] && fail "\$LFS_TGT não definido."
[[ -d "$LFS"         ]] || fail "\$LFS ($LFS) não existe."
[[ -x "$LFS/tools/bin/${LFS_TGT}-gcc" ]] || fail "Toolchain não encontrada. Executa 01→06 primeiro."

CC="${LFS_TGT}-gcc"
CXX="${LFS_TGT}-g++"
AR="${LFS_TGT}-ar"
RANLIB="${LFS_TGT}-ranlib"
STRIP="${LFS_TGT}-strip"
COMMON_FLAGS="
    --prefix=/usr
    --host=${LFS_TGT}
    --build=$(gcc -dumpmachine)
    --disable-nls
"
CFLAGS_TARGET="-O2"
LDFLAGS_TARGET="-L${LFS}/usr/lib -Wl,-rpath-link=${LFS}/usr/lib"
CPPFLAGS_TARGET="-I${LFS}/usr/include"

export PATH="${LFS}/tools/bin:$PATH"

log "✅ Ambiente validado. Iniciando bootstrap de ferramentas..."
log "   Target:  ${LFS_TGT}"
log "   LFS:     ${LFS}"
log "   Build:   ${BUILD_DIR}"
log ""

# ──────────────────────────────────────────────────────────────
# HELPER: extrai, compila, instala, limpa
# ──────────────────────────────────────────────────────────────
build_pkg() {
    local name="$1"
    local tarball="$2"
    local extra_flags="${3:-}"

    log "🔨 Compilando $name..."

    local src_dir
    src_dir=$(basename "$tarball" .tar.gz)
    src_dir=$(basename "$src_dir" .tar.xz)
    src_dir=$(basename "$src_dir" .tar.bz2)

    cd "$BUILD_DIR"
    rm -rf "$src_dir" "build-$name"
    tar xf "${SOURCES_DIR}/${tarball}"
    mkdir "build-$name"
    cd "build-$name"

    # shellcheck disable=SC2086
    "../${src_dir}/configure" \
        $COMMON_FLAGS \
        CC="$CC" \
        CXX="$CXX" \
        AR="$AR" \
        RANLIB="$RANLIB" \
        CFLAGS="$CFLAGS_TARGET" \
        LDFLAGS="$LDFLAGS_TARGET" \
        CPPFLAGS="$CPPFLAGS_TARGET" \
        $extra_flags \
        >> "$LOG_FILE" 2>&1 || fail "$name: configure falhou. Ver $LOG_FILE"

    make -j"$(nproc)" >> "$LOG_FILE" 2>&1 || fail "$name: make falhou. Ver $LOG_FILE"
    make DESTDIR="$LFS" install >> "$LOG_FILE" 2>&1 || fail "$name: make install falhou. Ver $LOG_FILE"

    # Strip para reduzir tamanho (são temporários)
    find "$LFS/usr/bin" -newer "${SOURCES_DIR}/${tarball}" -type f \
        -exec "$STRIP" --strip-unneeded {} \; 2>/dev/null || true

    cd "$BUILD_DIR"
    rm -rf "$src_dir" "build-$name"
    ok "$name instalado."
}

# ──────────────────────────────────────────────────────────────
# PACOTES — ordem importa (dependências primeiro)
# ──────────────────────────────────────────────────────────────

# 1. zlib — dependência de tar, xz, gcc, openssl, etc.
log "── zlib ──────────────────────────────────────────"
cd "$BUILD_DIR"
rm -rf zlib-1.3.1
tar xf "${SOURCES_DIR}/zlib-1.3.1.tar.gz"
cd zlib-1.3.1
CC="$CC" CFLAGS="$CFLAGS_TARGET" \
./configure --prefix=/usr >> "$LOG_FILE" 2>&1 || fail "zlib: configure falhou"
make -j"$(nproc)" >> "$LOG_FILE" 2>&1 || fail "zlib: make falhou"
make DESTDIR="$LFS" install >> "$LOG_FILE" 2>&1 || fail "zlib: install falhou"
cd "$BUILD_DIR"
rm -rf zlib-1.3.1
ok "zlib instalada."

# 2. xz — necessário para extrair .tar.xz
log "── xz ────────────────────────────────────────────"
build_pkg "xz" "xz-5.6.2.tar.xz" \
    "--disable-doc --disable-scripts"

# 3. tar — extrair sources dentro do chroot
log "── tar ───────────────────────────────────────────"
build_pkg "tar" "tar-1.35.tar.xz"

# 4. make — compilar pacotes
log "── make ──────────────────────────────────────────"
build_pkg "make" "make-4.4.1.tar.gz" \
    "--without-guile"

# 5. grep — usado em scripts de configure
log "── grep ──────────────────────────────────────────"
build_pkg "grep" "grep-3.11.tar.xz"

# 6. sed — usado em scripts de configure e patch
log "── sed ───────────────────────────────────────────"
build_pkg "sed" "sed-4.9.tar.xz"

# 7. gawk — scripts de build
log "── gawk ──────────────────────────────────────────"
build_pkg "gawk" "gawk-5.3.0.tar.xz" \
    "--disable-extensions"

# 8. patch — aplicar patches LFS
log "── patch ─────────────────────────────────────────"
build_pkg "patch" "patch-2.7.6.tar.xz"

# 9. diffutils — dependência de vários build systems
log "── diffutils ─────────────────────────────────────"
build_pkg "diffutils" "diffutils-3.10.tar.xz"

# 10. findutils — find, xargs — usados em build systems
log "── findutils ─────────────────────────────────────"
build_pkg "findutils" "findutils-4.10.0.tar.xz"

# 11. coreutils — ls, cp, mv, rm, mkdir, cat, head, tail, etc.
log "── coreutils ─────────────────────────────────────"
cd "$BUILD_DIR"
rm -rf coreutils-9.5
tar xf "${SOURCES_DIR}/coreutils-9.5.tar.xz"
cd coreutils-9.5

which x86_64-linux-musl-gcc


mkdir build && cd build
../configure \
    --prefix=/usr \
    --host=x86_64-linux-musl \
    --build=$(gcc -dumpmachine) \
    --disable-nls \
    --enable-no-install-program=kill,uptime \
    CC=x86_64-linux-musl-gcc \
    AR=x86_64-linux-musl-ar \
    RANLIB=x86_64-linux-musl-ranlib \
    CFLAGS="-O2" \
    LDFLAGS="-L$LFS/usr/lib -Wl,-rpath-link=$LFS/usr/lib" \
    CPPFLAGS="-I$LFS/usr/include"
    
make -j"$(nproc)" >> "$LOG_FILE" 2>&1 || fail "coreutils: make falhou"
make DESTDIR="$LFS" install >> "$LOG_FILE" 2>&1 || fail "coreutils: install falhou"
cd "$BUILD_DIR"
rm -rf coreutils-9.5
ok "coreutils instalado."

# 12. bzip2 — extrair .tar.bz2
log "── bzip2 ─────────────────────────────────────────"
cd "$BUILD_DIR"
rm -rf bzip2-1.0.8
tar xf "${SOURCES_DIR}/bzip2-1.0.8.tar.gz"
cd bzip2-1.0.8
patch -Np1 -i "${SOURCES_DIR}/bzip2-1.0.8-install_docs-1.patch" >> "$LOG_FILE" 2>&1 || true

# Bzip2 tem Makefile antigo. Paralelismo (-jN) causa race conditions.
# Usamos -j1 para compilação determinística (padrão LFS).
make -j1 \
    CC="$CC" \
    AR="$AR" \
    RANLIB="$RANLIB" \
    CFLAGS="-O2 -D_FILE_OFFSET_BITS=64" \
    bzip2 bzip2recover libbz2.a \
    >> "$LOG_FILE" 2>&1 || fail "bzip2: make (static) falhou"

# Instala estática (binários + libbz2.a)
make PREFIX="${LFS}/usr" install >> "$LOG_FILE" 2>&1 || fail "bzip2: install (static) falhou"

# Prepara biblioteca partilhada
make clean >> "$LOG_FILE" 2>&1
make -f Makefile-libbz2_so \
    CC="$CC" \
    CFLAGS="-fPIC -O2" \
    >> "$LOG_FILE" 2>&1 || fail "bzip2: make shared falhou"

# Instala shared lib manualmente (bzip2 não o faz nativamente)
cp -av libbz2.so.1.0.8 "${LFS}/usr/lib/"
cd "${LFS}/usr/lib"
ln -sfv libbz2.so.1.0.8 libbz2.so
ln -sfv libbz2.so.1.0.8 libbz2.so.1
cd "$BUILD_DIR"

# Limpeza
rm -rf bzip2-1.0.8
ok "bzip2 instalado."

# ──────────────────────────────────────────────────────────────
# LIMPEZA
# ──────────────────────────────────────────────────────────────
rm -rf "$BUILD_DIR"

# ──────────────────────────────────────────────────────────────
# VALIDAÇÃO FINAL
# ──────────────────────────────────────────────────────────────
log ""
log "📊 Validação — binários instalados em \$LFS/usr/bin:"
for bin in tar make grep sed gawk patch find xargs ls cp mv rm mkdir cat head; do
    if [[ -x "${LFS}/usr/bin/${bin}" ]]; then
        log "  ✅ $bin"
    else
        log "  ❌ $bin — NÃO encontrado"
    fi
done

log ""
log "🧪 Teste rápido via chroot:"
chroot "$LFS" /usr/bin/env -i \
    PATH=/usr/bin:/usr/sbin \
    /usr/bin/bash --norc -c '
    echo "  tar:  $(tar --version 2>/dev/null | head -1)"
    echo "  make: $(make --version 2>/dev/null | head -1)"
    echo "  grep: $(grep --version 2>/dev/null | head -1)"
    echo "  ls:   $(ls --version 2>/dev/null | head -1)"
    echo "  find: $(find --version 2>/dev/null | head -1)"
    echo "  sed:  $(sed --version 2>/dev/null | head -1)"
' 2>&1 | tee -a "$LOG_FILE" || log "⚠️  Teste chroot falhou — verifica o loader musl"

log ""
ok "Bootstrap de ferramentas concluído."
log "🚀 Entra no chroot e começa o sistema base:"
log "   sudo -E ~/vera-workspace/scripts/build/08-enter-chroot.sh"
log "   cd /sources && tar xf zlib-1.3.1.tar.gz"