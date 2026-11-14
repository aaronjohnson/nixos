#!/usr/bin/env bash
# phone-fallback-setup.sh — pair the Pixel over Bluetooth and make the
# NetworkManager profile "Pixel-BT" that phone-fallback.nix brings up when
# Wi-Fi has no internet. Run as amj (networkmanager group), not sudo.
#
# On the Pixel first:
#   Settings > Network & internet > Hotspot & tethering > Bluetooth tethering: ON
#   Settings > Connected devices > Pair new device   (keep that screen open)
# After pairing, on the phone's page for "hadron" (gear icon):
#   Internet sharing: ON. Without it the phone refuses the tether ("bnep:
#   connection setup TO" in the bluetooth log). It appeared there on
#   2026-11-13 once Bluetooth tethering was on. Turn off Phone calls, Media
#   audio and contacts, so the phone doesn't send its audio to the laptop.
#
# Usage:  ops/phone-fallback-setup.sh            # PHONE_BT from ~/.config/uplinks.env
#         ops/phone-fallback-setup.sh AA:BB:...  # another phone
# The address lives outside this repo because it is public.
# Idempotent: re-pairing a paired phone and re-making the profile are no-ops.
set -euo pipefail

log="$(dirname "$0")/log/phone-fallback-setup.log"
mkdir -p "$(dirname "$log")"
exec > >(tee -a "$log") 2>&1
echo "== $(date -Is) $*"

# shellcheck source=/dev/null
[[ -f ~/.config/uplinks.env ]] && source ~/.config/uplinks.env
mac=${1:-${PHONE_BT:?pass the phone Bluetooth address or set PHONE_BT in ~/.config/uplinks.env}}
mac=${mac^^}

# Scan and pair in ONE bluetoothctl session: a separate `scan on` forgets
# the phone when it exits, and `pair` then says "not available".
if ! bluetoothctl info "$mac" 2>/dev/null | grep -q 'Paired: yes'; then
  echo "scanning up to 30 s for $mac; keep the Pixel on 'Pair new device',"
  echo "then tap Pair on the phone when its code appears"
  {
    echo "agent KeyboardDisplay"; echo "default-agent"; echo "scan on"
    for _ in $(seq 30); do
      sleep 1
      bluetoothctl devices | grep -qi "$mac" && break
    done
    echo "pair $mac"; sleep 8
    echo "yes"; sleep 12          # answers "Confirm passkey (yes/no)"
    echo "scan off"; echo "quit"
  } | bluetoothctl | grep -iE "$mac|passkey|pair|fail|error" || true
fi
if ! bluetoothctl info "$mac" | grep -q 'Paired: yes'; then
  echo "not paired. Named devices seen:"
  bluetoothctl devices | grep -vE ' ([0-9A-F]{2}-){5}[0-9A-F]{2}$' || true
  echo "check Settings > About phone > Bluetooth address on the Pixel"
  exit 1
fi
bluetoothctl trust "$mac"

if ! nmcli -t -f NAME con show | grep -qxF Pixel-BT; then
  nmcli con add type bluetooth con-name Pixel-BT bluetooth.bdaddr "$mac" \
    bluetooth.type panu
fi
# Managed by phone-fallback, never on its own. While up it must win the
# default route even with a no-internet Wi-Fi still associated.
nmcli con modify Pixel-BT connection.autoconnect no connection.metered yes \
  ipv4.route-metric 50 ipv6.route-metric 50

echo "testing: up, then down"
nmcli -w 30 con up Pixel-BT && curl -s -m 10 -o /dev/null -w 'http %{http_code}\n' http://nmcheck.gnome.org/check_network_status.txt
nmcli con down Pixel-BT
echo "done"
