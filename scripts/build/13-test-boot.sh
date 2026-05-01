#!/usr/bin/env bash
# 13-test-boot.sh - Vëra Fase 1: Criação de Imagem, Instalação e Teste de Boot
# Uso: NO HOST. cd ~/vera-workspace/scripts/build && chmod +x 13-test-boot.sh && sudo ./13-test-boot.sh

set -euo pipefail

# ──────────────────────────────────────────────────────────────
# CONFIGURAÇÃO
# ──────────────────────────────────────────────────────────────
LFS="/mnt/lfs"
IMG_NAME="vera-boot-test.img"
IMG_SIZE="5G"
MOUNT_POINT="/mnt/vera-test"

# Cores
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Limpeza automática se o script falhar ou terminar (Ctrl+C)
cleanup() {
    echo "🧹 Limpando loop devices e pontos de montagem..."
    umount "$MOUNT_POINT"/{dev,proc,sys} 2>/dev/null || true
    umount "$MOUNT_POINT" 2>/dev/null || true
    losetup -d "$LOOP_DEV" 2>/dev/null || true
}
trap cleanup EXIT

echo -e "${GREEN}🚀 Vëra Fase 1: Preparando o Primeiro Boot...${NC}"

# ──────────────────────────────────────────────────────────────
# 0. VALIDAÇÕES
# ──────────────────────────────────────────────────────────────
[[ -d "$LFS" ]] || { echo -e "${RED}❌ \$LFS ($LFS) não encontrado.${NC}"; exit 1; }
command -v qemu-img &>/dev/null || { echo -e "${RED}❌ qemu-img não encontrado.${NC}"; exit 1; }
command -v grub-install &>/dev/null || { echo -e "${RED}❌ grub-install não encontrado.${NC}"; exit 1; }

# ──────────────────────────────────────────────────────────────
# 1. CRIAR E PARTICIONAR IMAGEM
# ──────────────────────────────────────────────────────────────
echo -e "\n📦 Criando imagem de disco ($IMG_SIZE)..."
rm -f "$IMG_NAME"
qemu-img create -f raw "$IMG_NAME" "$IMG_SIZE" >/dev/null 2>&1

echo "💾 Particionando imagem (MBR + partição Linux completa)..."
sfdisk "$IMG_NAME" << EOF
label: dos
1 : start=2048, size=+, type=83
EOF

# ──────────────────────────────────────────────────────────────
# 2. LOOP DEVICE & FORMATO
# ──────────────────────────────────────────────────────────────
echo "🔗 Configurando loop device..."
LOOP_DEV=$(losetup --find --partscan --show "$IMG_NAME")
LOOP_PART="${LOOP_DEV}p1"

echo "🎨 Formatando ${LOOP_PART} (ext4)..."
mkfs.ext4 -F -L vera-root "$LOOP_PART" >/dev/null 2>&1

# ──────────────────────────────────────────────────────────────
# 3. COPIAR SISTEMA
# ──────────────────────────────────────────────────────────────
mkdir -p "$MOUNT_POINT"
echo "📂 Montando ${LOOP_PART} em $MOUNT_POINT..."
mount "$LOOP_PART" "$MOUNT_POINT"

# Garante que não copiamos VFS montados no chroot
umount "$LFS"/{proc,sys,dev,dev/pts,run,tmp} 2>/dev/null || true

echo "📦 Copiando sistema base (excluindo diretórios virtuais)..."
rsync -aHAXx \
    --exclude='/dev/*' \
    --exclude='/proc/*' \
    --exclude='/sys/*' \
    --exclude='/tmp/*' \
    --exclude='/run/*' \
    "$LFS/" "$MOUNT_POINT/"

# Recriar diretórios vazios essenciais
mkdir -p "$MOUNT_POINT"/{dev,proc,sys,tmp,run}
chmod 1777 "$MOUNT_POINT/tmp"

# ──────────────────────────────────────────────────────────────
# 4. CORREÇÃO DO BOOT (GRUB.CFG DINÂMICO)
# ──────────────────────────────────────────────────────────────
# Obter PARTUUID da partição
PARTUUID=$(blkid -s PARTUUID -o value "${LOOP_PART}")

if [[ -z "$PARTUUID" ]]; then
    echo "❌ Falha ao obter PARTUUID"
    exit 1
fi

echo "✅ PARTUUID detectado: $PARTUUID"

# Gerar grub.cfg com PARTUUID
cat > "$MOUNT_POINT/boot/grub/grub.cfg" << EOF
set default=0
set timeout=5
insmod part_msdos
insmod ext2

menuentry "Vëra Linux 6.10.5 (Musl)" {
    set root='hd0,msdos1'
    linux /boot/vmlinuz-6.10.5-vera root=PARTUUID=${PARTUUID} ro quiet loglevel=3
}
EOF

# ──────────────────────────────────────────────────────────────
# 5. INSTALAR GRUB NO MBR
# ──────────────────────────────────────────────────────────────
echo "🐧 Instalando GRUB no MBR da imagem..."
# Usamos o grub-install do HOST para escrever no loop device de forma segura
grub-install \
    --target=i386-pc \
    --boot-directory="$MOUNT_POINT/boot" \
    --recheck \
    "$LOOP_DEV"

# ──────────────────────────────────────────────────────────────
# 6. LANÇAR QEMU
# ──────────────────────────────────────────────────────────────
echo -e "\n${GREEN}✅ Imagem criada com sucesso: $IMG_NAME${NC}"
echo -e "${GREEN}🎉 A Vëra está pronta para o primeiro boot!${NC}"
echo -e "\n🖥️  Iniciando QEMU... (Pressiona Ctrl+C para sair)"

# Executa QEMU
qemu-system-x86_64 \
    -drive file="$IMG_NAME",format=raw,if=virtio \
    -m 2048 \
    -boot order=c \
    -serial stdio \
    -no-reboot \
    -d cpu_reset,guest_errors \
    -D qemu.log