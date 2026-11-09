#!/usr/bin/env bash
# move-dir.sh left|right|up|down: $mod+Shift+arrow. Tiled window: i3's move (at the screen edge it
# goes to the next screen's workspace). Floating window: straight to the workspace of the next
# screen in that direction, keeping the focus (i3's move would only nudge it by 10 px; nudging
# is in the resize mode, arrows / Shift+arrows)
dir=$1
id=$(i3-msg -t get_tree | jq -r 'first(.. | objects | select(.type? == "floating_con")
  | select([.nodes[]? | select(.focused)] | length > 0) | .nodes[0].id) // empty')
if [ -n "$id" ]; then
  i3-msg -q "move container to output $dir" && i3-msg -q "[con_id=$id] focus"
else
  i3-msg -q "move $dir"
fi
