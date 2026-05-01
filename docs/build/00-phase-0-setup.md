### 📄 `docs/build/00-phase-0-setup.md`

# Fase 0: Setup do Ambiente e Validação (Fundação)
  
**Correspondência no Roadmap:** "Fase 0 — Fundação (Mês 1–2)"  

## 🎯 Objectivo e Visão Arquitectural

A **Fase 0** é o alicerce de toda a distribuição Vëra. Antes de compilar uma única linha de código para o sistema alvo, precisamos de garantir que o ambiente de construção (Host) é capaz, seguro e isolado.

Esta fase define a **filosofia de isolamento estrito**: o que acontece no Host nunca polui o Target (`$LFS`), e o que acontece no Target nunca depende do Host durante o runtime.

### Principais Marcos da Fase 0
1.  **Validação do Host:** Garantir que o sistema operacional subjacente tem as ferramentas e versões mínimas para compilar software moderno.
2.  **Estruturação do Workspace:** Criar um directório organizado (`~/vera-workspace`) com separação clara entre fontes, patches e scripts.
3.  **Integridade das Fontes:** Download automatizado e verificação de checksums (MD5) contra listas oficiais do LFS.
4.  **Isolamento do Ambiente:** Configurar variáveis de ambiente (`PATH`, `LFS_TGT`) para criar um "túnel" limpo para a compilação.

---

## 🏗️ Arquitectura de Fluxo de Trabalho

O setup da Vëra segue uma ordem lógica e rígida:

1.  **Host Check** (`check-host.sh`) ➜ "O meu computador aguenta?"
2.  **Env Setup** (`setup-env.sh`) ➜ "Criar as pastas e verificar espaço."
3.  **Download** (`download-sources.sh`) ➜ "Obter as peças com garantia de integridade."
4.  **Mount LFS** (`setup-lfs-env.sh`) ➜ "Montar o disco virtual onde vamos construir."
5.  **Shell Config** (`00-env.sh`) ➜ "Preparar o terminal para o trabalho sujo."

---

## 📜 Documentação Detalhada dos Scripts

### 1. `check-host.sh` — Validação Rigorosa do Host

**Script:** `scripts/build/check-host.sh`  
**Fase:** 0 (Pré-requisito)  
**Execução:** No HOST

#### 🧠 Decisões de Design
*   **Fail-Fast com Timeouts:** Usa `timeout 2s` em cada verificação. Um comando pendente (ex: `gawk` a tentar ler um device ocupado) não deve travar o script de validação inteiro.
*   **Comparação de Versões Semântica:** Implementa `ver_ge` (version greater or equal) para garantir que não estamos a usar ferramentas obsoletas que geram bugs subtis no GCC.
*   **Zero Interação:** Script puramente informativo. Retorna código de saída baseado no sucesso/falha, ideal para CI/CD.

#### 🔍 Validação Crítica
O script valida pontos de dor comuns do LFS:
*   `Symlink /bin/sh`: Deve apontar para `bash`, não `dash`.
*   `Libstdc++`: Verifica se as bibliotecas C++ do host estão presentes.
*   `Binutils`: Confirma suporte a gprofng (ou a sua desactivação intencional).

---

### 2. `setup-env.sh` — Inicialização do Workspace

**Script:** `scripts/setup-env.sh`  
**Fase:** 0  
**Execução:** No HOST (utilizador normal)

#### 🧠 Decisões de Design
*   **Segurança Anti-Root:** O script aborta se detecta `root`. Construir uma distro como root é uma receita para desastre (permissões erradas, ficheiros corrompidos).
*   **Validação de Espaço:** Executa `df` para garantir >10GB livres. Uma build completa falha silenciosamente a meio se o disco encher.
*   **Estrutura FHS-Like:** Cria `sources`, `patches`, `build`, `docs` para manter a higiene do projecto.

#### 🔄 Workflow
1.  Verifica permissões e utilizador.
2.  Cria árvore de directórios.
3.  Gera `README.md` e `NOTES.md` iniciais para documentação.

---

### 3. `download-sources.sh` — Gestão de Fontes e Integridade

**Script:** `scripts/build/download-sources.sh`  
**Fase:** 0 → 1  
**Execução:** No HOST

#### 🧠 Decisões de Design
*   **Sistema de Tiers:** O script está preparado para baixar apenas o necessário para a Fase 1 (Tier 1 & 2). Tiers futuros (Desktop, Python, Systemd) estão comentados para evitar bloat.
*   **Verificação Criptográfica:** Baixa `md5sums` oficiais do LFS e valida **cada** tarball após o download. Um hash falhado aborta o processo (`exit 1`).
*   **Idempotência:** Se o ficheiro já existe e o hash está correcto, o download é saltado. Permite retomar downloads interrompidos.

