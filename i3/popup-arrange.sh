#!/usr/bin/env bash
# Rearranges the floating windows of a workspace so they don't overlap: rows filled left to
# right (tallest first), each row centered, the whole block centered. When they don't fit at
# their current size, all of them are shrunk by the same factor (aspect ratio kept, never enlarged).
#   popup-arrange.sh [--by-type] [WORKSPACE]   default: the focused workspace (DRY_RUN=1: print the i3 commands)
# --by-type: grouped by window type (images, then PDFs, videos... window-type.jq), each type
# starting a new row.
# Started from the polybar actions menu.

gap=8         # space between windows and around the block
min_scale=0.3 # below that, windows would be unreadable: overlap instead

by_type=false
[ "${1:-}" = --by-type ] && by_type=true && shift
ws=${1:-$(i3-msg -t get_workspaces | jq -r '.[] | select(.focused) | .name')}

arrange() {
i3-msg -t get_tree | jq -r -L "$HOME/.config/i3" --argjson by_type "$by_type" --arg ws "$ws" --argjson gap "$gap" --argjson min "$min_scale" '
  include "window-type";
  [.. | objects | select(.type? == "workspace" and .name == $ws)] | first
  | .rect as $area
  | [.floating_nodes[] | {id: .nodes[0].id, w: .rect.width, h: .rect.height,
                          group: (if $by_type then (.nodes[0] | window_type_rank) else 0 end)}]
  | sort_by(.group, -.h) as $wins
  | if ($wins | length) == 0 then empty else

    # Rows for scale $s: [[{id, w, h, group}...]...]. A new row when the current one is full,
    # or when the group (window type, --by-type) changes
    def rows($s):
      reduce ($wins[] | .w = (.w * $s | floor) | .h = (.h * $s | floor)) as $win
        ({rows: [], x: 0};
         if (.rows | length) > 0
            and (.x + $win.w + $gap > $area.width - $gap or .rows[-1][-1].group != $win.group)
         then .rows += [[$win]] | .x = $gap + $win.w + $gap
         else (if (.rows | length) == 0 then .rows = [[]] | .x = $gap else . end)
              | .rows[-1] += [$win] | .x += $win.w + $gap
         end)
      | .rows;
    def height($rows): ([$rows[] | map(.h) | max] | add) + $gap * (($rows | length) + 1);
    def width($row): ($row | map(.w) | add) + $gap * (($row | length) - 1);
    def fits($rows): height($rows) <= $area.height and all($rows[]; width(.) <= $area.width - 2 * $gap);

    # Largest scale (1, 0.95, 0.9...) where everything fits
    ([range(100; ($min * 100) - 1; -5) | . / 100 | select(fits(rows(.)))] | first // $min) as $s
    | rows($s) as $rows
    | ($area.y + ((($area.height - height($rows)) / 2 | floor) | if . < 0 then 0 else . end) + $gap) as $top
    | foreach range(0; $rows | length) as $i ({y: $top};
        .row = $rows[$i]
        | .y as $y
        | ($area.x + (($area.width - width(.row)) / 2 | floor)) as $x0
        | .out = [ foreach .row[] as $win ({x: $x0}; .cur = .x | .x += $win.w + $gap;
                     "[con_id=\($win.id)] resize set \($win.w) px \($win.h) px, move position \(.cur) px \($y) px") ]
        | .y += (.row | map(.h) | max) + $gap;
        .out[])
  end' |
while read -r cmd; do
  if [ -n "${DRY_RUN:-}" ]; then echo "$cmd"; else i3-msg "$cmd" >/dev/null; fi
done
}

arrange
# Some apps refuse a size below their minimum (eog: ~470 px wide): second pass with the sizes
# they actually took (usually just moves them)
[ -n "${DRY_RUN:-}" ] || { sleep 0.3; arrange; }
