#!/usr/bin/env bash
# Left click on the polybar scratchpad module: list the popups minimized from this screen's
# workspace (rofi, at the mouse). Picking one brings back just that window, at its old position.
# Same marks / positions file as ~/.config/i3/popup-scratchpad-toggle.sh.

positions_file="${XDG_RUNTIME_DIR:-/tmp}/i3-scratchpad/positions.json"
tree=$(i3-msg -t get_tree)

# Visible workspace of this bar's screen ($MONITOR, set by launch_polybar.sh), else the focused one
ws=$(echo "$tree" | jq -r --arg out "${MONITOR:-}" '
  ( first(.nodes[] | select(.name == $out)
    | .nodes[] | select(.name == "content")
    | (.focus[0]) as $f | .nodes[] | select(.id == $f) | .name) )
  // first(.. | objects | select(.type? == "workspace")
       | select([.. | objects | select(.focused? == true)] | length > 0) | .name)
  // ""')
[ -n "$ws" ] || exit 0

# One line per minimized popup: "<xid>\t<mark>\t<label>"
# Label: readable kind (from the class / instance set by popup-open.sh & co) + window title.
# VLC's title already ends with " - VLC media player": trimmed.
mapfile -t entries < <(echo "$tree" | jq -r --arg ws "$ws" '
  def kind:
    (.window_properties.class // "") as $c | (.window_properties.instance // "") as $i
    | if   $c == "EogPopup" or $c == "Eog"    then "󰋩  Image"
      elif $c == "EvincePopup"                then "  PDF"
      elif $i == "VlcPopup" or $c == "vlc"    then "󰕧  Vidéo"
      elif $i == "NsxivPopup"                 then "󰋩  Vignettes"
      elif $i == "MpvPopup"                   then "󰄀  Capture"
      elif $i == "AudioPopup"                 then "󰎆  Audio"
      elif $c == "AlacrittyPopup" or $c == "Alacritty" then "  Terminal"
      elif ($c | test("chrome"; "i"))         then "  Chrome"
      elif $c == "" then "?"
      else "  \($c)" end;
  .. | objects | select(.name? == "__i3_scratch") | .floating_nodes[]?
  | (.nodes[0]? // .)
  | ((.marks // []) | map(select(startswith("_ws_\($ws)_"))) | first) as $m
  | select($m != null)
  | [.window, $m, "\(kind)  —  \((.name // "") | sub(" - VLC media player$"; ""))"] | @tsv')
[ ${#entries[@]} -gt 0 ] || exit 0

labels=() 
for e in "${entries[@]}"; do
  label=${e#*$'\t'*$'\t'}
  [ ${#label} -gt 70 ] && label="${label:0:69}…"
  labels+=("  $label")
done

choice=$(printf '%s\n' "${labels[@]}" | rofi -dmenu -i -p Popups -format i -no-custom -monitor -3 \
  -theme ~/.config/polybar/menu.rasi -theme-str "listview { lines: ${#labels[@]}; }")
[ -n "$choice" ] || exit 0

IFS=$'\t' read -r win mark _ <<< "${entries[$choice]}"
pos=""
if [ -s "$positions_file" ]; then
  pos=$(jq -r --arg k "$win" 'if .[$k] then ", move position \(.[$k].x) px \(.[$k].y) px" else "" end' "$positions_file")
  jq --arg k "$win" 'del(.[$k])' "$positions_file" > "$positions_file.tmp" && mv "$positions_file.tmp" "$positions_file"
fi
i3-msg "[id=$win] scratchpad show, unmark $mark$pos" >/dev/null
