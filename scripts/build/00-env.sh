#!/usr/bin/env bash
# 00-env.sh - Configura ambiente de sessão para LFS Cap. 5 (Toolchain Temporária)
# Filosofia: explícito, isolado, validado, zero poluição do host.
# Uso OBRIGATÓRIO: source ~/vera-workspace/scripts/build/00-env.sh

# ──────────────────────────────────────────────────────────────
# VALIDAÇÃO INICIAL
# ──────────────────────────────────────────────────────────────
if [[ -z "${LFS:-}" ]]; then
    echo "[vera-env] ❌ ERRO: \$LFS não está definido." >&2
    echo "[vera-env] 💡 Executa antes: export LFS=/mnt/lfs" >&2
    return 1 2>/dev/null || exit 1
fi

if [[ ! -d "$LFS" || ! -w "$LFS" ]]; then
    echo "[vera-env] ❌ ERRO: \$LFS ($LFS) não existe ou não tem permissão de escrita." >&2
    return 1 2>/dev/null || exit 1
fi

log() { echo "[vera-env] ✅ $*"; }

# ──────────────────────────────────────────────────────────────
# CONFIGURAÇÃO EXPLÍCITA (LFS 12.2 Cap. 5)
# ──────────────────────────────────────────────────────────────

# Desativa hash da shell: força busca no PATH a cada comando (evita usar binários antigos em cache)
set +h

# Mascara padrão: ficheiros criados com permissões seguras (rwxr-xr-x / rw-r--r--)
umask 022


# Locale neutro: evita bugs de i18n/gconv durante compilação de glibc/gcc
export LC_ALL=POSIX
export LANG=POSIX

# Limpa variáveis do host que costumam quebrar builds LFS
unset -v LD_LIBRARY_PATH LDFLAGS CFLAGS CXXFLAGS CPPFLAGS PKG_CONFIG_PATH

# PATH limpo: tools primeiro, depois host /usr/bin (e /bin se não for symlink)
export PATH="$LFS/tools/bin:/usr/bin"
[[ ! -L /usr/bin ]] && export PATH="/bin:$PATH"

# Shell explícita para scripts de build
export CONFIG_SHELL=/bin/bash

# Paralelismo explícito (usa todos os cores físicos disponíveis)
export MAKEFLAGS="-j$(nproc)"

# Exporta tudo para sub-processos
export LFS  LC_ALL LANG PATH CONFIG_SHELL MAKEFLAGS

export LFS=/mnt/lfs
export LFS_TGT="x86_64-linux-musl"
export MAKEFLAGS="-j$(nproc)"
export LC_ALL=POSIX
export CONFIG_SHELL=/bin/bash
export PATH="/tools/bin:/usr/bin:$PATH"

# ──────────────────────────────────────────────────────────────
# VALIDAÇÃO FINAL & FEEDBACK
# ──────────────────────────────────────────────────────────────
log "Ambiente configurado para sessão atual:"
log "  LFS=$LFS"
log "  LFS_TGT=$LFS_TGT"
log "  LC_ALL=$LC_ALL"
log "  MAKEFLAGS=$MAKEFLAGS"
log "  CONFIG_SHELL=$CONFIG_SHELL"
log "  PATH inicia com: $(echo $PATH | cut -d: -f1,2)"
log ""
log "💡 Validação rápida: env | grep -E '^(LFS|PATH|LC_ALL|MAKEFLAGS|CONFIG_SHELL)='"
log "🛠️  Próximo: ./scripts/build/01-binutils-pass1.sh"
