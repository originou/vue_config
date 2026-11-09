#!/usr/bin/env bash
# Workspace-scoped scratchpad toggle for i3 popups (floating windows).
#
#   popup-scratchpad-toggle.sh            toggle
#     - popups visible on the workspace -> ALL of them go to the scratchpad at once
#     - none visible                    -> the ones minimized from this workspace come back
#     Tiled windows are never touched.
#   popup-scratchpad-toggle.sh --restore  Polybar right click: bring back this workspace's popups
#   popup-scratchpad-toggle.sh --current  $mod+- : minimize the focused window, only if floating
#   popup-scratchpad-toggle.sh --minimize [--type TYPE]  minimize the visible popups (only those
#     of TYPE: image, pdf... window-type.jq). From the $mod+Shift+- menu (minimize-menu.sh)
#   --restore also takes --type TYPE
#
# Each minimized window gets an i3 mark _ws_<workspace>_<xid>: marks survive i3 reload/restart,
# so the Polybar module (scratchpad.sh) keeps counting them (minimize.jq). Positions are kept in
# $XDG_RUNTIME_DIR/i3-scratchpad/positions.json (keyed by X11 window id, also stable).
# Workspace: $1, else $MONITOR (Polybar), else the focused workspace.

set -euo pipefail

state_dir="${XDG_RUNTIME_DIR:-/tmp}/i3-scratchpad"
mkdir -p "$state_dir"
positions_file="$state_dir/positions.json"
[ -s "$positions_file" ] || echo "{}" > "$positions_file"

mode="toggle"
target=""
type=""
while [ $# -gt 0 ]; do
  case "$1" in
    --restore)  mode="restore" ;;
    --current)  mode="current" ;;
    --minimize) mode="minimize" ;;
    --type)     type="$2"; shift ;;
    *) target="$1" ;;
  esac
  shift
done
[ -n "$target" ] || target="${MONITOR:-}"

tree=$(i3-msg -t get_tree)

# Workspace name: visible workspace of output $target, or $target itself, or the focused one
ws=$(echo "$tree" | jq -r --arg target "$target" '
  if $target != "" then
    ( first(.nodes[] | select(.name == $target)
      | .nodes[] | select(.name == "content")
      | (.focus[0]) as $f | .nodes[] | select(.id == $f) | .name) ) // $target
  else
    first(.. | objects | select(.type? == "workspace")
      | select([.. | objects | select(.focused? == true)] | length > 0) | .name)
  end // ""')
[ -n "$ws" ] || exit 0

# Popups minimized from this workspace (only those of $type, if set): [{win, mark}]
minimized=$(echo "$tree" | jq -c -L "$HOME/.config/i3" --arg ws "$ws" --arg type "$type" '
  include "window-type";
  [ .. | objects | select(.name? == "__i3_scratch") | .floating_nodes[]?
    | (.nodes[0]? // .)
    | select($type == "" or window_type == $type)
    | ((.marks // []) | map(select(startswith("_ws_\($ws)_"))) | first) as $m
    | select($m != null)
    | {win: .window, mark: $m} ]')

restore() {
  [ "$(echo "$minimized" | jq 'length')" -gt 0 ] || return 1
  local cmd
  cmd=$(jq -r --argjson list "$minimized" '
    . as $p
    | [ $list[] | (.win | tostring) as $k
        | "[id=\(.win)] scratchpad show, unmark \(.mark)"
          + (if $p[$k] then ", move position \($p[$k].x) px \($p[$k].y) px" else "" end)
      ] | join("; ")' "$positions_file")
  # Forget the restored positions
  jq --argjson list "$minimized" '
    ($list | map(.win | tostring)) as $keys
    | with_entries(select(.key as $k | $keys | index($k) | not))' \
    "$positions_file" > "$positions_file.tmp" && mv "$positions_file.tmp" "$positions_file"
  i3-msg "$cmd" >/dev/null
}

if [ "$mode" = current ]; then
  # Focused window, if floating: same mark / saved position as a group minimize, so the
  # polybar module lists it and Win+Shift+- or the module brings it back
  current=$(echo "$tree" | jq -c '
    first(.. | objects | select(.type? == "workspace")
      | .name as $ws | .floating_nodes[]?
      | .rect as $r | (.nodes[0]? // .)
      | select(.focused == true and .window != null)
      | {ws: $ws, win: .window, x: $r.x, y: $r.y, marks: (.marks // [])}) // empty')
  [ -n "$current" ] || exit 0  # tiled or no window: nothing to do
  jq -L "$HOME/.config/i3" --argjson w "$current" 'include "minimize";
    reduce ([$w] | to_save($w.ws))[] as $w (.; .[$w.win | tostring] = {x: $w.x, y: $w.y})' \
    "$positions_file" > "$positions_file.tmp" && mv "$positions_file.tmp" "$positions_file"
  i3-msg "$(echo "$current" | jq -r -L "$HOME/.config/i3" 'include "minimize"; [.] | minimize_cmd(.[0].ws)')" >/dev/null
  exit 0
fi

if [ "$mode" = restore ]; then
  restore || true
  exit 0
fi

# Every popup (floating window) currently visible on this workspace (only those of $type, if set)
visible=$(echo "$tree" | jq -c -L "$HOME/.config/i3" --arg ws "$ws" --arg type "$type" '
  include "window-type";
  [ .. | objects | select(.type? == "workspace" and .name? == $ws)
    | .floating_nodes[]?
    | .rect as $r
    | (.nodes[0]? // .) | select(.window != null)
    | select($type == "" or window_type == $type)
    | {win: .window, x: $r.x, y: $r.y, marks: (.marks // [])} ]')

# Toggle: minimize the visible ones, or restore when there's none. --minimize: never restore
if [ "$(echo "$visible" | jq 'length')" -gt 0 ]; then
  # Minimize them all at once: remember positions, mark, send to the scratchpad
  jq -L "$HOME/.config/i3" --argjson list "$visible" --arg ws "$ws" 'include "minimize";
    reduce ($list | to_save($ws))[] as $w (.; .[$w.win | tostring] = {x: $w.x, y: $w.y})' \
    "$positions_file" > "$positions_file.tmp" && mv "$positions_file.tmp" "$positions_file"
  cmd=$(echo "$visible" | jq -r -L "$HOME/.config/i3" --arg ws "$ws" 'include "minimize"; minimize_cmd($ws)')
  i3-msg "$cmd" >/dev/null
elif [ "$mode" = toggle ]; then
  restore || true
fi
