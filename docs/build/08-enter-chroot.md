
### 📄 `docs/build/08-enter-chroot.md`

# 08-enter-chroot.sh — Entrada no Ambiente Chroot

**Script:** `scripts/build/08-enter-chroot.sh`  
**Fase:** 1 — Sistema Base Bootável  
**Execução:** No HOST (com `sudo`)  
**Status:** ✅ Produzido e validado  

---

## Objectivo

Transicionar do ambiente host para o ambiente chroot Vëra (`/mnt/lfs`), isolando completamente a toolchain musl e validando que o interpreter `ld-musl-x86_64.so.1` está funcional. Este passo é o ponto de viragem onde deixamos de depender do compilador do host e passamos a usar exclusivamente `/tools/bin`.

---

## Decisões de design

| Decisão | Motivo |
|---------|--------|
| `exec env -i` | Limpa o ambiente completamente. Zero poluição do host dentro do chroot. |
| `PATH=/tools/bin:/usr/bin` | Prioriza a toolchain temporária. Garante que `gcc`, `make`, etc. são os compilados para musl. |
| `PS1` personalizado | Distingue visualmente o chroot (`[vera chroot]`) do shell normal. Evita erros humanos. |
| Validar `${LFS_TGT}-gcc` antes de entrar | Falha rápida se a toolchain (caps 5-6) não estiver completa. |
| Montar `/sources` via bind mount | Evita duplicar tarballs (~2GB) dentro do chroot. Poupa espaço e tempo de cópia. |

---

## Workflow do script

1. Valida `$LFS` e `${LFS_TGT}-gcc`
2. Cria directórios VFS (`proc`, `sys`, `dev`, `dev/pts`, `run`)
3. Monta sistemas de ficheiros virtuais
4. Valida o interpreter musl (`ld-musl-x86_64.so.1`)
5. Faz bind mount de `/sources` (do host)
6. Executa `chroot` com ambiente limpo (`env -i`)

---

## Problemas encontrados e soluções

### 1. Variáveis de ambiente poluíam o chroot
**Causa:** Usar `chroot $LFS /bin/bash` sem `env -i` herda `PATH`, `LD_LIBRARY_PATH`, etc. do host.  
**Solução:**
```bash
exec env -i \
    HOME=/root \
    TERM="$TERM" \
    PS1='\[\033[1;35m\](vera chroot)\[\033[0m\] \[\033[1;32m\]\u\[\033[0m\]:\[\033[1;34m\]\w\[\033[0m\]\$ ' \
    PATH=/tools/bin:/usr/bin \
    chroot "$LFS" /usr/bin/bash --login
```
**Resultado:** Ambiente 100% isolado. Só existe o que foi compilado.

### 2. `/sources` vazio no chroot
**Causa:** Os tarballs estavam no host (`~/vera-workspace/sources`), não no chroot.  
**Solução:** `mount --bind "$WORKSPACE_DIR/sources" "$LFS/sources"`  
**Vantagem:** Zero cópia. O chroot acede aos tarballs directamente.

### 3. Interpreter musl em falta
**Causa:** Script executado antes de `04-musl.sh` ou musl não instalou correctamente.  
**Solução:** Validação explícita com `exit 1` se `$LFS/lib/ld-musl-x86_64.so.1` não existir.  
**Lição:** Fail-fast antes de entrar no chroot.

---

## Validação pós-execução
```bash
# Dentro do chroot:
echo $PATH          # /tools/bin:/usr/bin
which gcc           # /tools/bin/gcc
gcc -v 2>&1 | grep Target  # Target: x86_64-linux-musl
ls /sources/        # linux-6.10.5.tar.xz  bash-5.2.21.tar.gz  ...
```

---

## Notas para a Fase 2
- O `08-enter-chroot.sh` será substituído por um pipeline containerizado (Docker/Podman) para CI/CD
- O bind mount de `/sources` será substituído por cópia para artefactos imutáveis em builds oficiais
- O `PS1` personalizado será documentado no guia de contribuição para padronizar logs

---

