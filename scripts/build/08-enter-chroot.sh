#!/usr/bin/env bash
# 08-enter-chroot.sh - LFS 12.2 Cap. 7.4: Entrar no chroot
# Filosofia: usa APENAS /tools/bin — zero dependências do host dentro do chroot.
# IMPORTANTE: correr APÓS 08-prepare-chroot-env.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
LOG_DIR="${WORKSPACE_DIR}/logs/build"
mkdir -p "$LOG_DIR"
LOG_FILE="${LOG_DIR}/07-chroot.log"

log() { echo "[vera-build] $(date '+%Y-%m-%d %H:%M:%S') $*" | tee -a "$LOG_FILE"; }

[[ $EUID -ne 0 ]] && { log "❌ ERRO: Requer root. Executa: sudo $0"; exit 1; }

export LFS="${LFS:-/mnt/lfs}"
[[ -d "$LFS" ]] || { log "❌ ERRO: \$LFS ($LFS) não existe."; exit 1; }

# Validar que /tools/bin/bash existe — é o único bash que usamos
# ──────────────────────────────────────────────────────────────
# VALIDAÇÃO CORRIGIDA (Alinhada com LFS 12.2 Cap. 6.2)
# ──────────────────────────────────────────────────────────────
# Verifica a toolchain (gcc), NÃO o bash
if [[ ! -x "$LFS/tools/bin/${LFS_TGT}-gcc" ]]; then
    log "❌ ERRO: Toolchain em \$LFS/tools incompleta."
    log "💡 Executa 01 → 02 → 03 → 04 → 05 → 06 primeiro."
    exit 1
fi

log "✅ Toolchain validada. Entrando no chroot Vëra..."
log "💡 Sair: 'exit' ou 'Ctrl+D'"
log "📝 Após sair: 'sudo ~/vera-workspace/scripts/build/07-leave-chroot.sh'"

# ──────────────────────────────────────────────────────────────
# MONTAR VFS
# ──────────────────────────────────────────────────────────────
log "✅ Montando VFS..."
mkdir -pv "$LFS"/{proc,sys,dev,dev/pts,run}
mountpoint -q "$LFS/proc"    || mount -t proc    proc    "$LFS/proc"
mountpoint -q "$LFS/sys"     || mount -t sysfs   sysfs   "$LFS/sys"
mountpoint -q "$LFS/run"     || mount -t tmpfs   tmpfs   "$LFS/run"
mountpoint -q "$LFS/dev"     || mount --bind /dev        "$LFS/dev"
mountpoint -q "$LFS/dev/pts" || mount --bind /dev/pts    "$LFS/dev/pts"
log "✅ VFS montados."

# Validar que o interpreter do musl existe
MUSL_LD="$LFS/lib/ld-musl-x86_64.so.1"
if [[ ! -f "$MUSL_LD" ]]; then
    log "❌ ERRO: Interpreter do musl não encontrado: $MUSL_LD"
    log "💡 Verifica se 04-musl.sh instalou correctamente"
    exit 1
fi
log "✅ Interpreter musl válido: $MUSL_LD"

# ──────────────────────────────────────────────────────────────
# MONTAR SOURCES (bind mount — sem duplicar tarballs)
# ──────────────────────────────────────────────────────────────
SOURCES_HOST="${WORKSPACE_DIR}/sources"
if [[ -d "$SOURCES_HOST" ]]; then
    if mountpoint -q "$LFS/sources" 2>/dev/null; then
        log "✅ Sources já montados."
    else
        mount --bind "$SOURCES_HOST" "$LFS/sources"
        log "✅ Sources montados: $SOURCES_HOST → $LFS/sources"
    fi
else
    log "⚠️  $SOURCES_HOST não existe — /sources estará vazio no chroot."
fi
 
log "🚀 Entrando no chroot Vëra..."
log "💡 Sair: 'exit' ou 'Ctrl+D'"
log "📝 Após sair: 'sudo -E ~/vera-workspace/scripts/build/09-leave-chroot.sh'"
log ""
# Entra com /tools/bin/env e /tools/bin/bash — ZERO dependências do host
# Ambiente completamente limpo: só as variáveis que o LFS exige

# Remove 'exec' se quiseres que o script continue para desmontar depois (opcional)
# Mantemos 'exec' para substituir o shell actual e evitar processos orfãos
exec env -i \
    HOME=/root \
    TERM="$TERM" \
    PS1='\[\033[1;35m\](vera chroot)\[\033[0m\] \[\033[1;32m\]\u\[\033[0m\]:\[\033[1;34m\]\w\[\033[0m\]\$ ' \
    PATH=/tools/bin:/usr/bin \
    chroot "$LFS" /usr/bin/bash --login