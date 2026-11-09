#!/usr/bin/env bash
# Runs a TUI in a floating terminal (i3 rule on class AlacrittyPopup), inside its own tmux
# session named like the other popups: popup-<cmd>-<rand>.
#   term-popup.sh [VAR=value...] CMD [ARGS...]
# The session ends with the command (q in yazi closes the window) or with the window.
# POPUP_INSTANCE (env): X instance of the window, class stays AlacrittyPopup (i3 rules): tells
# its type apart (window-type.jq, e.g. AudioPopup for termusic-play.sh)
# POPUP_FONT_SIZE (env): font size, 14 by default
export PATH="$HOME/.nix-profile/bin:$PATH"
unset TMUX  # also works when started from inside tmux
# Leading VAR=value arguments: environment of the command (the session's, tmux doesn't pass ours)
env=()
while [[ "${1:-}" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]]; do env+=(-e "$1"); shift; done
cmd=$(basename "$1")
# i3 hides floating windows behind a fullscreen one: leave fullscreen first (focused window)
i3-msg -q fullscreen disable 2>/dev/null
# Bigger font than the main terminals (10): read from further away, the popup is centered and large
exec alacritty --class "AlacrittyPopup,${POPUP_INSTANCE:-AlacrittyPopup}" -o "font.size=${POPUP_FONT_SIZE:-14}" -e \
  tmux new-session -s "popup-$cmd-$(date +%s | tail -c 4)" "${env[@]}" "$@" \; set-option destroy-unattached on
