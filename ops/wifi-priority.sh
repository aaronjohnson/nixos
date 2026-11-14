#!/usr/bin/env bash
# wifi-priority.sh — put parked .nmconnection files back into NetworkManager
# with a priority BELOW the phone hotspot, so a local wifi that has no
# internet can never lock the laptop out of the hotspot.
#
# Ladder (higher wins when several are in range):
#   100  Starlink (future)
#    50  the phone hotspot — only exists when the hotspot is on
#    20  local wifis we've been given (guest networks, friends' homes)
#     0  cafes and everything else
#
# Usage:  sudo ops/wifi-priority.sh ~/Some.nmconnection [...]
# The hotspot's profile name comes from ~/.config/uplinks.env (HOTSPOT=...),
# kept out of this repo because it is public.
# Idempotent: re-running re-installs the same files and re-asserts priorities.
# Undo one:  sudo rm /etc/NetworkManager/system-connections/<file> && sudo nmcli con reload
set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "run with sudo" >&2; exit 1; }
# shellcheck source=/dev/null
source "$(getent passwd "${SUDO_USER:-root}" | cut -d: -f6)/.config/uplinks.env"
: "${HOTSPOT:?set HOTSPOT in ~/.config/uplinks.env}"

dir=/etc/NetworkManager/system-connections
log="$(dirname "$0")/log/wifi-priority.log"
mkdir -p "$(dirname "$log")"
touch "$log"
chown -R "${SUDO_USER:-root}": "$(dirname "$log")"   # other ops scripts log here as amj
exec > >(tee -a "$log") 2>&1
echo "== $(date -Is) $*"

for f in "$@"; do
  id=$(sed -n 's/^id=//p' "$f" | head -1)
  [[ -n $id ]] || { echo "no id= in $f, skipping"; continue; }
  install -m600 -o root -g root "$f" "$dir/$(basename "$f")"
  nmcli con load "$dir/$(basename "$f")"
  nmcli con modify "$id" connection.autoconnect-priority 20
  echo "installed '$id' at priority 20"
done

nmcli con modify "$HOTSPOT" connection.autoconnect-priority 50
nmcli -f NAME,AUTOCONNECT,AUTOCONNECT-PRIORITY con show
