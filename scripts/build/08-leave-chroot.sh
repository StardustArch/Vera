#!/usr/bin/env bash
# 08-leave-chroot.sh - Desmonta VFS de forma segura e ordenada
# Filosofia: explícito, fail-safe, ordem inversa de montagem.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
LOG_DIR="${WORKSPACE_DIR}/logs/build"
mkdir -p "$LOG_DIR"
LOG_FILE="${LOG_DIR}/07-chroot.log"

log() { echo "[vera-unmount] $(date '+%Y-%m-%d %H:%M:%S') $*" | tee -a "$LOG_FILE"; }

if [[ $EUID -ne 0 ]]; then
    log "❌ ERRO: Requer root. Executa: sudo $0"; exit 1
fi

export LFS="${LFS:-/mnt/lfs}"

log "🔄 Desmontando filesystems virtuais (ordem inversa)..."
umount -v "$LFS/dev/pts" 2>/dev/null || true
umount -v "$LFS/dev"     2>/dev/null || true
umount -v "$LFS/run"     2>/dev/null || true
umount -v "$LFS/sys"     2>/dev/null || true
umount -v "$LFS/proc"    2>/dev/null || true

log "✅ VFS desmontados. Ambiente $LFS isolado e seguro."
log "📊 Espaço usado em \$LFS: $(du -sh "$LFS" 2>/dev/null | awk '{print $1}')"
log "💡 Podes desligar, fazer snapshot ou continuar a compilar no próximo boot."