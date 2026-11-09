#!/usr/bin/env bash
# $mod+Shift+space: toggle floating and switch the border style with it, like the popups:
#   floating -> title bar (drag to move) + 5 px border (drag to resize)
#   tiled    -> back to the thin tiling border
i3-msg -q floating toggle
state=$(i3-msg -t get_tree | jq -r 'first(.. | objects | select(.focused? == true)) | .floating')
case "$state" in
  *_on) i3-msg -q border normal 8 ;;
  *)    i3-msg -q border pixel 1 ;;
esac
