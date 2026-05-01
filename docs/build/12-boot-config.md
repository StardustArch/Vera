# Boot Configuration — GRUB + Init + fstab

**Script:** `scripts/build/12-boot-config.sh`
**Data:** 2026-04-29
**Status:** ✅ Validado em chroot musl
**Tempo de build:** ~10-15 minutos

---

## Objectivo

Compilar o GRUB 2.12, criar os ficheiros de configuração de boot mínimos (`/etc/fstab`, `/etc/inittab`, `/boot/grub/grub.cfg`), e preparar a Vëra para o primeiro boot em hardware real ou VM.

**Resultado:** Sistema iniciável com GRUB BIOS, sysvinit, e configuração de root explícita.

---

## Decisões de design

| Decisão | Motivo |
|---------|--------|
| `--target=i386 --with-platform=pc` | GRUB BIOS corre em 100% das VMs e hardware. Evita complexidade de UEFI nesta fase. |
| `--disable-werror` | musl é estrito com warnings de casting e prototypes. GRUB upstream tem vários. |
| `grub.cfg` manual hardcoded | `grub-mkconfig` depende de `blkid`, `udev`, `lsblk` em runtime — falha no chroot. Config manual é transparente e auditável. |
| Python 3.12.5 minimal | GRUB 2.12 exige Python para gerar listas de módulos. Só o interpretador core é necessário. |
| Sysvinit + `inittab` explícito | Init simples, sem daemons ocultos. Zero serviços não solicitados. Controlo total do boot. |

---

## Componentes

### Python 3.12.5

Dependência de build do GRUB — usado para parsear ficheiros `.mod` e gerar `command.lst`, `fs.lst`, etc.

Compilado com `--without-ensurepip --disable-test-modules`. Módulos como `_ssl`, `zlib` e `readline` falham por falta de headers mas são irrelevantes para o GRUB.

Após instalação é necessário criar o symlink e limpar o cache do bash:
```bash
ln -sfv python3.12 /usr/bin/python3
hash -r
```

### GRUB 2.12

Compilado com flags mínimas para BIOS legacy. Build sequencial (`-j1`) obrigatório — paralelismo causa race condition no Makefile do GRUB 2.12.

### /etc/fstab

```
# <file system>  <mount point>  <type>  <options>     <dump>  <pass>
/dev/sda1        /              ext4    rw,relatime    0       1
tmpfs            /tmp           tmpfs   nosuid,nodev   0       0
```

Minimalista — só root e `/tmp`. Swap e outras partições adicionadas pelo utilizador pós-instalação.

### /etc/inittab

Define runlevel padrão (`3`), script de init (`/etc/rc.d/rc.sysinit`), e 6 gettys (`tty1`-`tty6`). Zero serviços automáticos.

### /boot/grub/grub.cfg

```grub
set default=0
set timeout=5
insmod part_msdos
insmod ext2

menuentry "Vëra Linux 6.10.5 (Musl)" {
    set root='hd0,msdos1'
    linux /vmlinuz-6.10.5-vera root=/dev/sda1 ro quiet loglevel=3
}
```

Hardcoded — sem detecção automática de UUIDs. O utilizador sabe exactamente qual partição e kernel estão a ser carregados. Módulos mínimos: `part_msdos` + `ext2`.

---

## Problemas encontrados e soluções

### 1. `platform "pc,efi-x86_64" is not supported`

**Causa:** O GRUB separa `--target` (CPU) de `--with-platform` (firmware). A string combinada é inválida.

**Solução:** Usar `--target=i386 --with-platform=pc` separadamente.

---

### 2. `no suitable Python interpreter found`

**Causa:** GRUB 2.12 mudou para Python 3 como dependência de build obrigatória.

**Solução:** Compilação manual de Python 3.12.5 minimal antes do GRUB.

---

### 3. `python3: command not found` após instalação

**Causa:** Binário instalado como `python3.12`. Symlink `python3` não criado automaticamente. Cache do bash fica stale.

**Solução:**
```bash
ln -sfv python3.12 /usr/bin/python3
hash -r
```

---

### 4. `No rule to make target '../grub-core/extra_deps.lst'`

**Causa:** Bug upstream no Makefile do GRUB 2.12 — o ficheiro de dependências não é gerado automaticamente.

**Solução:**
```bash
touch grub-core/extra_deps.lst
```

Aplicado antes do `make`. Zero patches invasivos.

---

### 5. `make -j4` falha com `all-recursive`

**Causa:** Race condition na geração de `.lst` e `.marker` em paralelo no Makefile do GRUB.

**Solução:** `make -j1` (build sequencial). Perda de ~30 segundos irrelevante.

---

### 6. `grub-mkconfig` não gera config válida

**Causa:** Depende de `blkid`, `udev`, `/dev/disk/by-uuid` — só existem em runtime, não no chroot.

**Solução:** Config manual hardcoded. Controlo total, zero boot loops.

---

## Validação

```bash
# Binários presentes
ls -l /usr/bin/grub-install /usr/bin/grub-mkimage /usr/bin/python3

# Versão do GRUB
grub-install --version
# Esperado: grub-install (GRUB) 2.12

# Ficheiros de configuração
cat /boot/grub/grub.cfg
cat /etc/fstab
grep initdefault /etc/inittab

# Syntax do grub.cfg
grub-script-check /boot/grub/grub.cfg && echo "✅ válido" || echo "❌ erro"
```

---

## Notas para a Fase 2

- Recompilar Python 3 com `zlib`, `ssl`, `readline` nativos em musl
- Adicionar suporte UEFI (`--target=x86_64 --with-platform=efi`)
- Substituir `grub.cfg` manual por `grub-mkconfig` quando `blkid`/`udev` estiverem disponíveis
- Criar `vpm install grub` para gerir actualizações do bootloader

---

**Milestone 1:** ✅ Sistema pronto para imagem de boot e teste QEMU
**Próximo:** `13-test-boot.md` — imagem raw, GRUB na MBR, primeiro boot real