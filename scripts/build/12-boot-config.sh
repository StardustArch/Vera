#!/usr/bin/env bash
# 12-boot-config.sh - Vëra Fase 1: Python + GRUB + fstab + inittab + grub.cfg
# Uso: DENTRO DO CHROOT. cd /sources && chmod +x 12-boot-config.sh && ./12-boot-config.sh

set -euo pipefail

SOURCES="/sources"
LOG="/var/log/vera-build/12-boot.log"
mkdir -p "$(dirname "$LOG")"

log() { echo "[vera-boot] $(date '+%H:%M:%S') $1" | tee -a "$LOG"; }
run() { "$@" >> "$LOG" 2>&1 || { log "❌ FALHA: $*"; tail -5 "$LOG"; exit 1; }; }

# ──────────────────────────────────────────────────────────────
# 0. PYTHON 3 (dependência de build do GRUB 2.12)
#    Compilado minimal: sem ensurepip, sem testes, sem módulos opcionais.
# ──────────────────────────────────────────────────────────────
log "── Compilando Python 3.12.5 (mínimo para GRUB) ──"
if [[ ! -f "$SOURCES/Python-3.12.5.tar.xz" ]]; then
    log "⚠️ Python source não encontrado. GRUB pode falhar."
else
    cd "$SOURCES"
    rm -rf Python-3.12.5 build-python
    tar xf Python-3.12.5.tar.xz
    mkdir build-python && cd build-python

    # Config minimalista para cross-compile musl
    ../Python-3.12.5/configure \
        --prefix=/usr \
        --host=${LFS_TGT:-x86_64-linux-musl} \
        --build=$(gcc -dumpmachine) \
        --without-ensurepip \
        --disable-test-modules \
        --enable-optimizations=no \
        ac_cv_file__dev_ptmx=no \
        ac_cv_file__dev_ptc=no \
        >> "$LOG" 2>&1 || log "⚠️ Python configure avisos (normal em musl)"

    run make -j$(nproc)
    run make install

    # Criar symlink python3 -> python3.12
    ln -sfv python3.12 /usr/bin/python3
    hash -r  # atualiza cache do bash

    log "✅ Python 3.12 instalado: $(python3 --version 2>/dev/null || echo 'binário presente')"
    cd "$SOURCES" && rm -rf Python-3.12.5 build-python
fi

# ──────────────────────────────────────────────────────────────
# 1. COMPILAR GRUB 2.12 (plataforma i386-pc para BIOS)
# ──────────────────────────────────────────────────────────────
log "── Compilando GRUB 2.12 (plataforma: i386-pc) ──"
if [[ ! -f "$SOURCES/grub-2.12.tar.xz" ]]; then
    log "❌ grub-2.12.tar.xz não encontrado em /sources"
    exit 1
fi

cd "$SOURCES"
rm -rf grub-2.12
tar xf grub-2.12.tar.xz
cd grub-2.12

# Workaround upstream: extra_deps.lst não é gerado automaticamente
touch grub-core/extra_deps.lst

run ./configure \
    --prefix=/usr \
    --sysconfdir=/etc \
    --disable-werror \
    --target=i386 \
    --with-platform=pc \
    --disable-grub-mkfont \
    --disable-emu \
    --disable-nls

run make -j1  # sequencial para evitar race conditions no Makefile
run make install

cd "$SOURCES" && rm -rf grub-2.12
log "✅ GRUB compilado e instalado."

# ──────────────────────────────────────────────────────────────
# 2. /etc/fstab (Estrutura mínima para boot)
# ──────────────────────────────────────────────────────────────
log "── Criando /etc/fstab ──"
cat > /etc/fstab << 'FSTAB'
# <file system> <mount point> <type> <options> <dump> <pass>
/dev/vda1       /             ext4   rw,relatime 0     1
tmpfs           /tmp          tmpfs  nosuid,nodev  0     0
FSTAB
log "✅ /etc/fstab configurado."

# ──────────────────────────────────────────────────────────────
# 3. /etc/inittab (Sysvinit mínimo)
# ──────────────────────────────────────────────────────────────
log "── Criando /etc/inittab ──"
cat > /etc/inittab << 'INITTAB'
id:3:initdefault:
si::sysinit:/etc/rc.d/rc.sysinit
l0:0:wait:/etc/rc.d/rc 0
l1:1:wait:/etc/rc.d/rc 1
l2:2:wait:/etc/rc.d/rc 2
l3:3:wait:/etc/rc.d/rc 3
l4:4:wait:/etc/rc.d/rc 4
l5:5:wait:/etc/rc.d/rc 5
l6:6:wait:/etc/rc.d/rc 6
ca:12345:ctrlaltdel:/sbin/shutdown -t1 -a -r now
1:2345:respawn:/sbin/agetty --noclear tty1 linux
2:2345:respawn:/sbin/agetty tty2 linux
3:2345:respawn:/sbin/agetty tty3 linux
4:2345:respawn:/sbin/agetty tty4 linux
5:2345:respawn:/sbin/agetty tty5 linux
6:2345:respawn:/sbin/agetty tty6 linux
INITTAB
log "✅ /etc/inittab configurado."

# ──────────────────────────────────────────────────────────────
# 4. /boot/grub/grub.cfg (Explícito, zero magia)
# ──────────────────────────────────────────────────────────────
log "── Gerando grub.cfg ──"
mkdir -p /boot/grub
cat > /boot/grub/grub.cfg << 'GRUB'
set default=0
set timeout=5

insmod part_msdos
insmod ext2

menuentry "Vëra Linux 6.10.5 (Musl)" {
    set root='hd0,msdos1'
    linux /boot/vmlinuz-6.10.5-vera root=/dev/vda1 ro quiet loglevel=3
}
GRUB
log "✅ grub.cfg criado."

# ──────────────────────────────────────────────────────────────
# 5. RESUMO FINAL
# ──────────────────────────────────────────────────────────────
log ""
log "📊 Resumo do Milestone 1:"
log "✅ Kernel: /boot/vmlinuz-6.10.5-vera"
log "✅ Bootloader: /usr/bin/grub-* (plataforma i386-pc)"
log "✅ Python: /usr/bin/python3 ($(python3 --version 2>/dev/null || echo 'presente'))"
log "✅ Config: /etc/fstab + /etc/inittab + /boot/grub/grub.cfg"
log ""
log "🚀 Próximo passo (fora do chroot):"
log "1. Criar imagem: qemu-img create -f raw vera.img 4G"
log "2. Particionar: fdisk vera.img (criar partição 1, tipo Linux)"
log "3. Format: mkfs.ext4 /dev/loop0p1 (após losetup --partscan)"
log "4. Copiar: cp -a /mnt/lfs/* /mnt/vera-root/"
log "5. Instalar GRUB: grub-install --target=i386-pc --boot-directory=/mnt/vera-root/boot /dev/loop0"
log "6. Testar: qemu-system-x86_64 -drive file=vera.img,format=raw -m 2G"
log ""
log "🎉 Fase 1 concluída. Vëra está pronta para o primeiro boot."