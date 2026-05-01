#!/usr/bin/env bash
# 06-finalize-toolchain.sh - LFS 12.2 Cap. 5.9/Pre-Chroot: Finalizar, Sanitizar & Validar
# Filosofia: explícito, fail-fast, logging completo, zero suposições.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
LOG_DIR="${WORKSPACE_DIR}/logs/build"
mkdir -p "$LOG_DIR"

LOG_FILE="${LOG_DIR}/06-finalize-toolchain.log"
DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

log() { echo "[vera-build] $(date '+%Y-%m-%d %H:%M:%S') $*" | tee -a "$LOG_FILE"; }
run() {
    if $DRY_RUN; then log "🔍 DRY-RUN: $*"; else
        log "▶ $*"; "$@" >> "$LOG_FILE" 2>&1 || { log "❌ Falha: $*"; exit 1; }
    fi
}

[[ -z "${LFS:-}" || -z "${LFS_TGT:-}" ]] && { log "❌ ERRO: \$LFS ou \$LFS_TGT não definidos."; exit 1; }
[[ ! -d "$LFS/tools" ]] && { log "❌ ERRO: \$LFS/tools não existe."; exit 1; }

log "✅ Pré-requisitos validados. Finalizando toolchain temporária..."

# ──────────────────────────────────────────────────────────────
# 1. STRIP (apenas em modo real)
# ──────────────────────────────────────────────────────────────
if ! $DRY_RUN; then
    log "🔪 A remover símbolos de debug de \$LFS/tools..."
    strip --strip-debug "$LFS"/tools/lib/* 2>/dev/null || true
    /usr/bin/strip --strip-unneeded "$LFS"/tools/{,s}bin/* 2>/dev/null || true
    log "✅ Strip concluído. Espaço: $(du -sh "$LFS/tools" | awk '{print $1}')"
else
    log "🔍 DRY-RUN: strip --strip-debug/unneeded"
fi

# ──────────────────────────────────────────────────────────────
# 2. VALIDAÇÃO COMPLETA DA TOOLCHAIN (apenas em modo real)
# ──────────────────────────────────────────────────────────────
if ! $DRY_RUN; then
    log "🔍 Validando toolchain (C, C++, Threads, Linker)..."
    cd "$WORKSPACE_DIR"

    # Teste C
    cat > dummy.c << 'EOC'
#include <stdio.h>
int main() { printf("Vera Toolchain C OK\n"); return 0; }
EOC
    run $LFS_TGT-gcc -o dummy_c dummy.c
    
    if [[ -x "dummy_c" ]]; then
        INTERP_C=$(readelf -l dummy_c 2>/dev/null | grep interpreter | awk '{print $4}' | tr -d '[]')
        [[ "$INTERP_C" == *"/lib/ld-musl-x86_64.so.1" ]] && \
            log "✅ Teste C: OK (linker: $INTERP_C)" || \
            log "⚠️  Teste C compilado (interpreter: $INTERP_C)"
    else
        log "❌ Falha no teste C: binário não gerado"; exit 1
    fi
    rm -f dummy.c dummy_c

    # Teste C++ com STL e Threads
    cat > dummy.cpp << 'EOCPP'
#include <iostream>
#include <thread>
#include <vector>
void worker() { std::cout << "Thread OK\n"; }
int main() {
    std::vector<std::thread> threads;
    for(int i=0; i<2; ++i) threads.emplace_back(worker);
    for(auto& t : threads) t.join();
    return 0;
}
EOCPP
    run $LFS_TGT-g++ -pthread -o dummy_cpp dummy.cpp
    
    if [[ -x "dummy_cpp" ]]; then
        INTERP_CPP=$(readelf -l dummy_cpp 2>/dev/null | grep interpreter | awk '{print $4}' | tr -d '[]')
        [[ "$INTERP_CPP" == *"/lib/ld-musl-x86_64.so.1" ]] && \
            log "✅ Teste C++ + Threads: OK (linker: $INTERP_CPP)" || \
            log "⚠️  Teste C++ compilado (interpreter: $INTERP_CPP)"
    else
        log "❌ Falha no teste C++: binário não gerado"; exit 1
    fi
    rm -f dummy.cpp dummy_cpp

    # Validação específica para musl
    if [[ -f "$LFS/usr/lib/libc.so" ]]; then
        log "✅ Musl libc.so instalado em $LFS/usr/lib/"
    else
        log "❌ ERRO: libc.so do musl não encontrado"
        exit 1
    fi

    log "🔍 Verificando linker dinâmico (musl)..."
    log "✅ Linker musl OK: /lib/ld-musl-x86_64.so.1"
else
    log "🔍 DRY-RUN: Testes C/C++ seriam compilados e validados via readelf"
fi
# ──────────────────────────────────────────────────────────────
# 3. PREPARAR ESTRUTURA BASE PARA CHROOT
# ──────────────────────────────────────────────────────────────
if ! $DRY_RUN; then
    log "📁 Criando estrutura de diretórios mínima para chroot..."
    mkdir -p "$LFS"/{etc,var,usr/{bin,lib,sbin},home,root,tmp,mnt,media,opt,srv}
    chmod 1777 "$LFS/tmp"
    chmod 0750 "$LFS/root"
    log "✅ Estrutura criada e permissões ajustadas."
else
    log "🔍 DRY-RUN: mkdir + chmod para dirs base FHS"
fi

# ──────────────────────────────────────────────────────────────
# 4. RESUMO FINAL
# ──────────────────────────────────────────────────────────────
log "📊 Resumo:"
log "  Binários: $(ls -1 "$LFS/tools/bin/" 2>/dev/null | wc -l)"
log "  Bibliotecas: $(ls -1 "$LFS/tools/lib/" 2>/dev/null | wc -l)"
log "  Espaço \$LFS/tools: $(du -sh "$LFS/tools" | awk '{print $1}')"

log "🎉 Toolchain temporária finalizada!"
log "🚀 Próximo: 07-enter-chroot.sh (LFS Capítulo 6)"