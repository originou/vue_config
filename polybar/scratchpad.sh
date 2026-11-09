#!/usr/bin/env bash
# Polybar module: displays the number of popups in i3 scratchpad
# marked for THIS monitor's visible workspace (strict per-workspace isolation).
# Uses native i3 window marks (_ws_<num>_<xid>) which survive i3 reloads and restarts.
# Hidden (empty line) when this workspace has no minimized popups.

output=${MONITOR:?MONITOR is set by launch_polybar.sh}

get_current_workspace() {
  local tree=$1
  echo "$tree" | jq -r --arg out "$output" '
    .nodes[] | select(.name == $out)
    | .nodes[] | select(.name == "content")
    | (.focus[0]) as $ws | .nodes[] | select(.id == $ws)
    | .name // ""
  '
}

count_workspace_scratchpad() {
  local tree=$1 ws=$2
  [ -n "$ws" ] || { echo 0; return; }

  echo "$tree" | jq -r --arg ws "$ws" '
    [
      .. | objects
      | select(.name? == "__i3_scratch")
      | .floating_nodes[]?
      | select((.nodes[0]?.marks? // .marks? // []) | any(test("^_ws_\($ws)_")))
    ] | length
  ' 2>/dev/null || echo 0
}

render() {
  local tree ws count
  tree=$(i3-msg -t get_tree 2>/dev/null) || return
  ws=$(get_current_workspace "$tree")
  count=$(count_workspace_scratchpad "$tree" "$ws")
  if [ -n "$count" ] && [ "$count" -gt 0 ]; then
    printf '%%{T6}%%{T-} %s\n' "$count"
  else
    printf '\n'
  fi
}

render
i3-msg -t subscribe -m '["window", "workspace"]' 2>/dev/null | while read -r _; do
  render
done
