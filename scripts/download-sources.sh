#!/usr/bin/env bash
# download-sources.sh v3 - Fase 1 Only (Tier 1 & 2)
# Filosofia: explícito por tiers, checksums oficiais, falha cedo.
# Roadmap: Fase 0 → Fase 1 (Meses 1-6) - Toolchain + Sistema Base Bootável

set -euo pipefail

# ──────────────────────────────────────────────────────────────
# CONFIGURAÇÃO EXPLÍCITA
# ──────────────────────────────────────────────────────────────
CONTINUE_ON_ERROR="${CONTINUE_ON_ERROR:-true}"
SOURCES_DIR="${SOURCES_DIR:-$HOME/vera-workspace/sources}"
PATCHES_DIR="${PATCHES_DIR:-$HOME/vera-workspace/patches}"
LFS_VERSION="12.2"
LFS_BASE="https://www.linuxfromscratch.org/lfs/downloads/$LFS_VERSION"

log()   { echo "[vera-download] $*"; }
error() { 
    echo "[vera-download] ERRO: $*" >&2
    [[ "$CONTINUE_ON_ERROR" == "true" ]] && return 1 || exit 1
}
mkdir -p "$SOURCES_DIR" "$PATCHES_DIR"

# ──────────────────────────────────────────────────────────────
# LISTAS OFICIAIS LFS (fonte única de verdade para checksums)
# ──────────────────────────────────────────────────────────────
log "Baixando listas oficiais do LFS $LFS_VERSION..."

# Baixa wget-list (sempre disponível)
if ! wget -q -O "$SOURCES_DIR/wget-list" "$LFS_BASE/wget-list"; then
    error "Falha ao baixar wget-list de $LFS_BASE/wget-list"
fi
log "✅ wget-list baixado"

# Baixa md5sums (LFS 12.2 usa MD5, não SHA256)
if ! wget -q -O "$SOURCES_DIR/md5sums" "$LFS_BASE/md5sums"; then
    log "⚠️  Não foi possível baixar md5sums oficial. Continuando sem validação automática."
    log "💡 Dica: Valida manualmente depois com os hashes do LFS book."
else
    log "✅ md5sums baixado"
fi

