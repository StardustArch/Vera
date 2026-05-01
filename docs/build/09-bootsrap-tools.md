
### 📄 `docs/build/09-bootstrap-tools.md`

# 09-bootstrap-tools.sh — Bootstrap de Utilitários Essenciais

**Script:** `scripts/build/09-bootstrap-tools.sh`  
**Fase:** 1 — Sistema Base Bootável  
**Execução:** No HOST (antes de entrar no chroot)  
**Status:** ✅ Produzido e testado  

---

## Objectivo

Compilar e instalar um conjunto mínimo de utilitários (`tar`, `make`, `coreutils`, `xz`, `grep`, `sed`, `gawk`, `patch`, `diffutils`, `findutils`, `bzip2`, `zlib`) no ambiente chroot, cross-compilados para `x86_64-linux-musl`. Estes utilitários são necessários para compilar o sistema base completo dentro do chroot.

---

## Decisões de design

| Decisão | Motivo |
|---------|--------|
| Cross-compile para `${LFS_TGT}` | Garante que os binários são compatíveis com musl e não têm dependências do host. |
| `DESTDIR="$LFS" install` | Instala directamente no chroot sem sobrescrever o host. |
| `--disable-nls` em todos os pacotes | Remove suporte a internacionalização (gettext) para reduzir tamanho e complexidade. |
| `strip --strip-unneeded` | Remove símbolos de debug. Reduz tamanho em ~60%. |
| Compilação sequencial com validação | Cada pacote é validado antes do próximo. Falha rápida. |

---

## Workflow do script

1. Valida `$LFS`, `$LFS_TGT`, e toolchain no host
2. Compila `zlib` (dependência crítica)
3. Compila `xz` (para `.tar.xz`)
4. Compila `tar` (extrair sources)
5. Compila `make` (build system)
6. Compila `grep`, `sed`, `gawk`, `patch`, `diffutils`, `findutils`
7. Compila `coreutils` (ls, cp, mv, rm, mkdir, cat, etc.)
8. Compila `bzip2` (para `.tar.bz2`)
9. Valida binários instalados
10. Testa via comando `chroot`

---

## Problemas encontrados e soluções

### 1. Race conditions no `bzip2`
**Causa:** `make -j$(nproc)` no `bzip2` causa race conditions no Makefile antigo.  
**Solução:** `make -j1 CC="$CC" AR="$AR" ...`  
**Lição:** Pacotes com Makefiles antigos exigem compilação sequencial.

### 2. `coreutils` falha em cross-compile
**Causa:** `coreutils` tenta compilar programas que exigem `kill` e `uptime` do host.  
**Solução:** `--enable-no-install-program=kill,uptime`  
**Resultado:** Compilação limpa, sem dependências circulares.

### 3. Bibliotecas partilhadas em falta
**Causa:** `bzip2` não instala `libbz2.so` por defeito.  
**Solução:** Instalação manual de `libbz2.so.1.0.8` e criação de symlinks em `$LFS/usr/lib/`.  
**Lição:** Pacotes antigos exigem instalação manual de shared libs.

---

## Validação pós-execução
```bash
# Dentro do chroot:
for bin in tar make grep sed gawk patch find xargs ls cp mv rm mkdir cat head; do
    [[ -x "/usr/bin/$bin" ]] && echo "✅ $bin" || echo "❌ $bin"
done

# Teste funcional:
tar --version | head -1   # tar (GNU tar) 1.35
make --version | head -1  # GNU Make 4.4.1
```

---

## Notas para a Fase 2
- Estes utilitários são temporários. Na Fase 2, serão substituídos por versões finais compiladas com `vpm`
- O `--disable-nls` será reavaliado quando `gettext` for compilado
- O `strip` será opcional em builds de debug

---

