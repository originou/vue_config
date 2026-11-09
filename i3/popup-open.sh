#!/usr/bin/env bash
# Opens files in floating popups sized to their content (no black bars), within a max size:
#   popup-open.sh image|video|mpv|pdf FILE...   (video = VLC, mpv = mpv without any UI)
# All sizes are computed first, then every file is launched at once (one window each).
# popup-placer.sh recognises each window by its title (the file name) and applies its size.

kind=$1
shift

sizes="${XDG_RUNTIME_DIR:-/tmp}/popup-sizes"  # one file per expected window title: "<who> <w> <h>"
mkdir -p "$sizes"
find "$sizes" -type f -mmin +1 -delete  # leftovers of windows that never showed up

# Max window size, and the space taken by the app UI around the content (measured)
case "$kind" in
  image) max_w=1000 max_h=700  chrome_w=12 chrome_h=67  min_w=420 popup=EogPopup ;;    # eog: header bar + padding
  video) max_w=1280 max_h=760  chrome_w=10 chrome_h=27  min_w=480 popup=VlcPopup ;;    # vlc minimal view: only the i3 title bar (22) + 5 px border
  mpv)   max_w=1280 max_h=760  chrome_w=10 chrome_h=27  min_w=480 popup=MpvPopup ;;    # mpv: only the i3 title bar + 5 px border
  pdf)   max_w=1000 max_h=1350 chrome_w=48 chrome_h=84  min_w=480 popup=EvincePopup ;; # evince: header + page margins
  *) echo "usage: popup-open.sh image|video|mpv|pdf FILE..." >&2; exit 1 ;;
esac

# Content size (pixels, or points for a PDF page), empty if unknown
content_size() {
  case "$kind" in
    image) magick identify -format '%w %h\n' "$1[0]" 2>/dev/null | head -1 ;;
    video|mpv) # csv separator can't be a space; rotation (phone videos) is read separately
           echo "$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height \
                     -of csv=p=0:s=x "$1" 2>/dev/null | head -1 | tr x ' ') \
                 $(ffprobe -v error -select_streams v:0 -show_entries stream_side_data=rotation \
                     -of csv=p=0 "$1" 2>/dev/null | grep -m1 -oE '^-?[0-9]+')" ;;
    pdf)   pdfinfo "$1" 2>/dev/null | awk '/^Page size:/ { print $3, $5; exit }' ;;
  esac
}

# Largest window keeping the content ratio inside the max size; images are not upscaled
window_size() {
  awk -v cw="$1" -v ch="$2" -v rot="${3:-0}" -v mw="$max_w" -v mh="$max_h" \
      -v xw="$chrome_w" -v xh="$chrome_h" -v minw="$min_w" -v kind="$kind" 'BEGIN {
    if (rot == 90 || rot == -90 || rot == 270 || rot == -270) { t = cw; cw = ch; ch = t }
    s = (mw - xw) / cw; if ((mh - xh) / ch < s) s = (mh - xh) / ch
    if (kind == "image" && s > 1) s = 1
    w = int(cw * s + xw + 0.5); h = int(ch * s + xh + 0.5)
    if (w < minw) w = minw
    print w, h
  }'
}

# Window titles are the file name (evince: the PDF title when it has one); "/" can't be in a file name
key() { printf '%s' "${1//\//_}"; }

# Skip the files already open in a popup of this kind (window title = file name, or the PDF
# title; VLC adds " - VLC media player")
open_titles=$(i3-msg -t get_tree | jq -r --arg who "$popup" '.. | objects
  | select(.window_properties? and ((.window_properties.class // "") == $who or (.window_properties.instance // "") == $who))
  | .name // "" | sub(" - VLC media player$"; "")')
files=()
for f in "$@"; do
  name=$(basename "$f")
  patterns=(-e "$name")
  if [ "$kind" = pdf ]; then
    title=$(pdfinfo "$f" 2>/dev/null | sed -n 's/^Title: *//p')
    [ -n "$title" ] && patterns+=(-e "$title")
  fi
  grep -qxF "${patterns[@]}" <<<"$open_titles" && continue
  files+=("$f")
done
set -- "${files[@]}"
[ $# -gt 0 ] || exit 0

# One window per file: refuse big selections (opened from yazi, so the message is a notification)
max_files=20
if [ $# -gt "$max_files" ]; then
  notify-send -i dialog-warning "Too many files" \
    "$# files selected, $max_files popups at most: select fewer files (or use T for a thumbnail grid)."
  exit 1
fi

# 1. Sizes for every file (fast: metadata only)
for f in "$@"; do
  read -r cw ch rot <<<"$(content_size "$f")"
  [ -n "$cw" ] && [ -n "$ch" ] && [ "$cw" != 0 ] && [ "$ch" != 0 ] || continue  # unknown: i3 rule size
  size="$popup $(window_size "$cw" "$ch" "$rot")"
  echo "$size" > "$sizes/$(key "$(basename "$f")")"
  if [ "$kind" = pdf ]; then
    title=$(pdfinfo "$f" 2>/dev/null | sed -n 's/^Title: *//p')
    [ -n "$title" ] && echo "$size" > "$sizes/$(key "$title")"
  fi
done

# 2. Launch them all, slightly staggered (simultaneous starts step on each other)
for f in "$@"; do
  case "$kind" in
    image) eog --class=EogPopup "$f" ;;
    # Minimal view: no menu, controls or status bar (Ctrl+H in VLC shows them back)
    video) RESOURCE_NAME=VlcPopup vlc --no-qt-video-autoresize --qt-minimal-view "$f" ;;
    # Title = file name (what popup-placer.sh and the "already open" check look for)
    mpv)   mpv --x11-name=MpvPopup --title='${filename}' --force-window=immediate "$f" ;;
    pdf)   evince --class=EvincePopup "$f" ;;
  esac >/dev/null 2>&1 &
  sleep 0.15
done
