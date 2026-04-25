```
                                        ██╗   ██╗███████╗██████╗  █████╗
                                        ██║   ██║██╔════╝██╔══██╗██╔══██╗
                                        ██║   ██║█████╗  ██████╔╝███████║
                                        ╚██╗ ██╔╝██╔══╝  ██╔══██╗██╔══██║
                                         ╚████╔╝ ███████╗██║  ██║██║  ██║
                                          ╚═══╝  ╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝
```
<div align="center">
<br/>
 
**Your system. Your rules. Your truth.**
 
*An independent Linux distribution built from scratch, with its own package manager, its own philosophy, and zero compromises.*
 
<br/>
![Status](https://img.shields.io/badge/status-in%20development-534AB7?style=flat-square)
![Phase](https://img.shields.io/badge/phase-0%20%E2%80%94%20foundation-1D9E75?style=flat-square)
![License](https://img.shields.io/badge/license-MIT-AFA9EC?style=flat-square)
![Built with](https://img.shields.io/badge/built%20with-LFS-26215C?style=flat-square)
 
</div>
---
 
## What is Vëra?
 
Vëra is a Linux distribution built entirely from source — no Debian base, no Arch underneath, no inherited decisions. Every component is chosen deliberately, every package has a reason to exist, and every configuration is explicit.
 
This is not a distro for everyone. It is a distro for one person who got tired of inheriting other people's choices.
 
If you are looking for an out-of-the-box experience, Vëra is not for you.  
If you want to understand exactly what runs on your machine and why — welcome.
 
---
 
## Philosophy
 
> *The user is the only owner of the system.*
 
Three principles guide every decision in Vëra:
 
**Explicit over implicit** — nothing runs without your knowledge. No background services you didn't ask for. No magic that "just works" and breaks when you look at it.
 
**Purpose over completeness** — a package that isn't needed doesn't exist in Vëra. The base system is minimal by design, not by accident.
 
**Durability over novelty** — this distro is being built to last years. Stability and understanding matter more than bleeding-edge versions.
 
---
 
## Repositories
 
This organisation is split into focused repositories. Each one has a single responsibility.
 
| Repo | Description | Status |
|------|-------------|--------|
| [`vera`](.) | This file. Philosophy, roadmap, contributing guide. | active |
| [`vera-core`](../vera-core) | LFS build scripts, patches, base system configuration. | 🔨 building |
| [`vera-pkg`](../vera-pkg) | The Vëra package manager — resolver, CLI, binary cache. | 📋 planned |
| [`vera-ports`](../vera-ports) | Package recipes, one directory per package. | 📋 planned |
| [`vera-vex`](../vera-vex) | Vex — the native terminal assistant. Ships with Vëra, installable elsewhere. | 📋 planned |
| [`vera-dots`](../vera-dots) | Default dotfiles, theme, wallpapers, desktop environment configs. | 📋 planned |
| [`vera-site`](../vera-site) | Static site — documentation, blog, ISO download. | 📋 planned |
 
---
 
## Roadmap
 
### Phase 0 — Foundation *(now)*
- [ ] Define init system (evaluating OpenRC vs custom)
- [ ] Study and document LFS chapter by chapter
- [ ] Set up cross-compilation toolchain
- [ ] Write first automated build script
### Phase 1 — Bootable base system
- [ ] Compile LFS system base from scratch
- [ ] First successful boot on real hardware
- [ ] Minimal working shell environment
- [ ] Document every build decision
### Phase 2 — Package management
- [ ] Design `vera-pkg` architecture and CLI
- [ ] Implement dependency resolver
- [ ] Create `vera-ports` format and first 20 packages
- [ ] Self-hosting: Vëra can rebuild itself
### Phase 3 — Identity and tools
- [ ] Integrate Vex (terminal assistant) as native component
- [ ] Default dotfiles and desktop configuration
- [ ] First complete usable desktop session
### Phase 4 — Public release
- [ ] Automated ISO build pipeline
- [ ] Documentation site live
- [ ] First public ISO release
---
 
## Current state
 
Vëra is in **Phase 0**. The system does not boot yet. There is no package manager. There is no ISO.
 
What exists: a clear philosophy, a defined architecture, and a person who is going to build this over the next two years regardless.
 
Follow the journey through the commit history. Every build script added is a real step forward.
 
---
 
## Mascot
 
Meet **Vex** — a geometric fox who sees everything and judges nothing. The green ears mean the system is listening.
 
*Vex SVG assets live in `vera-dots/assets/mascot/`.*
 
---
 
## Why build from scratch instead of forking?
 
Because forking inherits decisions. Every distro carries the weight of choices made by people with different priorities, different users, different years.
 
Vëra starts from zero so that every decision made here is a conscious one. The goal is not to reinvent Linux — it is to understand it completely, by building it.
 
After two years of this, there will be no part of this system I cannot explain.
 
---
 
## Contributing
 
Vëra is a personal project. It is not looking for contributors right now.
 
If you are building something similar and want to exchange notes, open a Discussion. Ideas are always welcome.
 
---
 
## License
 
MIT — do whatever you want with this. Attribution appreciated, not required.
 
---
 
<div align="center">
<br/>
<sub>Built on Mozambique time. Powered by curiosity and strong coffee.</sub>
<br/><br/>
</div>
 
