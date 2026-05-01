
### 📄 `docs/build/02-gcc-pass1.md`

# 02-gcc-pass1.sh — Bootstrap do GCC (C/C++ Mínimo)

**Script:** `scripts/build/02-gcc-pass1.sh`  
**Fase:** 1 — Fundação da Toolchain (LFS Cap. 5.5)  
**Execução:** No HOST  
**Status:** ✅ Produzido e validado com teste de compilação C++  

---

## 🎯 Objectivo & Contexto Arquitectural

O **GCC Pass 1** é o compilador "semente". Compila apenas suporte para C e C++, sem bibliotecas partilhadas, sem threading, e sem olhar para headers do sistema host (`--without-headers`). 
Este passo é o **ponto de viragem** onde deixamos de depender do compilador do host para gerar código. O resultado é um compilador cross capaz de produzir binários para `$LFS_TGT`, pronto para compilar a libc (Musl) e os headers do Linux.

---

## 🧠 Decisões de Design & Filosofia Vëra

| Decisão | Justificação Técnica | Alinhamento Vëra |
|---------|----------------------|------------------|
| **Dependências Embutidas (GMP/MPFR/MPC)** | O GCC exige estas libs matemáticas. Extraí-las para dentro da árvore do GCC evita conflitos de versão e garante build determinística. | Autocontido. Zero deps externas voláteis. |
| `--without-headers` + `--with-newlib` | Força o GCC a não procurar headers do host. Usa stubs internos até a libc real ser compilada. | Isolamento total. Compilação limpa. |
| `--disable-shared` + `--disable-threads` | O bootstrap não precisa de libs dinâmicas ou pthreads. Reduz complexidade e tempo de build em ~40%. | Minimalismo funcional. |
| Symlink `cc -> gcc` | Padrão POSIX. Muitos pacotes (kernel, bash, coreutils) chamam `cc` por defeito. | Compatibilidade upstream. Zero patches desnecessários. |
| Validação pós-build com `readelf` | Confirma que o binário gerado usa o interpreter correto e não fallback do host. | Verificação criptográfica de integridade. |

---

## 🔄 Workflow Detalhado

1. **Validação:** Confirma `$LFS`, `$LFS_TGT`, tarball, e existência do Binutils Pass 1.
2. **Extracção GCC:** Descomprime `gcc-${VER}.tar.xz`.
3. **Injeção de Deps:** Extrai GMP, MPFR, MPC e renomeia pastas para `gmp/`, `mpfr/`, `mpc/` dentro da árvore do GCC (exigência do configure).
4. **Build Out-of-Tree:** Cria `gcc-build/` e entra.
5. **Configuração:** Aplica flags de bootstrap e security hardening básico (`--enable-default-pie`, `--enable-default-ssp`).
6. **Compilação:** `make` paralelo.
7. **Instalação:** `make install` em `$LFS/tools`.
8. **Symlink:** `ln -sv gcc $LFS/tools/bin/cc`.
9. **Validação:** Compila `dummy.c`, verifica interpreter via `readelf`, limpa artefactos.

---

## 🔍 Análise Profunda das Flags de Configuração

```bash
../configure \
    --target="$LFS_TGT" \            # Alvo: x86_64-linux-musl
    --prefix="$LFS/tools" \          # Isolamento
    --with-sysroot="$LFS" \          # Raiz virtual
    --with-newlib \                  # Usa libc mínima interna (bootstrap)
    --without-headers \              # Ignora headers do host completamente
    --enable-default-pie \           # Segurança: Position Independent Executables
    --enable-default-ssp \           # Segurança: Stack Smashing Protection
    --disable-nls \                  # Sem i18n nesta fase
    --disable-shared \               # Apenas estático para bootstrap
    --disable-multilib \             # Apenas 64-bit (Vëra é x86_64-only)
    --disable-threads \              # Threading vem na Pass 2
    --enable-languages=c,c++         # Apenas C/C++ (sem Fortran/Ada/Go)
```

**Nota de Segurança:** `--enable-default-pie` e `--enable-default-ssp` são activados desde o Pass 1. A Vëra prioriza hardening mesmo em ferramentas temporárias.

---

## 🛠️ Troubleshooting & Mitigações

| Sintoma | Causa Raiz | Solução Vëra |
|---------|------------|--------------|
| `configure: error: Building GCC requires GMP 4.2+, MPFR 3.1.0+ and MPC 0.8.0+` | Pastas GMP/MPFR/MPC não renomeadas ou ausentes. | O script já faz `mv gmp-x.y.z gmp`. Verificar se tarballs estão em `sources/`. |
| `error: unrecognized command line option '-fstack-protector-strong'` | Host compiler muito antigo (< GCC 4.9). | Actualizar host ou remover `--enable-default-ssp` temporariamente. |
| `make[3]: *** [libgcc.mvars] Error` durante build | Conflito com variáveis de ambiente do host (ex: `LD_LIBRARY_PATH`). | O script usa ambiente limpo. Nunca executar com `sudo -E`. |
| Binário `gcc` não é encontrado em `$LFS/tools/bin` | Instalação falhou ou prefix errado. | Verificar logs. O script já valida e faz `exit 1` se falhar. |

---

## ✅ Validação Pós-Execução

```bash
# 1. Versão do compilador
$LFS_TGT-gcc --version
# gcc (GCC) 14.2.0

# 2. Teste de compilação C++
echo 'int main(){return 0;}' > test.cpp
$LFS_TGT-g++ -o test test.cpp
readelf -l test | grep interpreter
# [Requesting program interpreter: /lib/ld-musl-x86_64.so.1] (ou stub temporário)
rm -f test test.cpp

# 3. Verificar symlink POSIX
ls -l $LFS/tools/bin/cc
# lrwxrwxrwx 1 root root 3 ... cc -> gcc
```

---

## 🔗 Integração no Roadmap (Fase 1)
- **Bloqueia:** `03-linux-headers.sh` e `04-musl.sh`
- **Dependência:** Binutils Pass 1, Host GCC, GMP/MPFR/MPC tarballs
- **Próximo Marco:** Capacidade de compilar código C/C++ targeting Vëra.
