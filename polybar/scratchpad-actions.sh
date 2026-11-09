#!/usr/bin/env bash
# Right click on the polybar scratchpad module: action menu (rofi) for the popups
# minimized from this screen's workspace:
#   1. Restore all           -> bring them back to this workspace at saved positions
#   2. Move all to workspace -> pick an existing workspace to restore & place them on
#   3. Move all to new ws    -> find the first free workspace number on this monitor
#
# Popups are placed without overlap via popup-placer.sh --place.
# Focus switches to the target workspace so the user follows them.

set -euo pipefail

output=${MONITOR:-}
tree=$(i3-msg -t get_tree)

# Visible workspace of this bar's screen ($MONITOR), else the focused one
ws=$(echo "$tree" | jq -r --arg out "$output" '
  ( first(.nodes[] | select(.name == $out)
    | .nodes[] | select(.name == "content")
    | (.focus[0]) as $f | .nodes[] | select(.id == $f) | .name) )
  // first(.. | objects | select(.type? == "workspace")
       | select([.. | objects | select(.focused? == true)] | length > 0) | .name)
  // ""')
[ -n "$ws" ] || exit 0

# Popups minimized from this workspace: "<xid>\t<mark>\t<con_id>"
mapfile -t entries < <(echo "$tree" | jq -r --arg ws "$ws" '
  .. | objects | select(.name? == "__i3_scratch") | .floating_nodes[]?
  | (.nodes[0]? // .)
  | ((.marks // []) | map(select(startswith("_ws_\($ws)_"))) | first) as $m
  | select($m != null)
  | [.window, $m, .id] | @tsv')

[ ${#entries[@]} -gt 0 ] || exit 0

menu_theme=~/.config/polybar/menu.rasi

actions=(
  "  Restore all"
  "󰆍  Move all to workspace…"
  "󰐕  Move all to new workspace"
)

choice=$(printf '%s\n' "${actions[@]}" | rofi -dmenu -i -p "Popups ($ws)" -format i -no-custom -monitor -3 \
  -theme "$menu_theme" -theme-str "listview { lines: ${#actions[@]}; }")
[ -n "$choice" ] || exit 0

# ── 1. Restore all ────────────────────────────────────────────────────────────
if [ "$choice" -eq 0 ]; then
  ~/.config/i3/popup-scratchpad-toggle.sh --restore "$output" &
  exit 0
fi

# ── 2. Move to existing workspace or 3. New workspace ─────────────────────────
target_ws=""

if [ "$choice" -eq 1 ]; then
  # List existing workspaces except $ws
  workspaces_json=$(i3-msg -t get_workspaces)
  mapfile -t target_list < <(echo "$workspaces_json" | jq -r --arg current "$ws" '
    [ .[] | select(.name != $current) | .name ]
    | sort_by(tonumber? // 999)
    | .[]')

  if [ ${#target_list[@]} -eq 0 ]; then
    # No other workspace currently exists: fall through to new workspace
    choice=2
  else
    ws_labels=()
    for wname in "${target_list[@]}"; do
      if [[ "$wname" =~ ^[0-9]+$ ]]; then
        ws_labels+=("󰆍  Workspace $wname")
      else
        ws_labels+=("󰆍  $wname")
      fi
    done

    # Short delay so the mouse button release from the first menu doesn't dismiss the second
    sleep 0.2
    ws_choice=$(printf '%s\n' "${ws_labels[@]}" | rofi -dmenu -i -p "Target workspace" -format i -no-custom -monitor -3 \
      -theme "$menu_theme" -theme-str "listview { lines: ${#ws_labels[@]}; }")
    [ -n "$ws_choice" ] || exit 0

    target_ws="${target_list[$ws_choice]}"
  fi
fi

if [ "$choice" -eq 2 ]; then
  workspaces_json=$(i3-msg -t get_workspaces)
  existing_nums=$(echo "$workspaces_json" | jq -c '[.[].num | select(. > 0)]')

  range_start=1
  range_end=10

  mon_left=$(grep -s 'monitorLeft' ~/.cache/i3/monitors.conf | awk '{print $3}' || true)
  if [ -n "$mon_left" ] && [ "$output" = "$mon_left" ]; then
    range_start=11
    range_end=20
  fi

  for ((n=range_start; n<=range_end; n++)); do
    if ! echo "$existing_nums" | jq -e --argjson n "$n" 'index($n)' >/dev/null; then
      target_ws="$n"
      break
    fi
  done

  if [ -z "$target_ws" ]; then
    for ((n=1; n<=50; n++)); do
      if ! echo "$existing_nums" | jq -e --argjson n "$n" 'index($n)' >/dev/null; then
        target_ws="$n"
        break
      fi
    done
  fi
fi

[ -n "$target_ws" ] || exit 0

# ── Execute move to target_ws ────────────────────────────────────────────────
positions_file="${XDG_RUNTIME_DIR:-/tmp}/i3-scratchpad/positions.json"

cmds=()
win_keys=()
for entry in "${entries[@]}"; do
  IFS=$'\t' read -r win mark _ <<< "$entry"
  cmds+=("[id=$win] scratchpad show, move container to workspace $target_ws, unmark $mark")
  win_keys+=("$win")
done

full_cmd=$(IFS='; '; echo "${cmds[*]}")
i3-msg "$full_cmd; workspace $target_ws" >/dev/null

# Clean up saved positions since windows moved to a new screen/workspace
if [ -s "$positions_file" ]; then
  keys_json=$(printf '%s\n' "${win_keys[@]}" | jq -R . | jq -s .)
  jq --argjson list "$keys_json" '
    with_entries(select(.key as $k | $list | index($k) | not))
  ' "$positions_file" > "$positions_file.tmp" && mv "$positions_file.tmp" "$positions_file"
fi

# Arrange the popups on target_ws without overlap using popup-placer.sh
new_tree=$(i3-msg -t get_tree)
new_con_ids=()
for win in "${win_keys[@]}"; do
  nid=$(echo "$new_tree" | jq -r --argjson win "$win" '.. | objects | select(.window == $win) | .id // empty' | head -1)
  [ -n "$nid" ] && new_con_ids+=("$nid")
done

if [ ${#new_con_ids[@]} -gt 0 ]; then
  ~/.config/i3/popup-placer.sh --place "${new_con_ids[@]}" >/dev/null 2>&1 &
fi