# ──────────────────────────────────────────────────────────────
# TIER 1 & 2: Essenciais para Fase 1 (Toolchain + Base Bootável)
# ──────────────────────────────────────────────────────────────
read -r -d '' PKGS << 'EOList' || true
https://download.savannah.gnu.org/releases/acl/acl-2.3.2.tar.xz
https://download.savannah.gnu.org/releases/attr/attr-2.5.2.tar.gz
https://ftp.gnu.org/gnu/autoconf/autoconf-2.72.tar.xz
https://ftp.gnu.org/gnu/automake/automake-1.17.tar.xz
https://ftp.gnu.org/gnu/bash/bash-5.2.32.tar.gz
https://sourceware.org/pub/binutils/releases/binutils-2.43.1.tar.xz
https://ftp.gnu.org/gnu/bison/bison-3.8.2.tar.xz
https://ftp.gnu.org/gnu/bc/bc-1.07.1.tar.gz
https://www.sourceware.org/pub/bzip2/bzip2-1.0.8.tar.gz
https://ftp.gnu.org/gnu/coreutils/coreutils-9.5.tar.xz
https://ftp.gnu.org/gnu/dejagnu/dejagnu-1.6.3.tar.gz
https://ftp.gnu.org/gnu/diffutils/diffutils-3.10.tar.xz
https://downloads.sourceforge.net/project/e2fsprogs/e2fsprogs/v1.47.1/e2fsprogs-1.47.1.tar.gz
https://sourceware.org/ftp/elfutils/0.191/elfutils-0.191.tar.bz2
https://github.com/libexpat/libexpat/releases/download/R_2_6_2/expat-2.6.2.tar.xz
https://astron.com/pub/file/file-5.45.tar.gz
https://ftp.gnu.org/gnu/findutils/findutils-4.10.0.tar.xz
https://github.com/westes/flex/releases/download/v2.6.4/flex-2.6.4.tar.gz
https://ftp.gnu.org/gnu/gawk/gawk-5.3.0.tar.xz
https://ftp.gnu.org/gnu/gcc/gcc-14.2.0/gcc-14.2.0.tar.xz
https://ftp.gnu.org/gnu/gdbm/gdbm-1.24.tar.gz
https://ftp.gnu.org/gnu/gettext/gettext-0.22.5.tar.xz
https://musl.libc.org/releases/musl-1.2.5.tar.gz
https://ftp.gnu.org/gnu/gmp/gmp-6.3.0.tar.xz
https://ftp.gnu.org/gnu/gperf/gperf-3.1.tar.gz
https://ftp.gnu.org/gnu/grep/grep-3.11.tar.xz
https://ftp.gnu.org/gnu/groff/groff-1.23.0.tar.gz
https://ftp.gnu.org/gnu/grub/grub-2.12.tar.xz
https://ftp.gnu.org/gnu/gzip/gzip-1.13.tar.xz
https://github.com/Mic92/iana-etc/releases/download/20240806/iana-etc-20240806.tar.gz
https://ftp.gnu.org/gnu/inetutils/inetutils-2.5.tar.xz
https://www.kernel.org/pub/linux/utils/net/iproute2/iproute2-6.10.0.tar.xz
https://www.kernel.org/pub/linux/utils/kbd/kbd-2.6.4.tar.xz
https://www.kernel.org/pub/linux/utils/kernel/kmod/kmod-33.tar.xz
https://www.greenwoodsoftware.com/less/less-661.tar.gz
https://www.kernel.org/pub/linux/libs/security/linux-privs/libcap2/libcap-2.70.tar.xz
https://github.com/libffi/libffi/releases/download/v3.4.6/libffi-3.4.6.tar.gz
https://download.savannah.gnu.org/releases/libpipeline/libpipeline-1.5.7.tar.gz
https://ftp.gnu.org/gnu/libtool/libtool-2.4.7.tar.xz
https://github.com/besser82/libxcrypt/releases/download/v4.4.36/libxcrypt-4.4.36.tar.xz
https://www.kernel.org/pub/linux/kernel/v6.x/linux-6.10.5.tar.xz
https://ftp.gnu.org/gnu/m4/m4-1.4.19.tar.xz
https://ftp.gnu.org/gnu/make/make-4.4.1.tar.gz
https://download.savannah.gnu.org/releases/man-db/man-db-2.12.1.tar.xz
https://www.kernel.org/pub/linux/docs/man-pages/man-pages-6.9.1.tar.xz
https://github.com/mesonbuild/meson/releases/download/1.5.1/meson-1.5.1.tar.gz
https://ftp.gnu.org/gnu/mpc/mpc-1.3.1.tar.gz
https://ftp.gnu.org/gnu/mpfr/mpfr-4.2.1.tar.xz
https://invisible-mirror.net/archives/ncurses/ncurses-6.5.tar.gz
https://www.openssl.org/source/openssl-3.3.1.tar.gz
https://ftp.gnu.org/gnu/patch/patch-2.7.6.tar.xz
https://www.cpan.org/src/5.0/perl-5.40.0.tar.xz
https://distfiles.ariadne.space/pkgconf/pkgconf-2.3.0.tar.xz
https://sourceforge.net/projects/procps-ng/files/Production/procps-ng-4.0.4.tar.xz
https://sourceforge.net/projects/psmisc/files/psmisc/psmisc-23.7.tar.xz
https://www.python.org/ftp/python/3.12.5/Python-3.12.5.tar.xz
https://ftp.gnu.org/gnu/readline/readline-8.2.13.tar.gz
https://ftp.gnu.org/gnu/sed/sed-4.9.tar.xz
https://pypi.org/packages/source/s/setuptools/setuptools-72.2.0.tar.gz
https://github.com/shadow-maint/shadow/releases/download/4.16.0/shadow-4.16.0.tar.xz
https://github.com/troglobit/sysklogd/releases/download/v2.6.1/sysklogd-2.6.1.tar.gz
https://github.com/slicer69/sysvinit/releases/download/3.10/sysvinit-3.10.tar.xz
https://ftp.gnu.org/gnu/tar/tar-1.35.tar.xz
https://downloads.sourceforge.net/tcl/tcl8.6.14-src.tar.gz
https://ftp.gnu.org/gnu/texinfo/texinfo-7.1.tar.xz
https://www.iana.org/time-zones/repository/releases/tzdata2024a.tar.gz
https://www.kernel.org/pub/linux/utils/util-linux/v2.40/util-linux-2.40.2.tar.xz
https://github.com/vim/vim/archive/v9.1.0660/vim-9.1.0660.tar.gz
https://pypi.org/packages/source/w/wheel/wheel-0.44.0.tar.gz
https://github.com//tukaani-project/xz/releases/download/v5.6.2/xz-5.6.2.tar.xz
https://zlib.net/fossils/zlib-1.3.1.tar.gz
https://github.com/facebook/zstd/releases/download/v1.5.6/zstd-1.5.6.tar.gz
EOList

