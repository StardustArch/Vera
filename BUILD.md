```markdown
# Vëra Build Guide (Fase 0–1)
> *"Explicit over implicit. The user is the only owner."*

## ⚠️ Scope & Philosophy
- Este guia cobre **apenas a Fase 0–1** (fundação + sistema base bootável).
- Não há "magia". Cada passo é explícito, validado e registado em logs.
- Se algo falhar, o script para imediatamente. Não prossigas sem entender o porquê.
- Lê `docs/PHILOSOPHY.md` antes de contribuir.

## 📦 Pré-requisitos do Host
- Linux moderno (kernel ≥ 4.19, GCC ≥ 11.2, Glibc ≥ 2.27)
- ≥ 20GB espaço livre, ≥ 4GB RAM
- Ferramentas: `bash`, `curl`, `wget`, `git`, `make`, `gcc`, `g++`, `bzip2`, `xz`
- Validação automática: `./scripts/check-host.sh`
```
## 🗂️ Estrutura de Pastas
```
~/vera-workspace/
├── sources/          # Tarballs validados (não versionados)
├── patches/          # Patches LFS 12.2
├── scripts/          # Automação explícita
├── docs/             # Filosofia, notas, decisões
├── logs/             # Build outputs (não versionados)
├── lfs.img           # Imagem $LFS (20GB, gerada localmente)
└── git/Vera/         # Repo meta (este guia vive aqui)

```
## 🛠️ Passo a Passo

### 1. Setup do Ambiente
```bash
chmod +x scripts/setup-env.sh
./scripts/setup-env.sh
```
→ Cria estrutura, valida espaço, gera `docs/NOTES.md`.

### 2. Validar Host System
```bash
./scripts/check-host.sh
```
→ Se houver `⚠️` ou `❌`, resolve antes de continuar. Versões antigas causam falhas silenciosas mais tarde.

### 3. Baixar Sources Tier 1 & 2
```bash
./scripts/download-sources.sh 2>&1 | tee logs/download.log
```
→ Validação MD5 oficial do LFS 12.2. Se um pacote falhar, o script para. Corrige a URL e retoma.

### 4. Preparar `$LFS`
```bash
export LFS=/mnt/lfs
# (Se usaste lfs.img, já está montado. Caso contrário, monta a partição/imagem)
sudo mount -o loop ~/vera-workspace/lfs.img $LFS
sudo chown $USER:$USER $LFS
```

### 5. Carregar Ambiente LFS (OBRIGATÓRIO `source`)
```bash
source scripts/build/00-env.sh
env | grep -E '^(LFS|PATH|LC_ALL|MAKEFLAGS)='
```
→ Isto isola a toolchain do host. **Nunca executes `00-env.sh` com `./`**.

### 6. Próximos Passos (Toolchain)
Os scripts de compilação (`01-*.sh`, `02-*.sh`, etc.) serão adicionados ao repo `vera-core`. 
Cada passo gera um log em `logs/build/` e pode ser retornado com `--resume`.

## 🐛 Troubleshooting
| Sintoma | Causa Provável | Solução |
|---------|---------------|---------|
| `command not found` após `source 00-env.sh` | `PATH` sobrescrito por `~/.bashrc` | Remove aliases/exports conflituantes temporariamente |
| `gcc: unrecognized option` | Variáveis `CFLAGS`/`LD_LIBRARY_PATH` do host ativas | `unset CFLAGS LD_LIBRARY_PATH` e faz `source 00-env.sh` novamente |
| Download falha com 404 | URL de terceiros mudou | Atualiza no script, valida MD5 manualmente, commit a correção |

## 🤝 Contribuir com Scripts de Build
1. Cada script deve começar com `#!/usr/bin/env bash`, `set -euo pipefail` e logs prefixados com `[vera-build]`.
2. Falhas são explícitas. Nada de `|| true` sem justificação documentada.
3. Adiciona testes de validação pós-compilação (ex: `ldd --version`, `gcc -dumpversion`).
4. Abre PR com `build:` prefix na mensagem e link para o log de teste.

---
*Última atualização: 2026-04-27 | Fase: 0→1 | Mantido por: equipa Vëra*
```