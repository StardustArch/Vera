
### 📄 `docs/build/03-linux-headers.md`

# 03-linux-headers.sh — Instalação de Linux API Headers Sanitizados

**Script:** `scripts/build/03-linux-headers.sh`  
**Fase:** 1 — Fundação da Toolchain (LFS Cap. 5.6)  
**Execução:** No HOST  
**Status:** ✅ Produzido e validado com verificação de árvore UAPI  

---

## 🎯 Objectivo & Contexto Arquitectural

Este script expõe a **interface de programação de aplicações (API)** do kernel Linux para o espaço de utilizador. 
A libc (Musl) e todas as ferramentas de sistema precisam de saber como falar com o kernel (syscalls, estruturas de dados, constantes). 
Em vez de copiar todo o source do kernel, extraímos e **sanitizamos** apenas os headers públicos (`UAPI`), removendo artefactos de build e ficheiros internos que poderiam causar conflitos ou vazamentos de implementação.

---

## 🧠 Decisões de Design & Filosofia Vëra

| Decisão | Justificação Técnica | Alinhamento Vëra |
|---------|----------------------|------------------|
| `make mrproper` antes de extrair headers | Garante árvore limpa. Configurações antigas ou `.config` residuais podem corromper a extração UAPI. | Estado determinístico. Zero resíduos. |
| Sanitização agressiva (`find ... ! -name '*.h' -delete`) | Headers do kernel contêm ficheiros `.c`, `.o`, `Makefile`, `.cmd`. Instalar tudo polui `$LFS/usr/include` e quebra compiladores. | Precisão cirúrgica. Apenas interface pública. |
| Cópia manual para `$LFS/usr/include` | Evita `make headers_install` que por vezes instala em paths incorrectos em ambientes cross. | Controlo total. Sem magia do Makefile. |
| Validação de `version.h` | Ficheiro gerado automaticamente. Confirma que o processo de extracção correu até ao fim. | Checkpoint verificável. |

---

## 🔄 Workflow Detalhado

1. **Validação:** Verifica `$LFS` e tarball do kernel.
2. **Extracção:** Descomprime `linux-${VER}.tar.xz`.
3. **Limpeza Profunda:** `make mrproper` remove ficheiros de configuração e build anteriores.
4. **Geração de Headers:** `make headers` processa a árvore e gera a versão sanitizada em `usr/include/`.
5. **Sanitização:** `find usr/include -type f ! -name '*.h' -delete` remove tudo que não é header C.
6. **Instalação:** `cp -rv usr/include $LFS/usr/` coloca a API no sysroot.
7. **Validação:** Confirma existência de `linux/version.h` e lista diretórios instalados.
8. **Limpeza:** Remove árvore de fontes do kernel.

---

## 🔍 Análise Profunda das Flags & Comandos

```bash
make mrproper
# Remove .config, backups, e ficheiros temporários. Essencial para reprodutibilidade.

make headers
# Executa o processo UAPI: valida headers, remove __KERNEL__ guards, gera versões limpas.

find usr/include -type f ! -name '*.h' -delete
# Filtragem crítica. Preserva apenas a interface pública. Remove .c, .o, Makefiles, Kconfig.

cp -rv usr/include "$LFS/usr"
# Instala no sysroot. A libc irá procurar syscalls e structs aqui.
```

**Nota Arquitectural:** A separação entre kernel source e user-space headers é fundamental para estabilidade. A Vëra segue o princípio de **menor privilégio**: o userspace só vê o que precisa para fazer syscalls.

---

## 🛠️ Troubleshooting & Mitigações

| Sintoma | Causa Raiz | Solução Vëra |
|---------|------------|--------------|
| `make headers` falha com `Permission denied` | Extracção feita com `sudo` mas compilação com user normal (ou vice-versa). | Garantir consistência de ownership. O script corre sempre com o mesmo utilizador. |
| Headers desactualizados ou incompletos | `make mrproper` não correu ou árvore corrompida. | O script limpa e extrai do zero. Idempotente. |
| Compiladores reclamam de headers em falta | Sanitização removeu ficheiros necessários por engano. | A regra `! -name '*.h'` é segura. Headers UAPI são estritamente `.h`. |
| `version.h` não gerado | `make headers` interrompido prematuramente. | Validar log de `make headers`. Deve terminar sem erros. |

---

## ✅ Validação Pós-Execução

```bash
# 1. Verificar estrutura UAPI
ls $LFS/usr/include/linux/ | head -10
# aio.h, audit.h, bpf.h, cgroup.h, ...

# 2. Validar version.h (gerado dinamicamente)
cat $LFS/usr/include/linux/version.h
# #define LINUX_VERSION_CODE 394757
# #define KERNEL_VERSION(a,b,c) ...

# 3. Confirmar que não há ficheiros de build
find $LFS/usr/include -name "*.o" -o -name "Makefile" | wc -l
# Deve retornar 0
```

---

## 🔗 Integração no Roadmap (Fase 1)
- **Bloqueia:** `04-musl.sh` (Musl precisa dos headers para compilar wrappers de syscalls)
- **Dependência:** Kernel source tarball
- **Próximo Marco:** Interface kernel-userspace estabelecida. Pronto para compilar a libc.

