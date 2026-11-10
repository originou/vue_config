# vue_config

Dotfiles pour un poste Debian 12 (bookworm) sans Nix, apt via un miroir d'entreprise :
i3, polybar, rofi, picom, dunst, alacritty, tmux, zsh (oh-my-zsh), neovim (AstroNvim + Mason).

## Installation

```bash
git clone https://github.com/originou/vue_config.git ~/vue_config
cd ~/vue_config
opencode   # puis coller le prompt de OPENCODE_PROMPT.md
```

Le prompt fait installer les paquets apt (`packages.txt`), neovim / lazygit / node hors apt dans
`~/.local`, puis lance `./install.sh`. À la main : `./install.sh` (re-lançable ; `--links` pour
juste les liens). Identité git ensuite :
`git config --global user.name … && git config --global user.email …`.

## Contenu

| Outil | Lien créé | Notes |
|---|---|---|
| tmux | `~/.tmux.conf` | préfixe Alt+w, TPM (resurrect, continuum, menus F9, suspend F12), thème nord, prefix s = sélecteur de sessions fzf |
| alacritty | `~/.config/alacritty/alacritty.{yml,toml}` | `.yml` pour la 0.11 d'apt, `.toml` pour une version récente ; chaque fenêtre ouvre sa session tmux |
| neovim | `~/.config/nvim` | AstroNvim v6 : sessions par projet, statusline façon LazyVim (état git), which-key épuré, Neo-tree (diff `gd`), favoris de lignes, undo persistant, requêtes HTTP (kulala)… ; LSP et outils via Mason (voir `nvim/README.md`) |
| i3 | `~/.config/i3/` | config + scripts (move-dir, float-toggle, focus-last Super+Tab, minimize Super+-, popups, wallpaper) |
| polybar | `~/.config/polybar/` | une barre : workspaces, fenêtre, scratchpad, cpu, mémoire, disque, volume, réseau, date, power |
| rofi | `~/.config/rofi/config.rasi` | thème material |
| picom | `~/.config/picom/picom.conf` | backend xrender, sans flou ni animations (picom 10, VM sans GPU) |
| dunst | `~/.config/dunst/dunstrc` | |
| zsh | `~/.zshrc` | oh-my-zsh agnoster, autosuggestions, syntax-highlighting, fzf-history, zoxide ; `~/.zshrc.local` pour le spécifique (proxy…) |
| git | include dans `~/.gitconfig` | alias et réglages, sans identité |
| X | `~/.Xresources` | |

## Limites de bookworm

- neovim apt = 0.7 : trop vieux, installé depuis la release GitHub (>= 0.11) dans `~/.local`.
- alacritty apt = 0.11 : lit le YAML, d'où `alacritty.yml`.
- picom apt = 10 : pas d'animations ni de backend egl.
- lazygit absent, node 18 (vieux pour certains serveurs de langage) : hors apt aussi.
- go 1.19 et Java 17 : trop vieux pour gopls et jdtls que Mason installe (Go récent, Java 21+).

Wallpapers : Vincent Guth (aurora), Mikael Gustafsson.
