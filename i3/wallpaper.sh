#!/usr/bin/env bash
# Random wallpaper: an image of wallpapers/ (png / jpg), the same on every monitor.
#   wallpaper.sh          sets it as the desktop background (feh; i3 start / reload)
#   wallpaper.sh --pick   only prints its path (lock.sh: picked independently of the desktop one)
export PATH="$HOME/.nix-profile/bin:$PATH"
dir="$(dirname "$(readlink -f "$0")")/wallpapers"
img=$(find "$dir" -maxdepth 1 -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \) | shuf -n1)
[ -n "$img" ] || exit 1
if [ "$1" = --pick ]; then echo "$img"; else feh --bg-fill "$img"; fi
