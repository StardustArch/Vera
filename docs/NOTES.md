# Notas de Desenvolvimento - Vëra

## 🎯 Estado Atual
- **Fase:** 0 → 1 (Fundação → Sistema Base)
- **Roadmap:** [ver ROADMAP.md](./ROADMAP.md)
- **Última atualização:** 2026-04-27

## 🏗️ Decisões de Arquitetura
- [✅] **Init system:** `runit` (minimal, explícito, auditável). OpenRC fica em `vera-ports`.
- [✅] **FHS:** Seguir padrão FHS estritamente. Qualquer desvio futuro será documentado e justificado.
- [✅] **`$LFS` mount point:** Configurado via imagem ext4 (`lfs.img`), montado em `/mnt/lfs`. Persistência via `~/.bashrc`.
- [✅] **Ambiente de build:** `~/vera-workspace/` isolado. Scripts em `scripts/`, sources em `sources/`, patches em `patches/`.
- [✅] **Estratégia de pacotes:** Tier 1 & 2 para Fase 1. Tier 3 (GUI, systemd, python-runtime, testes) adiado para Fase 3+.
- [✅] **Filosofia formalizada:** `docs/PHILOSOPHY.md` criado. Zero systemd, Sway (Wayland), Vex local, explícito > implícito.
- [✅] **Estrutura de repositórios:** `vera-workspace` = build local. `github.com/StardustArch/` = repos públicos versionados.

## 📖 LFS - Capítulo por Capítulo
### Cap. 1-2 (Introdução & Host Validation)
- [✅] Host system validado (gcc 15.2, glibc 2.43, bash 5.3, coreutils 9.10, kernel 7.0, etc.)
- [✅] `$LFS` variável e ponto de montagem definidos
- [✅] Verificação de espaço, permissões e dependências concluída

### Cap. 3-4 (Sources & Patches)
- [✅] Script `download-sources.sh v3` funcional com validação MD5 oficial
- [✅] 71 sources + 5 patches baixados e validados
- [✅] expat-2.6.2 corrigido para URL do GitHub (lição: URLs de terceiros mudam)
- [✅] Espaço total: ~500 MB

### Cap. 5-6 (Toolchain Temporária) - PRÓXIMO
- [ ] Compilar Binutils Pass 1
- [ ] Compilar GCC Pass 1
- [ ] Configurar Linux API Headers
- [ ] Compilar Glibc
- [ ] Compilar GCC Pass 2 (com libstdc++)
- [ ] Ajustar linker e specs file
- [ ] Testar toolchain (`dummy` program)

### Cap. 7-8 (Sistema Base) - FUTURO
- [ ] Criar diretórios base (`/bin`, `/etc`, `/usr`, `/var`, etc.)
- [ ] Instalar ~40 pacotes essenciais
- [ ] Configurar kernel (`make menuconfig` → minimal)
- [ ] Configurar GRUB
- [ ] **Milestone 1:** Primeiro boot bem-sucedido

## 🧠 Notas & Lições Aprendidas
- `set -euo pipefail` + `timeout` previne hangs silenciosos em scripts de validação.
- Caminhos com `~` podem falhar em expansão dentro de alguns comandos; usar `$PWD` ou caminhos absolutos é mais seguro.
- `bzip2 --version` escreve em `stderr` e entra em modo interativo; requer tratamento especial em scripts.
- Validar checksums *antes* de compilar é não-negociável. Zero confiança cega.

## 🔗 Links Úteis
- LFS Book 12.2: https://www.linuxfromscratch.org/lfs/view/stable/
- LFS Wget List: https://www.linuxfromscratch.org/lfs/downloads/12.2/wget-list
- Vëra Philosophy: `docs/PHILOSOPHY.md`
- Repo Principal: https://github.com/StardustArch/Vera