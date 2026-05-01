

### 📄 `docs/build/10-build-base-system.md`

# 10-build-base-system.sh — Sistema Base Completo (Musl)

**Script:** `scripts/build/10-build-base-system.sh`  
**Fase:** 1 — Sistema Base Bootável  
**Execução:** Dentro do chroot  
**Status:** ✅ Produzido e testado  



## Objectivo

Compilar e instalar o sistema base completo da Vëra dentro do chroot, incluindo `util-linux`, `e2fsprogs`, `shadow`, `pkgconf`, `procps-ng`, `psmisc`, `kbd`, `kmod`, `sysvinit`, e dependências críticas (`gzip`, `iana-etc`). Este passo transforma o chroot num sistema Linux funcional.

---

## Decisões de design

| Decisão | Motivo |
|---------|--------|
| Toolchain musl explícita (`CC=x86_64-linux-musl-gcc`) | Garante que todos os binários são linkados contra musl, não glibc. |
| `--disable-static` global | Reduz tamanho do sistema. Shared libs apenas. |
| `--disable-nls` global | Remove internacionalização. Sistema mais leve e rápido. |
| `LDFLAGS="-Wl,-rpath-link=/usr/lib"` | Resolve dependências circulares sem modificar `ldconfig`. |
| Compilação sequencial com `log()` | Cada pacote é logado. Falha rápida com contexto. |

---

## Workflow do script

1. Compila `gzip` (pré-requisito para `tar`)
2. Instala `iana-etc` (services/protocols)
3. Compila `util-linux` (mount, fdisk, blkid, etc.)
4. Compila `e2fsprogs` (mkfs.ext4, fsck, etc.)
5. Compila `shadow` (passwd, chpasswd, login)
6. Compila `pkgconf` (pkg-config alternativo)
7. Compila `procps-ng` (ps, top, free, etc.)
8. Compila `psmisc` (killall, fuser, pstree)
9. Compila `kbd` (loadkeys, setfont)
10. Compila `kmod` (modprobe, lsmod)
11. Compila `sysvinit` (init, shutdown, reboot)

---

## Problemas encontrados e soluções

### 1. `kdb` falha a compilar `tests`
**Causa:** O Makefile gerado tenta compilar `tests` que exigem `autom4te` (não disponível).  
**Solução:** `sed -i 's/ tests//g' Makefile`  
**Lição:** Pacotes com suites de teste exigem dependências de build extras.

### 2. `shadow` falha com `libbsd`
**Causa:** `shadow` tenta linkar contra `libbsd` (não disponível em musl).  
**Solução:** `--without-libbsd ac_cv_func_readpassphrase=no`  
**Resultado:** Usa fallback interno. Funciona em musl.

### 3. `e2fsprogs` instala binários em `/usr/sbin`
**Causa:** `e2fsprogs` instala `mkfs.ext4` em `/usr/sbin` por defeito.  
**Solução:** `--with-root-prefix=`  
**Lição:** Pacotes de sistema base exigem prefixos específicos.

---

## Validação pós-execução
```bash
# Dentro do chroot:
which mount mkfs.ext4 passwd ps killall loadkeys modprobe init
# /usr/bin/mount
# /usr/sbin/mkfs.ext4
# /usr/bin/passwd
# ...

# Teste funcional:
mkfs.ext4 -V    # mke2fs 1.47.1
ps --version    # ps from procps-ng 4.0.4
init --version  # sysvinit 3.10
```

---

## Notas para a Fase 2
- O `sysvinit` será reavaliado. OpenRC ou runit podem ser adoptados na Fase 3
- O `--disable-nls` será removido quando `gettext` for compilado
- O `kmod` será substituído por módulos nativos do kernel quando possível

---

**Dependência anterior:** `09-bootstrap-tools.sh`  
**Próximo passo:** `11-build-kernel.sh` (kernel Linux)
```

---

### 📋 Resumo da estrutura gerada
| Ficheiro | Caminho | Conteúdo |
|----------|---------|----------|
| `08-enter-chroot.md` | `docs/build/08-enter-chroot.md` | ✅ Isolamento, VFS, clean env |
| `09-bootstrap-tools.md` | `docs/build/09-bootstrap-tools.md` | ✅ Cross-compile, 12 utilitários, strip |
| `10-build-base-system.md` | `docs/build/10-build-base-system.md` | ✅ Musl toolchain, 11 pacotes base, fixes |

Podes copiar cada bloco directamente para os ficheiros correspondentes. Estão prontos para integração no teu repositório. 🐧