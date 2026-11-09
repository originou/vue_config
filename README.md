# vue_config

Dotfiles pour un poste Debian 12 (bookworm) sans Nix, apt via un miroir d'entreprise :
i3, polybar, rofi, picom, dunst, alacritty, tmux, zsh (oh-my-zsh), neovim (lazy.nvim + Mason).

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
| neovim | `~/.config/nvim` | lazy.nvim, LSP via Mason, telescope, treesitter, neo-tree… (`deck.lua` ne fait rien sans xdotool) |
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
- lazygit absent, node 18 (Copilot veut >= 22) : hors apt aussi.

Wallpapers : Vincent Guth (aurora), Mikael Gustafsson.