#### 🔍 Flags e Configuração
*   `CONTINUE_ON_ERROR`: Permite decidir se um download falhado deve parar tudo ou apenas ser logado.
*   **Source Mirrors:** Usa uma lista híbrida de mirrors oficiais (GNU, Kernel.org, GitHub) para garantir disponibilidade.

---

### 4. `setup-lfs-env.sh` — Montagem do Ambiente Alvo

**Script:** `scripts/setup-lfs-env.sh`  
**Fase:** 0  
**Execução:** No HOST (com `source`)

#### 🧠 Decisões de Design
*   **Loop Device Automático:** Detecta e monta `lfs.img` (ou partição) em `/mnt/lfs`.
*   **Gestão de Permissões:** Executa `chown` automático para garantir que o utilizador actual tem acesso de escrita em `$LFS`, evitando o uso desnecessário de `sudo` durante a compilação.
*   **Chain Loading:** Executa automaticamente o `00-env.sh` após a montagem, entregando o ambiente pronto a usar.

---

### 5. `00-env.sh` — Configuração da Shell de Build

**Script:** `scripts/build/00-env.sh`  
**Fase:** 1 (Toolchain)  
**Execução:** No HOST (via `source`)

#### 🧠 Decisões de Design & Filosofia Vëra
Este é o script mais crítico para a integridade da build. Ele isola o ambiente da shell das "sujeiras" do sistema operativo anfitrião.

*   **Limpeza de PATH:**
    *   Remove `/usr/local/bin`, `/usr/sbin`, etc.
    *   Define `PATH="$LFS/tools/bin:/bin:/usr/bin"`.
    *   **Motivo:** Impede que o compilador use ferramentas do Host (ex: `grep` ou `sed` com flags diferentes) acidentalmente.
*   **Destruição de Variáveis Perigosas:**
    *   `unset LD_LIBRARY_PATH`: Impede que o linker procure libs em paths errados.
    *   `unset CFLAGS/CXXFLAGS`: Garante que flags de optimização do Host não poluam a build da Vëra.
*   **Locale POSIX:** Força `LC_ALL=POSIX`. Bugs de internacionalização (i18n) durante a compilação de `glibc` ou `bash` são infames e difíceis de debugar. O ambiente de build deve ser "burro" e determinístico.
*   **Umask 022:** Garante que ficheiros criados durante a instalação não fiquem com permissões demasiado restritivas ou permissivas.
*   **Target Triplet:** Exporta `LFS_TGT=x86_64-linux-musl`, definindo a identidade arquitectural da distribuição.

#### 🔄 Workflow
1.  Verifica se `$LFS` existe.
2.  Limpa variáveis host.
3.  Define `PATH` e `LC_ALL`.
4.  Exporta `LFS_TGT`.
5.  Imprime resumo de validação para o utilizador confirmar.

---

## 🛠️ Troubleshooting da Fase 0

| Problema | Causa Provável | Solução Vëra |
|----------|----------------|--------------|
| `check-host.sh` falha em `gcc` | Versão do gcc < 11.2 ou não instalado. | Instalar `build-essential` (Debian/Ubuntu) ou `base-devel` (Arch). |
| `setup-env.sh` aborta por espaço | Disco cheio ou partição pequena. | Expandir VM ou disco. Mínimo 15GB recomendado. |
| `download-sources.sh` falha MD5 | Download corrompido ou mirror desactualizado. | Apagar o ficheiro `.tar.xz` e re-executar o script. |
| `00-env.sh` dá erro de permissão | Tentativa de executar com `sudo`. | Usar `source` como utilizador normal. `sudo` estraga o ambiente de variáveis. |
| `/mnt/lfs` não monta | Imagem `lfs.img` em falta ou loop device ocupado. | Verificar se ficheiro existe. Executar `losetup -d /dev/loopX` se necessário. |

---

## 🔗 Integração no Roadmap

Estes scripts cobrem a transição entre a **Fase 0** e o início da **Fase 1**:

1.  **Fase 0 (Fundação):** `check-host`, `setup-env`, `download-sources`.
    *   *Resultado:* Ambiente pronto, fontes baixadas, host validado.
2.  **Início Fase 1 (Toolchain):** `setup-lfs-env`, `00-env`.
    *   *Resultado:* `$LFS` montado, shell configurada para compilar Binutils e GCC.

**Próximo Passo:** Executar `01-binutils-pass1.sh` para iniciar a construção da toolchain temporária.