# ──────────────────────────────────────────────────────────────
# TIER 3: Comentado para Fase 2+ (Desktop, Python Runtime, Systemd, Testes)
# Descomenta quando chegares à Fase 3 do roadmap.
# ──────────────────────────────────────────────────────────────
# read -r -d '' TIER3_PKGS << 'EOList' || true
# https://github.com/libcheck/check/releases/download/0.15.2/check-0.15.2.tar.gz
# https://dbus.freedesktop.org/releases/dbus/dbus-1.14.10.tar.xz
# https://pypi.org/packages/source/f/flit-core/flit_core-3.9.0.tar.gz
# https://pypi.org/packages/source/J/Jinja2/jinja2-3.1.4.tar.gz
# https://www.linuxfromscratch.org/lfs/downloads/12.2/lfs-bootscripts-20240825.tar.xz
# https://pypi.org/packages/source/M/MarkupSafe/MarkupSafe-2.1.5.tar.gz
# https://github.com/ninja-build/ninja/archive/v1.12.1/ninja-1.12.1.tar.gz
# https://www.python.org/ftp/python/doc/3.12.5/python-3.12.5-docs-html.tar.bz2
# https://github.com/systemd/systemd/archive/v256.4/systemd-256.4.tar.gz
# https://anduin.linuxfromscratch.org/LFS/systemd-man-pages-256.4.tar.xz
# https://downloads.sourceforge.net/tcl/tcl8.6.14-html.tar.gz
# https://anduin.linuxfromscratch.org/LFS/udev-lfs-20230818.tar.xz
# https://cpan.metacpan.org/authors/id/T/TO/TODDR/XML-Parser-2.47.tar.gz
# EOList

# ──────────────────────────────────────────────────────────────
# PATCHES ESSENCIAIS (LFS 12.2)
# ──────────────────────────────────────────────────────────────
read -r -d '' PATCHES << 'EOList' || true
https://www.linuxfromscratch.org/patches/lfs/12.2/bzip2-1.0.8-install_docs-1.patch
https://www.linuxfromscratch.org/patches/lfs/12.2/coreutils-9.5-i18n-2.patch
https://www.linuxfromscratch.org/patches/lfs/12.2/kbd-2.6.4-backspace-1.patch
https://www.linuxfromscratch.org/patches/lfs/12.2/sysvinit-3.10-consolidated-1.patch

EOList

# ──────────────────────────────────────────────────────────────
# LÓGICA DE DOWNLOAD & VALIDAÇÃO
# ──────────────────────────────────────────────────────────────
download_with_verify() {
    local url="$1" target_dir="$2"
    local filename=$(basename "$url")
    local target="$target_dir/$filename"
    
    if [[ -f "$target" ]]; then
        log "✅ $filename: já existe, a validar checksum..."
        if [[ -f "$SOURCES_DIR/md5sums" ]] && grep -q "$filename" "$SOURCES_DIR/md5sums" 2>/dev/null; then
            (cd "$target_dir" && md5sum -c <(grep "$filename" "$SOURCES_DIR/md5sums") 2>/dev/null) && \
                { log "✅ $filename: MD5 válido"; return 0; } || \
                { log "⚠️  $filename: MD5 inválido, a rebaixar..."; rm -f "$target"; }
        else
            log "⚠️  $filename: sem checksum na lista (pular validação)"
        fi
    fi
    
    log "⬇️  $filename..."
    curl -fL --retry 3 -o "$target" "$url" 2>/dev/null || \
        wget -q -O "$target" "$url" || \
        error "Falha ao baixar $filename"
    
    # Valida apenas se md5sums existir e tiver a entrada
    if [[ -f "$SOURCES_DIR/md5sums" ]] && grep -q "$filename" "$SOURCES_DIR/md5sums" 2>/dev/null; then
        (cd "$target_dir" && md5sum -c <(grep "$filename" "$SOURCES_DIR/md5sums")) || \
            error "MD5 falhou para $filename — ficheiro corrompido"
        log "✅ $filename: validado"
    else
        log "⚠️  $filename: sem MD5 na lista oficial (validação manual recomendada)"
    fi
}

# ──────────────────────────────────────────────────────────────
# EXECUÇÃO
# ──────────────────────────────────────────────────────────────
log "=== BAIXANDO TIER 1 & 2 (Fase 1: Toolchain + Base) ==="
while IFS= read -r url; do
    [[ -z "$url" ]] && continue
    download_with_verify "$url" "$SOURCES_DIR"
done <<< "$PKGS"

log "=== BAIXANDO PATCHES ==="
while IFS= read -r url; do
    [[ -z "$url" ]] && continue
    download_with_verify "$url" "$PATCHES_DIR"
done <<< "$PATCHES"

# ──────────────────────────────────────────────────────────────
# RESUMO EXPLÍCITO
# ──────────────────────────────────────────────────────────────
log "=== RESUMO FASE 1 ==="
log "📦 Sources: $(ls -1 "$SOURCES_DIR"/*.tar.* 2>/dev/null | wc -l) ficheiros"
log "🩹 Patches: $(ls -1 "$PATCHES_DIR"/*.patch 2>/dev/null | wc -l) ficheiros"
log "💾 Espaço: $(du -sh "$SOURCES_DIR" "$PATCHES_DIR" 2>/dev/null | awk '{print $1, $2}' | paste -sd' ')"
log "🎉 Download concluído. Pronto para LFS Cap. 5 (Toolchain Temporária)."
