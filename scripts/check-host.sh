#!/usr/bin/env bash
# check-host.sh v3 - Valida host para Vëra (LFS 12.2+)
# Filosofia: timeout explícito, falha visível, zero espera infinita.

set -uo pipefail

log()   { echo "[vera-host] $*"; }
ok()    { echo "✅ $*"; }
warn()  { echo "⚠️  $*"; }
fail()  { echo "❌ $*"; }

# Extrai versão tolerante
get_ver() { echo "$1" | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1; }

# Compara: retorna 0 se ver >= min
ver_ge() {
    local min="$1" ver="$2"
    [[ -z "$ver" ]] && return 1
    [[ $(printf '%s\n%s' "$min" "$ver" | sort -V | head -n1) == "$min" ]]
}

check() {
    local name="$1" cmd="$2" min="$3" flags="${4---version}"
    local out ver

    # timeout 2s evita hangs silenciosos
    out=$(timeout 2 $cmd $flags 2>&1 | head -n1 || echo "__TIMEOUT_OR_FAIL__")
    ver=$(get_ver "$out")

    if [[ "$out" == *"__TIMEOUT_OR_FAIL__"* ]] || [[ -z "$ver" ]]; then
        warn "$name: falhou ou versão não detectada (cmd: '$cmd $flags')"
        return 1
    fi

    if ver_ge "$min" "$ver"; then ok "$name: $ver (mín: $min)"; return 0
    else warn "$name: $ver (mín exigido: $min)"; return 1
    fi
}

log "Verificando host system (LFS 12.2+)..."
echo ""

check "Bash" "bash" "3.2"
check "Binutils" "ld" "2.38"
check "Bzip2" "bzip2" "1.0.4"
check "Coreutils" "chown" "8.32"
check "Diffutils" "diff" "3.3"
check "Findutils" "find" "4.4.0"
check "Gawk" "gawk" "4.1.0"
check "GCC" "gcc" "11.2"
check "GCC-C++" "g++" "11.2"
check "Glibc" "ldd" "2.27"
check "Grep" "grep" "2.5.1a"
check "Gzip" "gzip" "1.10"
check "Linux" "uname" "4.19" "-r"
check "Make" "make" "4.3"
check "Patch" "patch" "2.7.6"
check "Perl" "perl" "5.8.8"
check "Python3" "python3" "3.4" "--version"
check "Sed" "sed" "4.2.2"
check "Tar" "tar" "1.29" "--version"
check "Texinfo" "makeinfo" "5.0" "--version"
check "Xz" "xz" "5.0.0"

echo ""
log "Validação concluída. Revise ⚠️ e ❌ antes de avançar."
log "Dica: instala pacotes em falta via gestor do host (apt/pacman/dnf)."
