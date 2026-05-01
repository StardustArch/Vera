
# Teste de Boot — Imagem Raw + QEMU (VIRTIO-ONLY)

**Script:** `scripts/build/13-test-boot.sh`  
**Data:** 2026-05-01  
**Status:** ✅ **Milestone 1 alcançado — Boot bem-sucedido!**

---

## Objectivo

Transformar o ambiente chroot (`/mnt/lfs`) num disco virtual bootável (`vera-boot-test.img`) e validar o primeiro boot através do QEMU usando **VIRTIO-ONLY** (sem dependências de hardware legado).

---

## 🔄 Mudanças Críticas (Pós-Milestone 1)

### **ANTES** ❌
```bash
# UUID hardcoded — SEMPRE errado
root=UUID=c0e0be0d-3b99-46a5-9c6b-96920d8fe5a4

# Disco IDE/SATA — drivers desnecessários
-drive file=img,format=raw,if=ide
root=/dev/sda1
```

### **AGORA** ✅
```bash
# Device name fixo — VIRTIO é determinístico
-drive file=img,format=raw,if=virtio
root=PARTUUID=${PARTUUID}
```

**Porquê?**
- UUID muda a cada `mkfs.ext4` → **inviável**
- VIRTIO é paravirtualizado → **sempre `/dev/vda`**
- Elimina drivers ATA/PIIX → **kernel mais limpo**

---

## Decisões de design (ACTUALIZADO)

| Decisão | Motivo |
|---------|--------|
| **VIRTIO-ONLY** | Padrão moderno. Kernel não precisa de drivers IDE/SATA/PIIX. Mais rápido e estável. |
| **root=/dev/vda1** | VIRTIO-blk cria `/dev/vda` deterministicamente. Sem UUIDs que mudam. |
| **Imagem RAW** | Formato universal, fácil de analisar. Sem camadas de abstracção. |
| **Particionamento MBR** | Compatibilidade total com GRUB `i386-pc`. |
| **Loop device com `losetup -P`** | Permite formatar e montar partições dentro do ficheiro. |

---

##  Problemas ÉPICOS encontrados e soluções

### 1. **UUID Dinâmico — O Bug Fantasma** 💥

**Sintoma:**
```
Kernel panic: VFS: Unable to mount root fs on unknown-block(0,0)
```

**Causa REAL:**
O script usava `root=UUID=xxxx` **hardcoded**. Cada execução do `mkfs.ext4` gera um UUID **novo**. O GRUB apontava para um UUID que **já não existia**.

**Diagnóstico:**
```bash
# Kernel vê:
vda1 12496771-01  ← PARTUUID real

# GRUB tenta usar:
root=UUID=c0e0be0d-...  ← UUID errado/hardcoded
```

**Solução:**
```bash
UUID=$(blkid -s UUID -o value ${LOOP_PART})
# Injeta no grub.cfg
```

**Lição:** UUIDs são para sistemas **persistentes**. Em builds reproduzíveis, usa **device names** ou **PARTUUID**.

---

### 2. **Kernel sem drivers VIRTIO** 🔥

**Sintoma:**
```
VFS: Unable to mount root fs on unknown-block(0,0)
```

**Causa:**
Kernel compilado sem `CONFIG_VIRTIO_BLK=y`. O QEMU usava `if=virtio`, mas o kernel **não via o disco**.

**Solução:**
```bash
# No 11-build-kernel.sh:
scripts/config --enable VIRTIO
scripts/config --enable VIRTIO_PCI
scripts/config --enable VIRTIO_BLK
```

**Lição:** QEMU `if=virtio` **exige** kernel com VIRTIO built-in. Não assume nada.

---

### 3. **GRUB com UUID do HOST** 😱

**Sintoma:**
O `grub.cfg` tinha o UUID do **teu sistema Arch** (`/dev/sda7`), não da imagem!

**Causa:**
Copiaste o `fstab` do sistema host sem actualizar.

**Solução:**
```bash
# Sempre usar device name ou detectar dinamicamente:
root=/dev/vda1  # VIRTIO
# OU
root=PARTUUID=$(blkid -s PARTUUID -o value ${LOOP_PART}p1)
```

---

## Workflow do script (ACTUALIZADO)

```bash
1. Valida $LFS, qemu-img, grub-install
2. Cria vera-boot-test.img (5 GB, RAW)
3. Particiona: MBR + 1 partição Linux (type=83)
4. Loop device: losetup --partscan
5. Formata: mkfs.ext4 -F /dev/loopXp1
6. Monta em /mnt/vera-test
7. Copia sistema: rsync -aHAXx /mnt/lfs/. /mnt/vera-test/
8. Gera grub.cfg DINÂMICO:
   - Detecta UUID/PARTUUID real
   - OU usa root=/dev/vda1 (fixo)
9. grub-install --target=i386-pc /dev/loopX
10. Desmonta tudo
11. QEMU:
    qemu-system-x86_64 \
      -drive file=img,format=raw,if=virtio \
      -m 2048
```

---

## ✅ Validação pós-boot (REAL)

```bash
# Kernel
uname -r
# 6.10.5

# Root filesystem
df -h /
# /dev/vda1 montado em /

# Init system
ps aux | head -1
# root     1  ... /sbin/init

# Dispositivos
ls -l /dev/vda*
# brw-rw---- 1 root disk 254, 0 ... /dev/vda
# brw-rw---- 1 root disk 254, 1 ... /dev/vda1
```

---

## 📊 Resumo Técnico

| Componente | Configuração |
|------------|--------------|
| **QEMU disk** | `if=virtio` |
| **Kernel** | `CONFIG_VIRTIO_BLK=y` |
| **GRUB** | `root=/dev/vda1` |
| **fstab** | `/dev/vda1 / ext4 ...` |
| **UUID** | ❌ Não usado (muda sempre) |
| **PARTUUID** | ✅ Opcional (mais estável) |

---

## 🎯 Lições Aprendidas

1. **UUID ≠ PARTUUID**
   - UUID: do filesystem → muda com `mkfs`
   - PARTUUID: da partição → muda com `fdisk`
   - Device name: `/dev/vda1` → **fixo para VIRTIO**

2. **Kernel config ≠ drivers activos**
   - Ter `CONFIG_ATA=y` não ajuda se usas `if=virtio`
   - Precisas de `CONFIG_VIRTIO_BLK=y`

3. **GRUB.cfg hardcoded = dor**
   - Sempre gera dinamicamente ou usa device names fixos

4. **QEMU moderno = VIRTIO**
   - Esquece IDE/SATA/PIIX
   - VIRTIO é mais rápido, mais simples, mais estável

---

## 🚀 Próximos Passos

- [ ] Automatizar detecção de UUID/PARTUUID no script
- [ ] Adicionar suporte a UEFI (`if=virtio` + OVMF)
- [ ] Criar pipeline CI/CD para builds automáticas
- [ ] Documentar no `vera_roadmap_detalhado.html`

---

**Milestone 1:** ✅ **CONCLUÍDO**  
**Próximo:** Fase 2 — Gestão de Pacotes (`vpm`) + Self-hosting

---

**Nota Histórica:** Este foi o debugging mais intenso do projecto até agora. Cada erro ensinou algo sobre bootloaders, kernels, e a diferença entre "funciona no meu PC" e "funciona sempre". 🐧🔥