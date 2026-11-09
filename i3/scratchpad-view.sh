#!/usr/bin/env bash
# "Show scratchpad" action: every minimized popup, whatever its workspace, shown on the
# "scratchpad" workspace (arranged without overlap). Leaving that workspace (any way: this
# action again, $mod+<n>, a click on another workspace or screen) sends them back to the
# scratchpad, still listed under their own workspace.
# The windows keep their _ws_<workspace>_<xid> mark and saved position: minimized from the
# scratchpad workspace ($mod+-, $mod+Shift+-...) they also go back under their own workspace
# (minimize.jq). Restoring one from there (polybar module) works as usual.
#   scratchpad-view.sh           show / hide
#   scratchpad-view.sh --watch   (started by show) hide as soon as the view loses the focus

view=scratchpad

# Marked windows of the view back to the scratchpad
hide() {
  local cmd
  cmd=$(i3-msg -t get_tree | jq -r --arg ws "$view" '
    [.. | objects | select(.type? == "workspace" and .name == $ws)] | first | .floating_nodes[]?
    | (.nodes[0]? // .) | select((.marks // []) | any(startswith("_ws_")))
    | "[id=\(.window)] move scratchpad"' | paste -sd ';')
  [ -z "$cmd" ] || i3-msg -q "$cmd"
}

if [ "${1:-}" = --watch ]; then
  i3-msg -t subscribe -m '["workspace"]' | while read -r event; do
    [ "$(jq -r 'select(.change == "focus") | .current.name' <<<"$event")" ] || continue
    [ "$(jq -r '.current.name' <<<"$event")" = "$view" ] && continue
    hide
    exit 0
  done
  exit 0
fi

if [ "$(i3-msg -t get_workspaces | jq -r '.[] | select(.focused) | .name')" = "$view" ]; then
  i3-msg -q "workspace back_and_forth"  # the watcher sends them back
  exit 0
fi

cmd=$(i3-msg -t get_tree | jq -r --arg ws "$view" '
  .. | objects | select(.name? == "__i3_scratch") | .floating_nodes[]?
  | (.nodes[0]? // .) | select((.marks // []) | any(startswith("_ws_")))
  | "[id=\(.window)] scratchpad show, move container to workspace \($ws)"' | paste -sd ';')
if [ -z "$cmd" ]; then
  notify-send -t 2000 "Scratchpad" "No minimized window" 2>/dev/null
  exit 0
fi
pkill -f "scratchpad-view.sh --watch"  # a watcher left by a previous show
i3-msg -q "$cmd; workspace $view"
"$HOME/.config/i3/popup-arrange.sh" "$view"
setsid -f "$0" --watch >/dev/null 2>&1
