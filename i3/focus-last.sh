#!/usr/bin/env bash
# Win+Tab: back to the previously focused window (any workspace or screen), i3 has no such command.
#   focus-last.sh           daemon (exec_always): records the focus history
#   focus-last.sh --switch  focuses the previous window still open
# Pressing it again goes back and forth between the last two windows.

history="${XDG_RUNTIME_DIR:-/tmp}/i3-focus-history"  # con ids, most recent first

if [ "${1:-}" = --switch ]; then
  [ -f "$history" ] || exit 0
  # Skip the current window; closed ones fail to match and are skipped too
  tail -n +2 "$history" | while read -r id; do
    i3-msg "[con_id=$id] focus" 2>/dev/null | grep -q '"success":true' && break
  done
  exit 0
fi

# Single instance: exec_always runs again on every i3 restart (same as popup-placer.sh)
pidfile="${XDG_RUNTIME_DIR:-/tmp}/focus-last.pid"
if [ -f "$pidfile" ]; then
  old_pgid=$(ps -o pgid= -p "$(cat "$pidfile")" 2>/dev/null | tr -d ' ')
  [ -n "$old_pgid" ] && [ "$old_pgid" != "$(ps -o pgid= -p $$ | tr -d ' ')" ] && kill -- "-$old_pgid" 2>/dev/null
fi
echo $$ > "$pidfile"

i3-msg -t subscribe -m '["window"]' | jq --unbuffered -r 'select(.change == "focus") | .container.id' |
while read -r id; do
  { echo "$id"; grep -vx "$id" "$history" 2>/dev/null | head -n 30; } > "$history.tmp"
  mv "$history.tmp" "$history"
done
