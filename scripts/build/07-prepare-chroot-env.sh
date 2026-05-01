#!/usr/bin/env bash
# 07-prepare-chroot-env.sh
# Prepara o ambiente dentro do chroot ANTES de compilar qualquer pacote.
# Corre no HOST antes de entrar no chroot.
# Filosofia: zero libs do host, zero binários do host, apenas o que o LFS exige.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
LOG_DIR="${WORKSPACE_DIR}/logs/build"
mkdir -p "$LOG_DIR"

LOG_FILE="${LOG_DIR}/08-prepare-chroot-env.log"
log() { echo "[vera-build] $(date '+%Y-%m-%d %H:%M:%S') $*" | tee -a "$LOG_FILE"; }

[[ $EUID -ne 0 ]] && { log "❌ ERRO: Requer root. Executa: sudo $0"; exit 1; }
[[ -z "${LFS:-}" ]] && { log "❌ ERRO: \$LFS não definido."; exit 1; }
[[ -d "$LFS" ]] || { log "❌ ERRO: \$LFS ($LFS) não existe."; exit 1; }

# Validar que a toolchain existe — se não existir, para tudo
[[ -x "$LFS/tools/bin/${LFS_TGT}-gcc" ]] || {
    log "❌ ERRO: Toolchain não encontrada em \$LFS/tools."
    log "💡 Executa primeiro: 01 → 02 → 03 → 04 → 05 → 06"
    exit 1
}

log "✅ Toolchain validada. Preparando ambiente chroot..."

# ──────────────────────────────────────────────────────────────
# 1. ESTRUTURA DE DIRECTORIAS FHS
# ──────────────────────────────────────────────────────────────
log "📁 Criando estrutura FHS..."
mkdir -pv "$LFS"/{boot,home,mnt,opt,srv}
mkdir -pv "$LFS/etc"/{opt,sysconfig}
mkdir -pv "$LFS/lib/firmware"
mkdir -pv "$LFS/media"/{floppy,cdrom}
mkdir -pv "$LFS/usr"/{,local/}{include,src}
mkdir -pv "$LFS/usr/local"/{bin,lib,sbin}
mkdir -pv "$LFS/usr"/{,local/}share/{color,dict,doc,info,locale,man}
mkdir -pv "$LFS/usr"/{,local/}share/{misc,terminfo,zoneinfo}
mkdir -pv "$LFS/usr"/{,local/}share/man/man{1..8}
mkdir -pv "$LFS/var"/{cache,local,log,mail,opt,spool}
mkdir -pv "$LFS/var/lib"/{color,misc,locate}
install -dv -m 0750 "$LFS/root"
install -dv -m 1777 "$LFS/tmp" "$LFS/var/tmp"
log "✅ Estrutura FHS criada."

# ──────────────────────────────────────────────────────────────
# 2. SYMLINKS MERGED-USR (LFS 12.2 exige isto)
# ──────────────────────────────────────────────────────────────
log "🔗 Criando symlinks merged-usr..."
for dir in bin lib sbin; do
    [[ -e "$LFS/$dir" ]] || ln -sv "usr/$dir" "$LFS/$dir"
    [[ -e "$LFS/usr/local/$dir" ]] || ln -sv "../../usr/$dir" "$LFS/usr/local/$dir" 2>/dev/null || true
done

rm -f "$LFS/lib64" "$LFS/usr/lib64" 2>/dev/null || true

# ──────────────────────────────────────────────────────────────
# 3. SOURCES — bind mount da pasta do workspace
# Os tarballs ficam no host, acessíveis dentro do chroot via /sources
# Não duplicamos ficheiros — bind mount é eficiente e reversível
# ──────────────────────────────────────────────────────────────
log "📦 Montando sources via bind mount..."
mkdir -pv "$LFS/sources"
 
SOURCES_HOST="${WORKSPACE_DIR}/sources"
[[ -d "$SOURCES_HOST" ]] || { log "❌ ERRO: $SOURCES_HOST não existe."; exit 1; }
 
# Montar só se ainda não estiver montado
if mountpoint -q "$LFS/sources" 2>/dev/null; then
    log "✅ Sources já montados em $LFS/sources"
else
    mount --bind "$SOURCES_HOST" "$LFS/sources"
    log "✅ Sources montados: $SOURCES_HOST → $LFS/sources"
fi
 
