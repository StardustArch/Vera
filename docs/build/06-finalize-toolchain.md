### 📄 `docs/build/06-finalize-toolchain.md`

# 06-finalize-toolchain.sh — Finalização e Validação da Toolchain Temporária

**Script:** `scripts/build/06-finalize-toolchain.sh`  
**Fase:** 1 — Sistema Base Bootável (LFS Cap 5.9)  
**Execução:** No HOST  
**Status:** ✅ Produzido e validado  

---

## Objectivo

Consolidar a toolchain temporária (`/tools`), remover símbolos de debug para economizar espaço, e validar rigorosamente que todos os binários gerados estão linkados contra a biblioteca `musl` e não contra a `glibc` do host. Este é o "checkpoint" antes de entrarmos no chroot.

---

## Decisões de design

| Decisão | Motivo |
|---------|--------|
| `strip --strip-debug/unneeded` | Reduz o tamanho da toolchain em ~60%. Fundamental para builds determinísticas e rápidas. |
| Teste de compilação C/C++ com `readelf` | Garante que o compilador gera binários ELF com o interpreter `/lib/ld-musl-x86_64.so.1`. Zero suposições. |
| Validação de `libc.so` | Confirma que a biblioteca C padrão do sistema é a do musl, não a do host. |
| `DRY_RUN` mode | Permite testar o script sem alterar o sistema, útil para debugging e CI. |

---

## Workflow do script

1. Valida existência de `$LFS/tools`.
2. Aplica `strip` em binários e bibliotecas.
3. Compila e executa um programa de teste em C (valida libc).
4. Compila e executa um programa de teste em C++ com threads (valida libstdc++ e pthreads).
5. Verifica o interpreter de cada binário de teste via `readelf`.
6. Cria estrutura de diretórios mínima (`etc`, `var`, `root`, `tmp`).

---

## Problemas encontrados e soluções

### 1. Binários usando linker do Host
**Sintoma:** O teste C compilava, mas executava no ambiente do host sem erros, escondendo o facto de estar linkado contra `glibc`.  
**Solução:** Usar `readelf -l` para extrair a linha `[Requesting program interpreter: ...]`.  
**Validação:** Se o output não contiver `ld-musl-x86_64.so.1`, o script falha com `exit 1`.

### 2. Erros de permissão em `/root` e `/tmp`
**Causa:** Padrão LFS exige permissões restritas (0750 para root, 1777 para tmp).  
**Solução:** `chmod` explícito na secção de preparação de diretórios.

---

## Validação pós-execução
```bash
# Verificar tamanho da toolchain
du -sh /mnt/lfs/tools
# Exemplo: 450M (sem strip seria >1GB)

# Verificar interpreter de um binário do tools
readelf -l /mnt/lfs/tools/bin/gcc | grep interpreter
# [Requesting program interpreter: /lib64/ld-linux-x86-64.so.2] -> ERRADO (Host)
# [Requesting program interpreter: /lib/ld-musl-x86_64.so.1] -> CORRETO (Vëra)
```

---

**Dependência anterior:** `05-gcc-pass2.sh`  
**Próximo passo:** `07-prepare-chroot-env.sh` (Estrutura FHS e Identidade)
