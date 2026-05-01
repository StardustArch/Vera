

### 📄 `docs/build/07-prepare-chroot-env.md`

# 07-prepare-chroot-env.sh — Preparação do Ambiente do Chroot

**Script:** `scripts/build/07-prepare-chroot-env.sh`  
**Fase:** 1 — Sistema Base Bootável (LFS Cap 6)  
**Execução:** No HOST  
**Status:** ✅ Produzido e validado  

---

## Objectivo

Criar a estrutura de ficheiros (FHS), identidade do sistema e variáveis de ambiente necessárias para que o sistema dentro de `$LFS` possa ser executado independentemente do host. É a "ponte" entre a toolchain temporária e o sistema final.

---

## Decisões de design

| Decisão | Motivo |
|---------|--------|
| Estrutura FHS completa | Cria diretórios como `/var`, `/run`, `/usr/share`, etc., que o LFS espera para instalação de pacotes. |
| Symlinks Merged-Usr (`bin` -> `usr/bin`) | Alinha com o padrão moderno de distribuições Linux (merged-usr). |
| Bind mount de `/sources` | Evita copiar gigabytes de fontes para dentro da imagem; mantém as fontes acessíveis via loopback/bind. |
| Ficheiros de identidade (`passwd`, `group`) | Cria utilizadores e grupos base (`root`, `bin`, `daemon`) necessários para a posse de ficheiros. |

---

## Workflow do script

1. Cria a árvore de diretórios FHS.
2. Cria symlinks merged-usr.
3. Monta o diretório de fontes (`/sources`) via bind mount.
4. Copia ficheiros de identidade (`passwd`, `group`, `shadow`, `hosts`).
5. Configura o `/etc/profile` e o prompt do chroot.
6. Inicializa ficheiros de log (`wtmp`, `btmp`).

---

## Validação pós-execução
```bash
# Verificar estrutura
ls -ld /mnt/lfs/usr/bin
# lrwxrwxrwx 1 root root 3 ... /mnt/lfs/usr/bin -> bin

# Verificar identidade
cat /mnt/lfs/etc/passwd | head -1
# root:x:0:0:root:/root:/bin/bash
```

---

**Dependência anterior:** `06.5-bootstrap-bash.sh`  
**Próximo passo:** `08-enter-chroot.sh`
