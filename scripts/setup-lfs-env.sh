#!/usr/bin/env bash
# setup-lfs-env.sh - Monta $LFS e configura o ambiente de build Vëra
# Filosofia: explícito, idempotente, zero magia, ativado sob comando.
# Uso OBRIGATÓRIO: source ~/vera-workspace/scripts/setup-lfs-env.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LFS_IMG="${WORKSPACE_DIR}/lfs.img"
LFS_MOUNT="/mnt/lfs"

log() { echo "[vera-setup] $(date '+%H:%M:%S') $*"; }

# Validação inicial
[[ -f "$LFS_IMG" ]] || { log "❌ ERRO: Imagem $LFS_IMG não encontrada."; return 1 2>/dev/null || exit 1; }

# Garante ponto de montagem
mkdir -p "$LFS_MOUNT" 2>/dev/null || true

# Monta apenas se necessário
if ! mountpoint -q "$LFS_MOUNT" 2>/dev/null; then
    log "🔗 Montando $LFS_IMG em $LFS_MOUNT..."
    sudo mount -o loop "$LFS_IMG" "$LFS_MOUNT" || { log "❌ Falha ao montar imagem."; return 1 2>/dev/null || exit 1; }
    log "✅ Montado com sucesso."
else
    log "ℹ️  $LFS_MOUNT já está montado."
fi

# Ajusta permissões (apenas se o dono atual não for o utilizador corrente)
CURRENT_OWNER=$(stat -c '%U' "$LFS_MOUNT" 2>/dev/null || echo "unknown")
if [[ "$CURRENT_OWNER" != "$USER" ]]; then
    log "🔑 Ajustando proprietário de $LFS_MOUNT para $USER..."
    sudo chown "$USER:$USER" "$LFS_MOUNT"
fi

# Exporta variável
export LFS="$LFS_MOUNT"
log "✅ \$LFS definido: $LFS"

# Carrega o ambiente de build oficial (se existir)
ENV_SCRIPT="$SCRIPT_DIR/build/00-env.sh"
if [[ -f "$ENV_SCRIPT" ]]; then
    source "$ENV_SCRIPT"
else
    log "⚠️  00-env.sh não encontrado. Ambiente de build não carregado automaticamente."
fi

log "🎉 Ambiente Vëra pronto. Próximo: sudo $WORKSPACE_DIR/scripts/build/07-enter-chroot.sh"