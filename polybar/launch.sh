#!/usr/bin/env bash
# Starts the polybar "main" bar on every screen (i3 exec_always).

# One launcher at a time (i3 restarts in a row); the bars must not inherit the lock (9>&-)
exec 9>"${XDG_RUNTIME_DIR:-/tmp}/launch_polybar.lock"
flock 9

# Wired interface for the network module: first non-loopback, non-wifi interface with a carrier
# (VM names vary: ens18, enp0s3, eth0...)
ETH_IFACE=$(
  for dev in /sys/class/net/*; do
    name=$(basename "$dev")
    [ "$name" = lo ] || [ -e "$dev/wireless" ] || [ "$(cat "$dev/type")" != 1 ] && continue
    case "$name" in docker*|br-*|veth*|virbr*|tun*|tap*) continue ;; esac
    echo "$([ "$(cat "$dev/carrier" 2>/dev/null)" = 1 ] && echo 0 || echo 1) $name"
  done | sort | head -1 | cut -d' ' -f2
)
export ETH_IFACE

killall -q polybar
for _ in $(seq 20); do pgrep -x polybar >/dev/null || break; sleep 0.1; done
killall -q -9 polybar
pkill -f '\.config/polybar/[a-z_-]+\.sh'

polybar --list-monitors | while IFS=': x' read -r monitor width _; do
  if   [ "$width" -ge 3840 ]; then height=36 dpi=120
  elif [ "$width" -ge 2560 ]; then height=30 dpi=102
  else                             height=28 dpi=96
  fi
  MONITOR=$monitor BAR_HEIGHT=$height BAR_DPI=$dpi polybar -r main 9>&- &
done
