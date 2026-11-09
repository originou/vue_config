# Minimizing popups to the scratchpad: mark _ws_<workspace>_<xid> (read by the polybar
# scratchpad module and the restore scripts) and saved position. Input: [{win, x, y, marks}]
# On the "scratchpad" workspace (scratchpad-view.sh) a window that already has its mark goes back
# as is: still listed under its own workspace, its saved position kept.
def keeps_mark($ws): $ws == "scratchpad" and ((.marks // []) | any(startswith("_ws_")));

# i3 command minimizing the windows; a stale mark (window moved out of the scratchpad
# workspace by hand) is replaced by the one of $ws
def minimize_cmd($ws):
  map("[id=\(.win)] "
      + (if keeps_mark($ws) then "move scratchpad"
         else [ ((.marks // [])[] | select(startswith("_ws_")) | "unmark \(.)"),
                "mark --add _ws_\($ws)_\(.win)", "move scratchpad" ] | join(", ") end))
  | join("; ");

# Windows whose position must be saved
def to_save($ws): map(select(keeps_mark($ws) | not));
