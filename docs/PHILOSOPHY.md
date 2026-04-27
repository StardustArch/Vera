# Vëra Phase 3 Philosophy & Architectural Guidelines
> *"Nada é ativado por padrão. Tudo é explícito. O utilizador é o único dono."*

## 🎯 Princípios Fundamentais
1. **Explícito > Implícito**: Nenhum serviço, daemon, binding ou configuração existe sem uma declaração clara do utilizador.
2. **Minimal por Defeito**: A instalação base fornece apenas o necessário para funcionar. O resto é escolha.
3. **Transparência Radical**: Se algo roda, o utilizador sabe o quê, porquê e como parar/substituir.
4. **Substituibilidade Garantida**: Nenhum componente é obrigatório ou acoplado a ponto de impedir a troca por alternativas equivalentes.

## 🏗️ Decisões Arquiteturais (Fase 3)
### Init System: `runit`
- **Porquê**: 3 estágios claros, supervisão de processos simples, scripts em shell puro, zero dependências ocultas.
- **Trade-off**: Menos features out-of-the-box que systemd/OpenRC, mas totalmente auditável e extensível.
- **Fallback**: OpenRC permanece como alternativa documentada em `vera-ports`.

### Ambiente Gráfico: Sway (Wayland)
- **Porquê**: Configuração em texto puro, compatibilidade com lógica i3, sem serviços de background não solicitados.
- **Zero Magia**: Sem auto-mount, sem auto-start de apps, sem daemons gráficos ocultos.
- **Configuração**: `~/.config/sway/config` é a única fonte de verdade. Versionável em `vera-dots`.

### Agente Vex: Modelo Local (`llama.cpp`)
- **Porquê**: Privacidade total, zero telemetria, funcionamento offline, prompt visível e editável.
- **Requisito Mínimo**: 8GB RAM para `TinyLlama-1.1B` ou similar. Se indisponível, Vex degrada para modo "comandos pré-definidos".
- **Proibido**: Fallback automático para APIs externas sem consentimento explícito do utilizador.

### Dotfiles & Identidade (`vera-dots`)
- Shell: `bash` (padrão) ou `zsh/fish` (opcional, via ports)
- Prompt: Minimal, cores explícitas, sem plugins que rodem em background
- Tema: Alto contraste, legível, sem dependências de GUI ou caches pesados

## 🚫 O Que Não Entra (e Porquê)
| Componente | Razão da Exclusão | Filosofia Aplicada |
|------------|-------------------|-------------------|
| `systemd` | Complexidade oculta, dependências implícitas, journal binário | ❌ Explícito > implícito |
| GNOME/KDE | Serviços automáticos, config GUI/dconf, "magic" everywhere | ❌ Utilizador é o dono |
| LLM API (por padrão) | Telemetria, dependência externa, custo oculto | ❌ Transparência radical |
| Auto-update/Phone-home | Viola princípio de controlo total do utilizador | ❌ Zero compromissos |

## 🔍 Framework de Decisão (Novos Componentes)
Antes de adicionar qualquer pacote à Fase 3, responder:
1. O utilizador sabe que isto vai rodar? (Sim/Não)
2. Pode ser desativado sem quebrar o sistema? (Sim/Não)
3. A configuração é versionável e editável em texto puro? (Sim/Não)
4. Substituir isto por uma alternativa equivalente é trivial? (Sim/Não)
→ Se alguma resposta for **Não**, o componente não entra no core.

## 📅 Marcos da Fase 3 (Meses 15–20)
- [ ] `runit` integrado e documentado
- [ ] Sway + config mínima funcional
- [ ] Vex v1 (CLI local, modelo leve)
- [ ] `vera-dots` com shell/prompt/wallpaper base
- [ ] Primeira sessão desktop completa e auditável
- [ ] **Milestone 3**: Vëra usável como distro principal

## 📖 Referências
- Roadmap Oficial: `vera_roadmap_detalhado.html`
- LFS Book: https://www.linuxfromscratch.org/lfs/view/stable/
- runit docs: http://smarden.org/runit/
- Sway config: https://github.com/swaywm/sway/wiki
- llama.cpp: https://github.com/ggerganov/llama.cpp

*Última atualização: 2026-04-26 | Mantido por: equipa Vëra*