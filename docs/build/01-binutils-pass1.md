
### 📄 `docs/build/01-binutils-pass1.md`

# 01-binutils-pass1.sh — Cross-Compilation do Binutils (Passo 1)

**Script:** `scripts/build/01-binutils-pass1.sh`  
**Fase:** 1 — Fundação da Toolchain (LFS Cap. 5.4)  
**Execução:** No HOST (ambiente de build)  
**Status:** ✅ Produzido, testado e integrado no pipeline CI  

---

## 🎯 Objectivo & Contexto Arquitectural

Este script inicia a construção da **toolchain temporária** (`$LFS/tools`). O Binutils (GNU Binary Utilities) fornece o `as` (assembler), `ld` (linker), `ar`, `ranlib`, `objdump`, entre outros. 
Compilá-lo em primeiro lugar é **mandatório**: o GCC precisa de um linker e assembler funcionais para construir a si próprio. Este passo cria um ambiente de cross-compilação isolado, onde todos os binários resultantes apontam para `$LFS/tools` e utilizam o target `x86_64-linux-musl`.

---

## 🧠 Decisões de Design & Filosofia Vëra

| Decisão | Justificação Técnica | Alinhamento Vëra |
|---------|----------------------|------------------|
| **Build Out-of-Tree** | Separa fontes originais de artefactos compilados. Permite limpar `build/` sem tocar em `sources/`. | Reprodutibilidade. Zero estado sujo. |
| `--prefix=$LFS/tools` | Isola completamente a toolchain temporária do sistema host. Evita poluição de `/usr` ou `/usr/local`. | Segurança. Isolamento estrito. |
| `--with-sysroot=$LFS` | Define `$LFS` como raiz lógica para procura de headers e libs durante a cross-compilação. | Precisão. O compilador nunca olha para o host. |
| `--disable-werror` | Impede que warnings do compilador host (ex: GCC 14 no Arch) abortem a build. | Pragmatismo. Foco no resultado funcional. |
| `run()` wrapper + `DRY_RUN` | Captura stdout/stderr em logs, falha imediatamente (`set -e`), e permite simulação segura. | Observabilidade. Fail-fast. |

---

## 🔄 Workflow Detalhado

1. **Validação de Pré-requisitos:** Verifica `$LFS`, `$LFS_TGT`, e existência do tarball. Falha imediata se algo faltar.
2. **Limpeza Idempotente:** Remove diretórios de source e build anteriores. Garante estado fresco.
3. **Extracção:** Descomprime `binutils-${VER}.tar.xz` no workspace.
4. **Criação de Build Dir:** `mkdir -p binutils-build && cd binutils-build`.
5. **Configuração:** Executa `../configure` com flags de cross-compilação e otimização.
6. **Compilação:** `make` paralelo (controlado por `$MAKEFLAGS`).
7. **Instalação:** `make install` direciona binários e libs para `$LFS/tools`.
8. **Validação:** Verifica existência e versão de `$LFS_TGT-ld`.
9. **Limpeza:** Remove fontes e build dir para libertar espaço.

---

## 🔍 Análise Profunda das Flags de Configuração

```bash
../configure \
    --prefix="$LFS/tools" \          # Instalação isolada
    --with-sysroot="$LFS" \          # Raiz virtual para cross-compile
    --target="$LFS_TGT" \            # Arquitetura alvo (x86_64-linux-musl)
    --disable-nls \                  # Remove internacionalização (reduz tamanho/complexidade)
    --enable-gprofng=no \            # Desactiva gerador de perfis novo (evita deps de Python/Java)
    --disable-werror                 # Tolerância a warnings do host
```

**Nota Arquitectural:** `--disable-nls` é crítico na Fase 1. Internacionalização requer `gettext`, que ainda não existe. Desactivá-lo simplifica a build e reduz a superfície de ataque.

---

## 🛠️ Troubleshooting & Mitigações

| Sintoma | Causa Raiz | Solução Vëra |
|---------|------------|--------------|
| `configure: error: no acceptable C compiler found in $PATH` | GCC do host não está instalado ou PATH corrompido. | Instalar `base-devel` (Arch) ou `build-essential` (Debian). Validar `gcc --version`. |
| `make[3]: *** [Makefile:xxx] Error 1` durante `gprofng` | Dependências de profiling (Python/Java) em falta no host. | `--enable-gprofng=no` resolve. Ferramenta não é necessária para toolchain base. |
| Binários instalados em `/usr/local` por engano | `--prefix` mal configurado ou cache de configure antigo. | `rm -rf $LFS/tools/*` e re-executar. O script já limpa build dir automaticamente. |
| Linker ignora `$LFS` e usa libs do host | `--with-sysroot` omitido ou mal formatado. | Verificar sintaxe exata. O sysroot deve apontar para o diretório raiz do chroot. |

---

## ✅ Validação Pós-Execução

```bash
# 1. Verificar binário crítico
$LFS_TGT-ld --version
# GNU ld (GNU Binutils) 2.43.1

# 2. Validar isolamento (não deve haver referências a /lib/x86_64-linux-gnu do host)
readelf -d $LFS/tools/bin/$LFS_TGT-ld | grep NEEDED
# Deve mostrar apenas libs do sistema ou nenhuma (estático parcial)

# 3. Espaço ocupado
du -sh $LFS/tools
# Esperado: ~150-200MB
```

---

## 🔗 Integração no Roadmap (Fase 1)
- **Bloqueia:** `02-gcc-pass1.sh` (GCC precisa do linker para compilar)
- **Dependência:** Host compiler (GCC/Clang), `make`, `tar`, `texinfo`
- **Próximo Marco:** Toolchain temporária inicializada. Isolamento do host garantido.
