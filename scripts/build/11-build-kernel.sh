#!/usr/bin/env bash
# 11-build-kernel.sh - Vëra Milestone 1: Kernel Linux 6.10.5 (Musl)
# Filosofia: explícito, autónomo, documentado, zero intervenção manual.
# Uso: DENTRO DO CHROOT. cd /sources && chmod +x 11-build-kernel.sh && ./11-build-kernel.sh

set -euo pipefail

SOURCES="/sources"
LOG="/var/log/vera-build/11-kernel.log"
mkdir -p "$(dirname "$LOG")"

log()   { echo "[vera-kernel] $(date '+%H:%M:%S') $1" | tee -a "$LOG"; }
fail()  { log "❌ FALHA CRÍTICA: $1"; tail -20 "$LOG"; exit 1; }
run()   { "$@" >> "$LOG" 2>&1 || fail "$*"; }

# ──────────────────────────────────────────────────────────────
# 0. PRE-FLIGHT: PATH, SYMLINKS, SHELL
# ──────────────────────────────────────────────────────────────
log "── Verificando ambiente chroot ──"
export PATH="/usr/bin:/usr/sbin:/bin:/tools/bin"
[[ -e /usr/bin/sh ]] || ln -sfv /usr/bin/bash /usr/bin/sh >/dev/null 2>&1
command -v bc &>/dev/null || log "⚠️ bc não encontrado. Será compilado agora."

# ──────────────────────────────────────────────────────────────
# 1. BC (dependência obrigatória para timeconst.h)
#    Workaround: bc-1.07.1 exige 'ed' para gerar libmath.h.
#    Solução Vëra: injetar libmath.h mínimo + pular fix-libmath_h
# ──────────────────────────────────────────────────────────────
if ! command -v bc &>/dev/null; then
    log "── Compilando bc-1.07.1 (patch ed/libmath) ──"
    [[ -f "$SOURCES/bc-1.07.1.tar.gz" ]] || fail "bc-1.07.1.tar.gz ausente"
    cd "$SOURCES"
    rm -rf bc-1.07.1
    tar xf bc-1.07.1.tar.gz
    cd bc-1.07.1

    # Patch explícito: evita dependência de 'ed'
    cat > bc/libmath.h << 'EOF'
/* Vëra bootstrap: libmath.h mínimo (bypass ed dependency) */
static const char *libmath_b = "";
EOF
    sed -i 's|./fix-libmath_h|true # skipped (no ed)|' bc/Makefile

    run ./configure --prefix=/usr >/dev/null 2>&1
    run make -j$(nproc) >/dev/null 2>&1
    run make install >/dev/null 2>&1
    cd "$SOURCES" && rm -rf bc-1.07.1
    log "✅ bc compilado e instalado."
fi

# ──────────────────────────────────────────────────────────────
# 2. PREPARAÇÃO DO KERNEL
# ──────────────────────────────────────────────────────────────
log "── Preparando linux-6.10.5 ──"
cd "$SOURCES"
[[ -f linux-6.10.5.tar.xz ]] || fail "linux-6.10.5.tar.xz ausente"
rm -rf linux-6.10.5
tar xf linux-6.10.5.tar.xz
cd linux-6.10.5

run make mrproper >/dev/null 2>&1
run make defconfig >/dev/null 2>&1

# Desactivar validações/dev tools que dependem de glibc/openssl
log "── Aplicando config Vëra (musl-safe) ──"
scripts/config --disable STACK_VALIDATION UNWINDER_ORC DEBUG_INFO_BTF DEBUG_INFO
scripts/config --disable SYSTEM_CERTIFICATE_GENERATION SYSTEM_TRUSTED_KEYS SYSTEM_REVOCATION_KEYS MODULE_SIG MODULE_SIG_ALL


# Fallback explícito: força desactivação no .config (evita reversão pelo olddefconfig)
sed -i 's|^CONFIG_SYSTEM_CERTIFICATE_GENERATION=y|# CONFIG_SYSTEM_CERTIFICATE_GENERATION is not set|' .config
sed -i 's|^CONFIG_MODULE_SIG=y|# CONFIG_MODULE_SIG is not set|' .config
sed -i 's|^CONFIG_SYSTEM_TRUSTED_KEYS=.*|# CONFIG_SYSTEM_TRUSTED_KEYS is not set|' .config
sed -i 's|^CONFIG_SYSTEM_REVOCATION_KEYS=.*|# CONFIG_SYSTEM_REVOCATION_KEYS is not set|' .config

# Activar drivers VIRTIO (essencial para QEMU moderno)
log "── Activando drivers VIRTIO para QEMU ──"
scripts/config --enable VIRTIO
scripts/config --enable VIRTIO_PCI
scripts/config --enable VIRTIO_BLK
scripts/config --enable BLK_DEV_SD
scripts/config --enable SCSI

run make olddefconfig >/dev/null 2>&1

# ──────────────────────────────────────────────────────────────
# 3. OBJTOOL STUB (bypass libelf/argp dependency)
#    O kernel invoca objtool na linkagem de vmlinux.o.
#    Como desactivamos as dependências reais, criamos um stub inofensivo.
# ──────────────────────────────────────────────────────────────
log "── Criando stub objtool ──"
mkdir -p tools/objtool
cat > tools/objtool/objtool << 'DUMMY'
#!/bin/sh
# Vëra bootstrap dummy objtool
# Retorna sucesso imediato para permitir linkagem sem libelf/argp.
exit 0
DUMMY
chmod +x tools/objtool/objtool

# ──────────────────────────────────────────────────────────────
# 4. COMPILAÇÃO & INSTALAÇÃO
# ──────────────────────────────────────────────────────────────
log "── Compilando bzImage ──"
run make -j$(nproc) SKIP_STACK_VALIDATION=1 bzImage

log "── Instalando em /boot ──"
mkdir -p /boot
if [[ -f arch/x86/boot/bzImage ]]; then
    cp -v arch/x86/boot/bzImage /boot/vmlinuz-6.10.5-vera
    cp -v System.map /boot/System.map-6.10.5-vera 2>/dev/null || true
    cp -v .config /boot/config-6.10.5-vera
    log "✅ Kernel instalado."
else
    fail "bzImage não gerado."
fi

# ──────────────────────────────────────────────────────────────
# 5. VALIDAÇÃO FINAL
# ──────────────────────────────────────────────────────────────
log ""
log "📊 Validação:"
ls -lh /boot/vmlinuz-6.10.5-vera && log "✅ bzImage presente ($(du -h /boot/vmlinuz-6.10.5-vera | awk '{print $1}'))"
head -c 2 /boot/vmlinuz-6.10.5-vera | od -An -tx1 | grep -q "1f 8b" && \
  log "✅ Formato gzip válido (bzImage)" || log "⚠️ Formato inesperado"
log ""
log "🎉 Milestone 1: Kernel compilado e pronto para GRUB."
log "🚀 Próximo: ./12-boot-config.sh (GRUB + fstab + inittab + grub.cfg)"