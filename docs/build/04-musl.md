

### 📄 `docs/build/04-musl.md`

# 04-musl.sh — Compilação e Instalação da Musl Libc

**Script:** `scripts/build/04-musl.sh`  
**Fase:** 1 — Fundação da Toolchain (Substituição da glibc)  
**Execução:** No HOST  
**Status:** ✅ Produzido, testado e validado com verificação de `libc.so`  

---

## 🎯 Objectivo & Contexto Arquitectural

A **Musl libc** é o coração do sistema Vëra. Substitui a glibc por uma implementação mais leve, rápida, segura e estritamente conformante com POSIX/SUS. 
Este script compila a Musl contra os Linux Headers instalados e o GCC Pass 1, criando a biblioteca padrão C que todos os binários futuros irão linkar. 
A escolha da Musl elimina dependências circulares, simplifica o linking estático, e reduz drasticamente a pegada de memória.

---

## 🧠 Decisões de Design & Filosofia Vëra

| Decisão | Justificação Técnica | Alinhamento Vëra |
|---------|----------------------|------------------|
| **Musl em vez de glibc** | Menor código (~150k vs ~1M LOC), mais segura, melhor suporte a estático, sem "symbol versioning hell". | Minimalismo. Segurança. Transparência. |
| `--prefix=/usr` + `DESTDIR="$LFS"` | Instala no path padrão FHS, mas staged em `$LFS`. Evita paths estranhos como `/tools/lib`. | Compatibilidade FHS. Isolamento via DESTDIR. |
| `--disable-werror` | Compiladores modernos são agressivos com warnings. Musl é conservadora; warnings não devem abortar a build. | Pragmatismo. Foco na funcionalidade. |
| Validação de `libc.so` | Symlink crítico. Confirma que a biblioteca partilhada e o linker dinâmico foram instalados correctamente. | Checkpoint de integridade. |
| Build single-pass | Musl não requer multi-pass como a glibc. Mais rápido e menos propenso a erros. | Eficiência. Simplicidade. |

---

## 🔄 Workflow Detalhado

1. **Validação:** Confirma `$LFS`, `$LFS_TGT`, tarball da Musl.
2. **Extracção:** Descomprime `musl-${VER}.tar.gz`.
3. **Configuração:** `./configure --prefix=/usr --target=$LFS_TGT --disable-werror`.
4. **Compilação:** `make -j$(nproc)`. Musl é rápida (~1-2 min em CPU moderna).
5. **Instalação Staged:** `make DESTDIR="$LFS" install`. Coloca ficheiros em `$LFS/usr/`, `$LFS/lib/`.
6. **Validação:** Verifica existência de `libc.so` e estrutura de symlinks.
7. **Limpeza:** Remove fontes temporárias.

---

## 🔍 Análise Profunda das Flags & Arquitectura Musl

```bash
./configure \
    --prefix=/usr \              # Path padrão para libs e headers
    --target="$LFS_TGT" \        # Arquitectura alvo
    --disable-werror             # Tolerância a warnings do host compiler

make DESTDIR="$LFS" install
# Staging é crucial. Instala em $LFS/usr/lib, $LFS/lib, $LFS/usr/include
# Cria automaticamente:
#   /lib/ld-musl-x86_64.so.1 -> libc.so
#   /usr/lib/libc.so -> ../../lib/libc.so
```

**Nota Arquitectural:** A Musl usa um único ficheiro `libc.so` que contém tanto a biblioteca partilhada como o linker dinâmico (`ld-musl-*.so.1`). Isto simplifica drasticamente a gestão de runtime comparado com a glibc.

---

## 🛠️ Troubleshooting & Mitigações

| Sintoma | Causa Raiz | Solução Vëra |
|---------|------------|--------------|
| `error: 'struct statx' has no member named 'stx_mnt_id'` | Headers do kernel desactualizados ou incompatíveis. | Garantir que `03-linux-headers.sh` usou kernel >= 6.1. |
| `make: *** [Makefile:xx] Error 1` durante compilação | Host compiler muito antigo ou flags incompatíveis. | `--disable-werror` resolve 95% dos casos. Actualizar host se persistir. |
| `libc.so` não encontrado após install | `DESTDIR` mal aplicado ou prefix errado. | Verificar `find $LFS -name "libc.so*"`. Deve estar em `$LFS/lib/`. |
| Binários compilados dão `No such file or directory` | Interpreter `/lib/ld-musl-x86_64.so.1` em falta ou symlink quebrado. | Validar symlinks em `$LFS/lib/`. O script já verifica isto. |

---

## ✅ Validação Pós-Execução

```bash
# 1. Verificar biblioteca principal
ls -lh $LFS/lib/libc.so
# lrwxrwxrwx 1 root root 12 ... libc.so -> libc.so.1

# 2. Verificar linker dinâmico
ls -lh $LFS/lib/ld-musl-x86_64.so.1
# lrwxrwxrwx 1 root root 12 ... ld-musl-x86_64.so.1 -> libc.so

# 3. Testar compilação contra Musl
echo 'int main(){return 0;}' > test.c
$LFS_TGT-gcc -o test test.c
readelf -l test | grep interpreter
# [Requesting program interpreter: /lib/ld-musl-x86_64.so.1]
rm -f test test.c

# 4. Espaço ocupado
du -sh $LFS/lib $LFS/usr/lib
# Musl é leve: ~2-3MB total
```

---

## 🔗 Integração no Roadmap (Fase 1)
- **Bloqueia:** `05-gcc-pass2.sh` (GCC precisa da libc real para compilar libstdc++ e threading)
- **Dependência:** Linux API Headers, GCC Pass 1
- **Próximo Marco:** Libc instalada. Toolchain pronta para compilação completa.