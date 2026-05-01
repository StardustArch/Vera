#!/usr/bin/env bash
# 10-build-base-system.sh - Vëra Fase 1: Sistema Base (Musl)
# Uso: cd /sources && chmod +x 10-build-base-system.sh && ./10-build-base-system.sh

set -euo pipefail

SOURCES="/sources"
LOG="/var/log/vera-build/10-base.log"
mkdir -p "$(dirname "$LOG")"

# Toolchain Musl explícita (SEM LDFLAGS GLOBAL para não quebrar ./configure)
export CC="x86_64-linux-musl-gcc"
export CXX="x86_64-linux-musl-g++"
export AR="x86_64-linux-musl-ar"
export RANLIB="x86_64-linux-musl-ranlib"
export CFLAGS="-O2 -pipe"
export MAKEFLAGS="-j$(nproc)"
export PKG_CONFIG=pkgconf

log() { echo "[vera] $(date '+%H:%M:%S') $1" | tee -a "$LOG"; }
die() {
    log "❌ FALHA CRÍTICA: $1"
    log "📜 Últimas 20 linhas do log:"
    tail -n 20 "$LOG" 2>/dev/null | sed 's/^/  /'
    exit 1
}

run() { "$@" >> "$LOG" 2>&1 || die "$*"; }

# ──────────────────────────────────────────────────────────────
# 0. PRÉ-REQUISITO: GZIP
# ──────────────────────────────────────────────────────────────
log "── 0. Compilando gzip (pré-requisito) ──"
if [[ -f "$SOURCES/gzip-1.13.tar.xz" ]]; then
    cd "$SOURCES"
    rm -rf gzip-1.13
    tar xf gzip-1.13.tar.xz
    cd gzip-1.13
    run ./configure --prefix=/usr --host=x86_64-linux-musl
    run make
    run make install
    cd "$SOURCES"
    rm -rf gzip-1.13
    log "✅ gzip instalado. tar agora abre .tar.gz"
else
    die "gzip-1.13.tar.xz não encontrado"
fi

# ──────────────────────────────────────────────────────────────
# 1. IANA-ETC
# ──────────────────────────────────────────────────────────────
log "── 1. iana-etc ──"
if [[ -f "$SOURCES/iana-etc-20240806.tar.gz" ]]; then
    cd "$SOURCES"
    tar xf iana-etc-20240806.tar.gz
    cp -v iana-etc-20240806/services /etc/services
    cp -v iana-etc-20240806/protocols /etc/protocols
    rm -rf iana-etc-20240806
    log "✅ iana-etc configurado."
else
    log "⚠️ iana-etc não encontrado. A pular."
fi

# ──────────────────────────────────────────────────────────────
# 2. HELPER AUTOCONF
# ──────────────────────────────────────────────────────────────
build() {
    local name="$1" ver="$2" tarball="$3" flags="$4"
    if [[ ! -f "$SOURCES/$tarball" ]]; then
        log "⚠️ $tarball ausente. A pular."
        return 0
    fi
    log "── $name-$ver ──"
    cd "$SOURCES"
    rm -rf "${name}-${ver}"
    tar xf "$tarball"
    cd "${name}-${ver}"
    # --host explícito + LDFLAGS local (não global)
    run ./configure --prefix=/usr --host=x86_64-linux-musl --disable-static --disable-nls \
        LDFLAGS="-Wl,-rpath-link=/usr/lib" $flags
    run make
    run make install
    cd "$SOURCES"
    rm -rf "${name}-${ver}"
    log "✅ $name concluído."
}

# ──────────────────────────────────────────────────────────────
# 3. PACOTES ESSENCIAIS
# ──────────────────────────────────────────────────────────────
build "util-linux" "2.40.2" "util-linux-2.40.2.tar.xz" \
    "--disable-makeinstall-chown --disable-makeinstall-setuid --disable-libs --disable-liblastlog2 --without-python --without-systemd --without-tinfo"

CFLAGS="-O2 -pipe -Wno-error=implicit-function-declaration" \
build "e2fsprogs" "1.47.1" "e2fsprogs-1.47.1.tar.gz" \
    "--enable-elf-shlibs --with-root-prefix="

log "── shadow-4.16.0 ──"
cd "$SOURCES"
rm -rf shadow-4.16.0
tar xf shadow-4.16.0.tar.xz
cd shadow-4.16.0

# Musl fix: desactiva libbsd e força cache do autoconf para usar fallback seguro
run ./configure --prefix=/usr --host=x86_64-linux-musl --disable-static --disable-nls \
    LDFLAGS="-Wl,-rpath-link=/usr/lib" \
    --without-selinux --with-group-name-max-length=32 \
    --without-libbsd ac_cv_func_readpassphrase=no

run make
run make install
cd "$SOURCES"
rm -rf shadow-4.16.0
[[ -x /usr/bin/passwd ]] && mv -v /usr/bin/passwd /usr/sbin
[[ -x /usr/bin/chpasswd ]] && mv -v /usr/bin/chpasswd /usr/sbin
log "✅ shadow concluído."


build "pkgconf" "2.3.0" "pkgconf-2.3.0.tar.xz" ""

build "procps-ng" "4.0.4" "procps-ng-4.0.4.tar.xz" "--without-ncurses"

build "psmisc"    "23.7"    "psmisc-23.7.tar.xz" ""

log "── kbd-2.6.4 ──"
cd "$SOURCES"
rm -rf kbd-2.6.4
tar xf kbd-2.6.4.tar.xz
cd kbd-2.6.4

# Configuração padrão
run ./configure --prefix=/usr --host=x86_64-linux-musl --disable-static --disable-nls \
    LDFLAGS="-Wl,-rpath-link=/usr/lib" --disable-vlock

# FIX EXPLÍCITO: O Makefile gerado tenta compilar 'tests' (que exige autom4te).
# Editamos o ficheiro para remover essa referência antes de compilar.
sed -i 's/ tests//g' Makefile

run make -j1
run make install
cd "$SOURCES"
rm -rf kbd-2.6.4
log "✅ kbd concluído."


build "kmod" "33" "kmod-33.tar.xz" \
    "--with-xz --with-zlib --disable-static --without-openssl --without-zstd --disable-manpages"
    
log "── sysvinit ──"
if [[ -f "$SOURCES/sysvinit-3.10.tar.xz" ]]; then
    cd "$SOURCES"
    rm -rf sysvinit-3.10
    tar xf sysvinit-3.10.tar.xz
    cd sysvinit-3.10
    [[ -f ../sysvinit-3.10-consolidated-1.patch ]] && run patch -Np1 -i ../sysvinit-3.10-consolidated-1.patch
    run make -C src
    run make -C src install
    cd "$SOURCES"
    rm -rf sysvinit-3.10
    log "✅ sysvinit concluído."
fi

log ""
log "🎉 Sistema base concluído."
log "🚀 Próximo: Kernel Linux & GRUB (Milestone 1)"
