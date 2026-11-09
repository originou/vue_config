#!/usr/bin/env bash
# $mod+Shift+-: rofi menu to minimize the floating windows of the focused workspace to the
# scratchpad or bring them back (all, or by type). Same marks / saved positions as
# popup-scratchpad-toggle.sh (and the polybar scratchpad module). Rofi script mode: rofi-menu-lib.sh.

. "$HOME/.config/i3/rofi-menu-lib.sh"
rofi_menu_open minimize

toggle="$HOME/.config/i3/popup-scratchpad-toggle.sh"
ws=$(i3-msg -t get_workspaces | jq -r '.[] | select(.focused) | .name')
tree=$(i3-msg -t get_tree)

# Visible floating windows of the workspace, one type per line (window-type.jq)
visible_types=$(jq -r -L "$HOME/.config/i3" --arg ws "$ws" 'include "window-type";
  [.. | objects | select(.type? == "workspace" and .name == $ws)] | first
  | .floating_nodes[] | (.nodes[0]? // .) | select(.window != null) | window_type' <<<"$tree")
visible=$(grep -c . <<<"$visible_types")
count_type() { grep -cx "$1" <<<"$visible_types"; }
count_minimized_type() { grep -cx "$1" <<<"$minimized_types"; }
# Windows minimized from this workspace (mark _ws_<workspace>_<xid>), one type per line
minimized_types=$(jq -r -L "$HOME/.config/i3" --arg ws "$ws" 'include "window-type";
  .. | objects | select(.name? == "__i3_scratch") | .floating_nodes[]?
  | (.nodes[0]? // .) | select((.marks // []) | any(startswith("_ws_\($ws)_"))) | window_type' <<<"$tree")
minimized=$(grep -c . <<<"$minimized_types")

menu() {
  case "$1" in
    root)
      menu_header Minimize
      item all     "󰖰  Minimize all ($visible)" "$(yes_if "$visible")"
      item by-type "󰖰  Minimize by type ›" "$(yes_if "$visible")"
      item restore "󰖯  Restore all ($minimized)" "$(yes_if "$minimized")"
      item restore-by-type "󰖯  Restore by type ›" "$(yes_if "$minimized")"
      ;;
    restore-by-type)
      menu_header "Restore by type"
      item back "󰁍  Back"
      local type n
      for type in "${window_types[@]}"; do
        n=$(count_minimized_type "$type")
        item "restore-type:$type" "${type_icon[$type]}  ${type_label[$type]} ($n)" "$(yes_if "$n")"
      done
      ;;
    by-type)
      menu_header "Minimize by type"
      item back "󰁍  Back"
      local type n
      for type in "${window_types[@]}"; do
        n=$(count_type "$type")
        item "type:$type" "${type_icon[$type]}  ${type_label[$type]} ($n)" "$(yes_if "$n")"
      done
      ;;
  esac
  flush_items
}

run() {
  case "$1" in
    all)     detach "$toggle" --minimize "$ws" ;;
    type:*)  detach "$toggle" --minimize --type "${1#type:}" "$ws" ;;
    restore) detach "$toggle" --restore "$ws" ;;
    restore-type:*) detach "$toggle" --restore --type "${1#restore-type:}" "$ws" ;;
  esac
}

case "${ROFI_RETV}:${ROFI_INFO:-}" in
  0:*)       menu root ;;
  1:back)    menu root ;;
  1:by-type) menu by-type ;;
  1:restore-by-type) menu restore-by-type ;;
  1:*)       run "$ROFI_INFO" ;;
esac
