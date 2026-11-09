#!/usr/bin/env bash
# Debian 12 workstation without Nix: links the dotfiles of this repo into $HOME, clones
# oh-my-zsh / TPM and their plugins, installs the Nerd Fonts. Re-runnable: existing links are
# refreshed, a real file in the way is moved to <file>.bak.<timestamp>. apt packages and the
# tools outside apt (neovim, lazygit, node): OPENCODE_PROMPT.md, run that first.
#
#   ./install.sh           everything
#   ./install.sh --links   only the symlinks
set -euo pipefail

REPO=$(cd "$(dirname "$(readlink -f "$0")")" && pwd)

say() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*" >&2; }

# link SRC DEST (SRC relative to the repo)
link() {
  local src=$REPO/$1 dest=$2
  [ -e "$src" ] || { warn "missing source: $src"; return 0; }
  mkdir -p "$(dirname "$dest")"
  if [ -e "$dest" ] && [ ! -L "$dest" ]; then
    mv "$dest" "$dest.bak.$(date +%s)"
    warn "moved existing $dest to $dest.bak.*"
  fi
  ln -sfn "$src" "$dest"
}

# real_dir DIR: a real directory (an old symlink to a whole folder is removed)
real_dir() { [ -L "$1" ] && rm "$1"; mkdir -p "$1"; }

clone() {  # clone OWNER/REPO DEST
  if [ -d "$2/.git" ]; then git -C "$2" pull -q --ff-only || warn "could not update $2"
  else git clone -q --depth 1 "https://github.com/$1" "$2"; fi
}

links() {
  say "Symlinks"
  link nvim                  "$HOME/.config/nvim"
  link rofi/config.rasi      "$HOME/.config/rofi/config.rasi"
  link xresources/Xresources "$HOME/.Xresources"
  link tmux/tmux.conf        "$HOME/.tmux.conf"
  link zsh/zshrc             "$HOME/.zshrc"
  link alacritty/alacritty.yml  "$HOME/.config/alacritty/alacritty.yml"
  link alacritty/alacritty.toml "$HOME/.config/alacritty/alacritty.toml"
  link picom/picom.conf      "$HOME/.config/picom/picom.conf"
  link dunst/dunstrc         "$HOME/.config/dunst/dunstrc"
  link scripts/tmux-session-picker.sh "$HOME/.local/bin/tmux-session-picker.sh"

  # i3 and polybar: file by file (the scripts call each other through ~/.config/i3, ~/.config/polybar)
  local dir f
  for dir in i3 polybar; do
    real_dir "$HOME/.config/$dir"
    for f in "$REPO/$dir"/*; do
      link "$dir/$(basename "$f")" "$HOME/.config/$dir/$(basename "$f")"
    done
  done

  # Debian names fd / bat fdfind / batcat
  mkdir -p "$HOME/.local/bin"
  command -v fdfind >/dev/null && ! command -v fd >/dev/null && ln -sfn "$(command -v fdfind)" "$HOME/.local/bin/fd"
  command -v batcat >/dev/null && ! command -v bat >/dev/null && ln -sfn "$(command -v batcat)" "$HOME/.local/bin/bat"
  return 0
}

gitconfig() {
  # Shared settings / aliases through an include; the identity stays in ~/.gitconfig (git config --global)
  if git config --global --get-all include.path 2>/dev/null | grep -qxF "$REPO/git/gitconfig"; then
    return 0
  fi
  say "~/.gitconfig: include $REPO/git/gitconfig"
  git config --global --add include.path "$REPO/git/gitconfig"
  git config --global --get user.email >/dev/null || warn "no git identity yet: git config --global user.name / user.email"
  return 0
}

plugins() {
  say "oh-my-zsh + plugins"
  clone ohmyzsh/ohmyzsh "$HOME/.oh-my-zsh"
  local custom="$HOME/.oh-my-zsh/custom/plugins"
  clone zsh-users/zsh-autosuggestions        "$custom/zsh-autosuggestions"
  clone zsh-users/zsh-syntax-highlighting    "$custom/zsh-syntax-highlighting"
  clone joshskidmore/zsh-fzf-history-search  "$custom/zsh-fzf-history-search"

  say "tmux plugin manager (prefix Alt+w then I inside tmux installs the plugins)"
  clone tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
  "$HOME/.tmux/plugins/tpm/bin/install_plugins" >/dev/null 2>&1 || warn "TPM plugins: run prefix + I inside tmux"
}

fonts() {
  # Nerd Fonts used by alacritty (Hack), i3 / polybar / rofi menus (JetBrainsMono, + Propo)
  local dir="$HOME/.local/share/fonts/NerdFonts" name
  mkdir -p "$dir"
  for name in Hack JetBrainsMono FiraCode; do
    if ls "$dir/$name"/*.ttf >/dev/null 2>&1; then continue; fi
    say "Nerd Font $name"
    mkdir -p "$dir/$name"
    curl -fsSL "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/$name.tar.xz" \
      | tar -xJ -C "$dir/$name" || warn "could not download the $name Nerd Font"
  done
  fc-cache -f "$dir" >/dev/null
}

case "${1:-all}" in
  --links) links ;;
  all)
    links
    gitconfig
    plugins
    fonts
    [ "$(basename "${SHELL:-}")" = zsh ] || warn "login shell is not zsh: chsh -s /bin/zsh"
    say "Done. Log out, pick the i3 session at login. In nvim, lazy.nvim and Mason install on first start."
    ;;
  *) echo "usage: $0 [--links]" >&2; exit 1 ;;
esac
