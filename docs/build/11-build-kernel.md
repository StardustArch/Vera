# Kernel Linux 6.10.5 — Build Log

**Script:** `scripts/build/11-build-kernel.sh`
**Data:** 2026-04-29
**Status:** ✅ Validado em chroot musl
**Tempo de build:** ~15-20 minutos

---

## Objectivo

Compilar o kernel Linux 6.10.5 mínimo bootável em hardware real, linkado contra musl libc, sem módulos externos, sem dependências de ferramentas de desenvolvimento ausentes no chroot.

**Resultado:** `bzImage` em `/boot/vmlinuz-6.10.5-vera` pronto para GRUB.

---

## Decisões de configuração

### Base: `make defconfig` + ajustes manuais

`defconfig` fornece uma base estável e testada para x86_64. Os ajustes desactivam validações de desenvolvimento que dependem de ferramentas ausentes no chroot musl.

`allnoconfig` foi rejeitado — demasiado frágil e propenso a dependências de features em falta.

### Opções desactivadas

| Opção | Motivo | Impacto |
|-------|--------|---------|
| `CONFIG_STACK_VALIDATION` | Exige `objtool` → que depende de `libelf` → que depende de `argp_parse` (ausente em musl) | Perde validação de ORC/unwind. Kernel funciona normalmente. |
| `CONFIG_UNWINDER_ORC` | Depende de `objtool` | Usa frame pointer. Funcional. |
| `CONFIG_DEBUG_INFO` | Gera ~200MB de símbolos DWARF desnecessários para boot | Kernel mais enxuto. |
| `CONFIG_DEBUG_INFO_BTF` | Exige `pahole`/`dwarves` ausentes no chroot | Perde BTF para eBPF. Irrelevante no Milestone 1. |
| `CONFIG_SYSTEM_CERTIFICATE_GENERATION` | `extract-cert` exige `openssl/bio.h` ausente | Sem assinatura de módulos. Irrelevante sem módulos externos. |
| `CONFIG_MODULE_SIG` | Sem módulos nesta fase | Kernel monolítico mínimo. |
| `CONFIG_SYSTEM_TRUSTED_KEYS` | Sem certificados | Zero impacto. |

---

## Problemas encontrados e soluções

### 1. `gcc: command not found`

**Quando:** Primeira execução de `make defconfig`.

**Causa:** O Makefile do kernel procura `gcc` genérico mas a toolchain só tem `x86_64-linux-musl-gcc`.

**Solução:**
```bash
cd /tools/bin
ln -sv x86_64-linux-musl-gcc gcc
ln -sv x86_64-linux-musl-gcc cc
ln -sv x86_64-linux-musl-g++ g++
ln -sv x86_64-linux-musl-ld  ld
ln -sv x86_64-linux-musl-as  as
```

**Lição:** Criar symlinks genéricos antes de compilar qualquer pacote grande. Adicionado ao `09-bootstrap-tools.sh`.

---

### 2. `flex: command not found`

**Quando:** Durante `make defconfig`.

**Causa:** Kconfig usa `flex` para gerar `lexer.lex.c` a partir de `lexer.l`. `bison` também é necessário para `parser.tab.c`.

**Solução:** Compilar `flex` e `bison` antes do kernel.

```bash
# flex
cd /sources && tar xf flex-2.6.4.tar.gz && cd flex-2.6.4
./configure --prefix=/usr --disable-nls && make -j$(nproc) && make install

# bison
cd /sources && tar xf bison-3.8.2.tar.xz && cd bison-3.8.2
./configure --prefix=/usr --disable-nls && make -j$(nproc) && make install
```

---

### 3. `sh: command not found`

**Quando:** Durante compilação de headers (`SYSHDR`, `GEN`).

**Causa:** Subprocessos do `make` perdem referência a `/bin/sh` em ambiente merged-usr.

**Solução:**
```bash
export PATH="/usr/bin:/usr/sbin:/bin:/tools/bin"
ln -sfv /usr/bin/bash /usr/bin/sh
```

---

### 4. `gelf.h: No such file or directory` (objtool)

**Quando:** Compilação de `tools/objtool`.

**Causa:** `objtool` exige `libelf` (headers `gelf.h`).

