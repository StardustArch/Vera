

### 📄 `docs/build/05-gcc-pass2.md`

# 05-gcc-pass2.sh — GCC Pass 2 (Toolchain Completa com libstdc++)

**Script:** `scripts/build/05-gcc-pass2.sh`  
**Fase:** 1 — Finalização da Toolchain (LFS Cap. 5.8)  
**Execução:** No HOST  
**Status:** ✅ Produzido, validado com teste C++ e verificação de interpreter Musl  

---

## 🎯 Objectivo & Contexto Arquitectural

O **GCC Pass 2** é a reconstrução completa do compilador, agora contra a Musl libc real e com suporte total a C++, threading POSIX, bibliotecas partilhadas e hardening moderno. 
Este passo substitui o bootstrap mínimo do Pass 1 por um compilador de produção, capaz de gerar binários finais para a Vëra. É o **último componente da toolchain temporária** antes de entrarmos no chroot.

---

## 🧠 Decisões de Design & Filosofia Vëra

| Decisão | Justificação Técnica | Alinhamento Vëra |
|---------|----------------------|------------------|
| **Recompilação completa (Pass 2)** | O Pass 1 foi compilado sem libc. O Pass 2 liga contra a Musl real, garantindo consistência e suporte a C++/threads. | Coerência. Binários de produção desde o dia 1. |
| `--enable-shared` + `--enable-threads=posix` | Activa libstdc++.so e pthreads. Essencial para software moderno (Python, Node, Rust, etc.). | Compatibilidade. Modernidade. |
| `--enable-__cxa_atexit` | Requerido pela especificação C++ ABI para destrutores de estáticos. Evita memory leaks em C++. | Conformidade standard. Robustez. |
| `--enable-default-pie` / `--enable-default-ssp` | Hardening activo por defeito. ASLR e stack protection em todos os binários gerados. | Segurança by design. |
| Validação com `readelf` pós-build | Confirma que o compiler gera binários que procuram o interpreter Musl, não o do host. | Verificação criptográfica. Zero trust. |
| Flag `--no-clean` | Permite retomar builds longas após falhas sem reiniciar do zero. | Produtividade. Debugging eficiente. |

---

## 🔄 Workflow Detalhado

1. **Validação:** Confirma `$LFS`, `$LFS_TGT`, GCC Pass 1, e Musl (`libc.a`).
2. **Extracção & Deps:** Extrai GCC e injeta GMP/MPFR/MPC (reutiliza lógica do Pass 1).
3. **Build Dir:** Cria `gcc-build-pass2/` (suporte a `--no-clean`).
4. **Configuração:** Flags completas (C/C++, shared, threads, pie, ssp, system-zlib).
5. **Compilação:** `make` paralelo. Demora mais que Pass 1 (~5-10 min).
6. **Instalação:** `make install` em `$LFS/tools`.
7. **Symlink:** Garante `cc -> gcc`.
8. **Validação C++:** Compila `dummy.cpp`, verifica interpreter Musl via `readelf`.
9. **Limpeza:** Remove fontes e build dir (se não `--no-clean`).

---

## 🔍 Análise Profunda das Flags de Configuração

```bash
../configure \
    --target="$LFS_TGT" \
    --prefix="$LFS/tools" \
    --with-sysroot="$LFS" \
    --enable-default-pie \          # Segurança: ASLR por defeito
    --enable-default-ssp \          # Segurança: Stack canaries por defeito
    --disable-nls \
    --enable-languages=c,c++ \      # C e C++ completos
    --enable-shared \               # Gera libstdc++.so e libgcc_s.so
    --enable-threads=posix \        # Suporte a pthreads (crucial para software moderno)
    --enable-__cxa_atexit \         # C++ ABI compliance (destrutores estáticos)
    --enable-clocale=gnu \          # Locale padrão compatível
    --disable-libstdcxx-pch \       # Desactiva precompiled headers (evita bugs de cache)
    --disable-multilib \
    --disable-bootstrap \           # Já temos compiler host, não precisamos compilar compiler com compiler
    --disable-libmpx \              # MPX obsoleto/removido em CPUs modernas
    --with-system-zlib              # Usa zlib do host (já disponível)
```

**Nota Arquitectural:** `--disable-bootstrap` é seguro aqui porque já temos um GCC host funcional. O bootstrap só é necessário quando se compila um compiler do zero sem outro compiler.

---

## 🛠️ Troubleshooting & Mitigações

| Sintoma | Causa Raiz | Solução Vëra |
|---------|------------|--------------|
| `configure: error: C++ compiler missing or inoperational` | GCC Pass 1 falhou ou `cc` symlink em falta. | Re-executar `02-gcc-pass1.sh`. Validar `ls -l $LFS/tools/bin/cc`. |
| `error: 'pthread.h' not found` durante compilação | Headers de threading em falta ou Musl mal instalada. | Validar `04-musl.sh`. Verificar `$LFS/usr/include/pthread.h`. |
| `make[3]: *** [libstdc++-v3] Error` | Falta de `--enable-__cxa_atexit` ou conflito de ABI. | A flag está incluída. Se persistir, limpar build dir e reconfigurar. |
| Binários gerados usam interpreter do host | `--with-sysroot` ignorado ou Musl não detectada. | Validar `readelf -l` no dummy.cpp. O interpreter DEVE ser `/lib/ld-musl-*.so.1`. |
| Build demora demasiado ou consome RAM | `make` sem limites em máquina fraca. | Usar `MAKEFLAGS="-j2"` ou limitar com `ulimit`. |

---

## ✅ Validação Pós-Execução

```bash
# 1. Versão do compilador completo
$LFS_TGT-gcc --version
# gcc (GCC) 14.2.0

# 2. Teste C++ com STL e I/O
cat > test.cpp << 'EOF'
#include <iostream>
#include <vector>
int main() {
    std::vector<int> v = {1, 2, 3};
    std::cout << "Vëra GCC Pass 2 OK: " << v.size() << " elements\n";
    return 0;
}
EOF
$LFS_TGT-g++ -o test test.cpp
./test
# Vëra GCC Pass 2 OK: 3 elements

# 3. Validação CRÍTICA: Interpreter Musl
readelf -l test | grep interpreter
# [Requesting program interpreter: /lib/ld-musl-x86_64.so.1]
# Se aparecer /lib64/ld-linux-x86-64.so.2 -> FALHA CRÍTICA (ainda a usar glibc do host)

rm -f test test.cpp

# 4. Verificar libs partilhadas instaladas
ls $LFS/tools/lib64/libstdc++.so*
# libstdc++.so -> libstdc++.so.6.0.33
```

---

## 🔗 Integração no Roadmap (Fase 1)
- **Bloqueia:** `06-finalize-toolchain.sh` (strip, validação final, preparação chroot)
- **Dependência:** GCC Pass 1, Musl, Linux Headers, Binutils Pass 1
- **Próximo Marco:** Toolchain temporária completa, segura e autocontida. Pronto para sanitização e entrada no chroot.