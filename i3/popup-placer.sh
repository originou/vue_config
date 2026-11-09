#!/usr/bin/env bash
# Places new popup windows (class or instance matching below) so they don't all open stacked at the center:
#   1. the free spot (no overlap with other floating windows) closest to the center of the screen
#   2. otherwise cascaded from the center, 40 px per popup already on that workspace
# A size requested by popup-open.sh (content-fitted, keyed by the window title = file name) is
# applied in the same move, as soon as the window shows up or gets its title.
# Started by i3 (exec_always); a new instance replaces the previous one.

popups='^(AlacrittyPopup|EvincePopup|EogPopup|VlcPopup|MpvPopup|NsxivPopup)$'
step=50     # grid step (px) when looking for a free spot
gap=8       # space kept between windows
cascade=40  # offset per stacked popup
sizes="${XDG_RUNTIME_DIR:-/tmp}/popup-sizes"  # written by popup-open.sh: <title> -> "<who> <w> <h>"

# place ID [W H]: position (and size, when given) computed and applied in one i3 command,
# so the window doesn't visibly jump twice
place() {
  local id=$1 size_w=${2:-0} size_h=${3:-0} target
  target=$(i3-msg -t get_tree | jq -r --argjson id "$id" --argjson step "$step" \
    --argjson gap "$gap" --argjson cascade "$cascade" --arg re "$popups" \
    --argjson sw "$size_w" --argjson sh "$size_h" '
    # Workspace holding the window, its floating containers, and the window own container
    [.. | objects | select(.type? == "workspace")
        | select([.. | objects | select(.id? == $id)] | length > 0)] | first as $ws
    | ($ws.floating_nodes | map(select([.. | objects | select(.id? == $id)] | length > 0)) | first) as $me
    | ($ws.floating_nodes | map(select(.id != $me.id)) | map(.rect)) as $others
    | ($ws.floating_nodes | map(select(.id != $me.id)
        | select([.. | objects | select(.window_properties? // {} | (.class // "" | test($re)) or (.instance // "" | test($re)))] | length > 0))
        | length) as $stacked
    | $ws.rect as $area
    | (if $sw > 0 then $sw else $me.rect.width end) as $w
    | (if $sh > 0 then $sh else $me.rect.height end) as $h
    | ($area.x + (($area.width - $w) / 2 | floor)) as $cx
    | ($area.y + (($area.height - $h) / 2 | floor)) as $cy
    | def free($x; $y): all($others[];
        ($x + $w + $gap <= .x) or (.x + .width + $gap <= $x) or
        ($y + $h + $gap <= .y) or (.y + .height + $gap <= $y));
      # Candidates: a coarse grid, plus spots snapped next to / aligned with the other windows
      # (the grid alone misses exact fits, e.g. a row of popups just above the centered one)
      ( [range($area.x; $area.x + $area.width - $w + 1; $step)]
        + [$area.x, $area.x + $area.width - $w]
        + [$others[] | .x, .x + .width + $gap, .x - $w - $gap, .x + .width - $w] ) as $xs
    | ( [range($area.y; $area.y + $area.height - $h + 1; $step)]
        + [$area.y, $area.y + $area.height - $h]
        + [$others[] | .y, .y + .height + $gap, .y - $h - $gap, .y + .height - $h] ) as $ys
    | [ ($xs | unique[]) as $x | ($ys | unique[]) as $y
      | select($x >= $area.x and $x + $w <= $area.x + $area.width
               and $y >= $area.y and $y + $h <= $area.y + $area.height)
      | select(free($x; $y))
      | {x: $x, y: $y, d: (($x - $cx) * ($x - $cx) + ($y - $cy) * ($y - $cy))} ]
    | if ($others | length) == 0 then "\($cx) \($cy)"
      elif length > 0 then (min_by(.d) | "\(.x) \(.y)")
      else
        # No free spot: cascade from the center, kept inside the workspace
        ([$cx + $stacked * $cascade, $area.x + $area.width - $w] | min) as $x
        | ([$cy + $stacked * $cascade, $area.y + $area.height - $h] | min) as $y
        | "\($x) \($y)"
      end')
  [ -n "$target" ] || return
  read -r x y <<<"$target"
  if [ "$size_w" -gt 0 ]; then
    i3-msg "[con_id=$id] resize set $size_w px $size_h px, move position $x px $y px" >/dev/null
    # VLC may restore a remembered window size a moment later: put ours back if it did
    ( sleep 1.5
      i3-msg -t get_tree | jq -e --argjson id "$id" --argjson w "$size_w" --argjson h "$size_h" '
        .. | objects | select(.type? == "floating_con") | select([.nodes[]? | select(.id == $id)] | length > 0)
        | select(.rect.width != $w or .rect.height != $h)' >/dev/null &&
        i3-msg "[con_id=$id] resize set $size_w px $size_h px" >/dev/null ) &
  else
    i3-msg "[con_id=$id] move position $x px $y px" >/dev/null
  fi
}

# lookup TITLE WHO: "w h" requested by popup-open.sh for this window (entry consumed), if any
lookup() {
  local name=${1% - VLC media player} file for w h
  file="$sizes/${name//\//_}"
  [ -s "$file" ] && read -r for w h < "$file" && [ "$for" = "$2" ] || return 1
  rm -f "$file"
  echo "$w $h"
}

# One-shot: popup-placer.sh --place CON_ID... places existing windows (one after the other, so
# each one avoids the previous) and exits, without touching the running daemon.
# Used by polybar/scratchpad-actions.sh after moving popups to another workspace.
if [ "${1:-}" = --place ]; then
  shift
  for id in "$@"; do place "$id"; done
  exit 0
fi

# Single instance: exec_always runs again on every i3 restart. Stop the whole process group of
# the previous instance (its event loop and i3-msg subscription are child processes).
pidfile="${XDG_RUNTIME_DIR:-/tmp}/popup-placer.pid"
if [ -f "$pidfile" ]; then
  old_pgid=$(ps -o pgid= -p "$(cat "$pidfile")" 2>/dev/null | tr -d ' ')
  [ -n "$old_pgid" ] && [ "$old_pgid" != "$(ps -o pgid= -p $$ | tr -d ' ')" ] && kill -- "-$old_pgid" 2>/dev/null
fi
echo $$ > "$pidfile"

declare -A waiting  # popups placed without a size yet: con id -> time, until their title shows up

# Focus of the popups opened from yazi: Enter takes it, o doesn't. yazi writes "focus" or
# "nofocus" here just before opening (popup-focus.yazi, smart-enter.yazi); it applies to the
# popups showing up within 5 s. Older or missing: each window type's default (i3 config: the
# terminal popups take the focus, no_focus for the image / PDF / video ones)
focus_flag="${XDG_RUNTIME_DIR:-/tmp}/popup-focus"
focus_mode() {
  [ -f "$focus_flag" ] && (( $(date +%s) - $(stat -c %Y "$focus_flag") <= 5 )) && cat "$focus_flag"
}
declare -A unfocus  # nofocus popups: con id -> creation time; focus given back if i3 focuses them
                    # within 3 s (later: the user clicked them, left alone)
last_focus=""       # the window focused before (yazi's terminal), to give the focus back to

i3-msg -t subscribe -m '["window"]' | jq --unbuffered -r --arg re "$popups" '
  .container.window_properties as $p
  | (($p.class // "" | test($re)) or ($p.instance // "" | test($re))) as $popup
  | select(.change == "focus" or ((.change == "new" or .change == "title") and $popup))
  | [.change, .container.id,
     (if ($p.class // "" | test($re)) then $p.class else ($p.instance // "-") end),
     (.container.name // "")] | @tsv' |
while IFS=$'\t' read -r change id who name; do
  if [ "$change" = focus ]; then
    if [ -n "${unfocus[$id]}" ]; then
      (( SECONDS - unfocus[$id] <= 3 )) && [ -n "$last_focus" ] && i3-msg -q "[con_id=$last_focus] focus"
      unset "unfocus[$id]"
    else
      last_focus=$id
    fi
    continue
  fi
  # No delay: i3 has already applied its for_window rule (floating) when it sends the event
  if [ "$change" = new ]; then
    if size=$(lookup "$name" "$who"); then
      place "$id" $size
    else
      place "$id"
      waiting[$id]=$SECONDS
    fi
    case "$(focus_mode)" in
      focus)   i3-msg -q "[con_id=$id] focus" ;;
      nofocus) unfocus[$id]=$SECONDS ;;
    esac
  elif [ -n "${waiting[$id]}" ]; then  # title set after the window showed up
    if (( SECONDS - waiting[$id] > 10 )); then
      unset "waiting[$id]"
    elif size=$(lookup "$name" "$who"); then
      unset "waiting[$id]"
      place "$id" $size
    fi
  fi
done