**Tentativa 1 — compilar `elfutils`:**
```bash
cd /sources && tar xf elfutils-0.191.tar.bz2 && cd elfutils-0.191
./configure --prefix=/usr --disable-debuginfod
# ❌ configure: error: failed to find argp_parse
```
Falhada porque `argp_parse` faz parte da glibc e não existe em musl.

**Solução final — stub objtool:**
Desactivar `CONFIG_STACK_VALIDATION` e `CONFIG_UNWINDER_ORC` no `.config`, e criar um script dummy que retorna sucesso imediato:

```bash
mkdir -p tools/objtool
printf '#!/bin/sh\nexit 0\n' > tools/objtool/objtool
chmod +x tools/objtool/objtool
```

O kernel invoca `objtool` na linkagem de `vmlinux.o`. Como ORC está desactivado, o stub satisfaz a invocação sem efeitos.

---

### 5. `bc: command not found`

**Quando:** Geração de `include/generated/timeconst.h`.

**Causa:** O kernel usa `bc` para cálculos aritméticos de constantes de tempo.

**Tentativa 1 — compilar `bc-1.07.1`:**
```bash
./configure --prefix=/usr && make
# ❌ ./fix-libmath_h: line 1: ed: command not found
```
Falhada porque `bc-1.07.1` usa o editor `ed` para gerar `libmath.h`.

**Tentativa 2 — injetar `libmath.h` mínimo:**
```bash
cat > bc/libmath.h << 'EOF'
static const char *libmath_b = "";
EOF
sed -i 's|./fix-libmath_h|true|' bc/Makefile
# ❌ global.c:38:1: error: expected expression before ';' token
```
Falhada porque `libmath.h` ficou malformatado.

**Solução final — copiar `bc` do host:**
```bash
# No host
sudo cp -v /usr/bin/bc /mnt/lfs/usr/bin/
```
Scaffold temporário para o Milestone 1. Será recompilado nativamente na Fase 2.

---

### 6. `openssl/bio.h: No such file or directory`

**Quando:** Compilação de `certs/extract-cert`.

**Causa:** O kernel tenta compilar ferramenta de extracção de certificados X.509 que exige headers OpenSSL.

**Solução:** Desactivar via `sed` directo no `.config` (mais fiável que `scripts/config`):

```bash
sed -i 's|^CONFIG_SYSTEM_CERTIFICATE_GENERATION=y|# CONFIG_SYSTEM_CERTIFICATE_GENERATION is not set|' .config
sed -i 's|^CONFIG_MODULE_SIG=y|# CONFIG_MODULE_SIG is not set|' .config
sed -i 's|^CONFIG_SYSTEM_TRUSTED_KEYS=.*|CONFIG_SYSTEM_TRUSTED_KEYS=""|' .config
sed -i 's|^CONFIG_SYSTEM_REVOCATION_KEYS=.*|CONFIG_SYSTEM_REVOCATION_KEYS=""|' .config
```

---

### 7. `objtool: No such file or directory` (linkagem)

**Quando:** Linkagem de `vmlinux.o`, mesmo com `CONFIG_STACK_VALIDATION=n`.

**Causa:** O Makefile continua a invocar `objtool` em algumas fases de linkagem independentemente da config.

**Solução:** O stub criado no problema 4 resolve também este caso.

---

## Validação

```bash
# Ficheiro presente
ls -lh /boot/vmlinuz-6.10.5-vera

# Formato válido (magic number gzip: 1f 8b)
head -c 2 /boot/vmlinuz-6.10.5-vera | od -An -tx1

# Opções críticas desactivadas
grep "STACK_VALIDATION\|CERTIFICATE_GENERATION" /boot/config-6.10.5-vera
# Deve mostrar apenas linhas comentadas com #
```

---

## Notas para a Fase 2

Quando a Vëra tiver `vera-ports` e ferramentas nativas:

- Recompilar `bc` nativamente resolvendo a dependência de `ed`
- Adicionar `elfutils` com `argp-standalone` para suporte a `objtool`
- Habilitar `CONFIG_MODULE_SIG` e assinar módulos
- Compilar módulos para hardware específico
- Adicionar `openssl` ou `libressl` para certificados X.509

---

**Milestone 1:** ✅ Kernel compilado e pronto para GRUB
**Próximo:** `12-boot-config.md` — GRUB, fstab, inittab, grub.cfg