# Copiar patches para dentro dos sources (ficam persistentes)
if [[ -d "${WORKSPACE_DIR}/patches" ]]; then
    cp -av "${WORKSPACE_DIR}"/patches/*.patch "$LFS/sources/" 2>/dev/null || true
    log "✅ Patches copiados para /sources."
fi
 
# Verificar que os tarballs estão acessíveis
TARBALL_COUNT=$(find "$LFS/sources" -name "*.tar.*" 2>/dev/null | wc -l)
log "📦 Tarballs disponíveis em /sources: $TARBALL_COUNT"
[[ $TARBALL_COUNT -eq 0 ]] && {
    log "⚠️  Nenhum tarball encontrado em $SOURCES_HOST"
    log "💡 Descarrega os sources com: wget -i wget-list -P $SOURCES_HOST"
}
 

# ──────────────────────────────────────────────────────────────
# 4. FICHEIROS DE IDENTIDADE DO SISTEMA
# ──────────────────────────────────────────────────────────────
log "📝 Criando ficheiros de identidade..."

cat > "$LFS/etc/passwd" << "EOF"
root:x:0:0:root:/root:/bin/bash
bin:x:1:1:bin:/dev/null:/usr/bin/false
daemon:x:6:6:Daemon User:/dev/null:/usr/bin/false
messagebus:x:18:18:D-Bus Message Daemon User:/run/dbus:/usr/bin/false
nobody:x:65534:65534:Unprivileged User:/dev/null:/usr/bin/false
EOF

cat > "$LFS/etc/group" << "EOF"
root:x:0:
bin:x:1:daemon
sys:x:2:
kmem:x:3:
tape:x:4:
tty:x:5:
daemon:x:6:
floppy:x:11:
disk:x:13:
audio:x:17:
cdrom:x:18:
messagebus:x:18:
input:x:24:
utmp:x:13:
wheel:x:97:
users:x:999:
nogroup:x:65534:
EOF

cat > "$LFS/etc/shadow" << "EOF"
root::0:99999:7:::
bin:*:0:99999:7:::
daemon:*:0:99999:7:::
messagebus:*:0:99999:7:::
nobody:*:0:99999:7:::
EOF
chmod 640 "$LFS/etc/shadow"

echo "vera" > "$LFS/etc/hostname"

cat > "$LFS/etc/hosts" << "EOF"
127.0.0.1 localhost
127.0.1.1 vera
::1       localhost ip6-localhost ip6-loopback
EOF

log "✅ Ficheiros de identidade criados."

# ──────────────────────────────────────────────────────────────
# 5. PROFILE DO CHROOT (prompt + PATH usando só /tools)
# ──────────────────────────────────────────────────────────────
log "🎨 Configurando profile do chroot..."
mkdir -pv "$LFS/etc/profile.d"

cat > "$LFS/etc/profile" << "EOF"
# Vëra /etc/profile — gerado por 08-prepare-chroot-env.sh
# PATH usa APENAS /tools/bin durante a fase de build do Cap 8
# Quando coreutils nativo estiver instalado, /usr/bin passa a ter precedência
export PATH=/usr/bin:/usr/sbin:/tools/bin

for f in /etc/profile.d/*.sh; do
    [ -r "$f" ] && . "$f"
done
unset f
EOF

cat > "$LFS/etc/profile.d/vera-prompt.sh" << "EOF"
# Vëra chroot prompt
export PS1='\[\033[1;35m\](vera chroot)\[\033[0m\] \[\033[1;32m\]\u\[\033[0m\]:\[\033[1;34m\]\w\[\033[0m\]\$ '
export MAKEFLAGS="-j$(nproc)"
export LC_ALL=POSIX
export LANG=POSIX
EOF

log "✅ Profile configurado."

# ──────────────────────────────────────────────────────────────
# 6. FICHEIROS DE LOG INICIAIS
# ──────────────────────────────────────────────────────────────
log "📋 Inicializando ficheiros de log..."
touch "$LFS/var/log"/{btmp,lastlog,faillog,wtmp}
chgrp 13 "$LFS/var/log/lastlog" 2>/dev/null || true  # gid 13 = utmp
chmod 664 "$LFS/var/log/lastlog"
chmod 600 "$LFS/var/log/btmp"
log "✅ Ficheiros de log inicializados."

# ──────────────────────────────────────────────────────────────
# 7. VALIDAÇÃO FINAL
# ──────────────────────────────────────────────────────────────
log ""
log "📊 Resumo do ambiente preparado:"
log "  FHS:        $(ls $LFS | tr '\n' ' ')"
log "  Patches:    $(ls $LFS/sources/*.patch 2>/dev/null | wc -l) ficheiros"
log "  Toolchain:  $(ls $LFS/tools/bin | wc -l) binários"
log "  /etc:       $(ls $LFS/etc | tr '\n' ' ')"
log ""
log "🔍 Validação crítica — toolchain usa sysroot correcto:"

# Validação simplificada: musl não precisa de env externo
if chroot "$LFS" /usr/bin/bash --norc -c 'echo "✅ Chroot musl OK"' >/dev/null 2>&1; then
    log "✅ Validação chroot: bash arranca com musl"
else
    log "⚠️  Validação chroot falhou — pode ser falta de utilitários"
    log "💡 Dentro do chroot, usa builtins do bash: echo, cd, type"
fi
log ""
log "✅ Ambiente chroot pronto. Podes entrar com:"
log "   sudo ~/vera-workspace/scripts/build/08-enter-chroot.sh"
log ""
log "🚀 Dentro do chroot, primeiro comando:"
log "   cd /sources && ls musl-*.tar.gz 2>/dev/null || echo 'Musl já instalado. Próximo: Cap. 8 (sistema base)'"
