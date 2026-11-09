# Helpers for the rofi menus written as a rofi script mode (window-actions-menu.sh,
# minimize-menu.sh): rofi calls the script again with the picked entry (ROFI_RETV, ROFI_INFO),
# the script answers with the next level, or runs the action and prints nothing (rofi closes).
# Sourced, not run.

# rofi_menu_open TITLE [MONITOR PLACEMENT]: when started by i3 (not by rofi), open rofi on the
# calling script, centered on the focused screen, with a search bar. MONITOR (rofi -monitor) and
# PLACEMENT (extra rasi, e.g. a window location) override that, e.g. for a menu from polybar
rofi_menu_open() {
  [ -z "${ROFI_RETV:-}" ] || return 0
  exec rofi -show "$1" -modi "$1:$0" \
    -monitor "${2:--1}" -theme ~/.config/polybar/menu.rasi -theme-str '
      window    { location: center; anchor: center; x-offset: 0; y-offset: 0; width: 460px; }
      mainbox   { children: [ inputbar, listview ]; spacing: 8px; }
      inputbar  { children: [ prompt, entry ]; padding: 8px 12px; spacing: 10px;
                  border-radius: 10px; background-color: @surface; }
      prompt    { text-color: @accent; }
      entry     { placeholder: "Search…"; placeholder-color: #6c7086; }
      listview  { lines: 10; fixed-height: false; }' -theme-str "${3:-}"
}

# menu_header PROMPT: first lines of every level (pango labels, no free text, prompt)
menu_header() { printf '\0markup-rows\x1ftrue\n\0no-custom\x1ftrue\n\0prompt\x1f%s\n' "$1"; }

# item ID LABEL [ENABLED]: one row; ENABLED empty = greyed out and not selectable.
# Rows are printed by flush_items, greyed ones last: rofi highlights the first row, even a
# greyed one. (Kept in arrays: a bash string can't hold the NUL bytes of the row options.)
ids=() labels=() enabled=()
item() { ids+=("$1"); labels+=("$2"); enabled+=("${3-1}"); }
flush_items() {
  local i
  for i in "${!ids[@]}"; do
    [ "${enabled[$i]}" ] && printf '%s\0info\x1f%s\n' "${labels[$i]}" "${ids[$i]}"
  done
  for i in "${!ids[@]}"; do
    [ "${enabled[$i]}" ] || printf '<span alpha="40%%">%s</span>\0info\x1f%s\x1fnonselectable\x1ftrue\n' \
      "${labels[$i]}" "${ids[$i]}"
  done
}

# yes_if N: "1" (enabled) when N > 0
yes_if() { [ "$1" -gt 0 ] && echo 1; }

# Window types (window-type.jq), in menu order, with their icon and label
window_types=(image pdf video audio terminal browser other)
declare -A type_icon=([image]=󰋩 [pdf]=󰈦 [video]=󰕧 [audio]=󰎆 [terminal]=󰆍 [browser]=󰖟 [other]=󰘔)
declare -A type_label=([image]=Image [pdf]=PDF [video]=Video [audio]=Audio [terminal]=Terminal [browser]=Browser [other]=Other)

# Actions run detached: rofi closes as soon as the script prints nothing
detach() { setsid -f "$@" >/dev/null 2>&1; }
