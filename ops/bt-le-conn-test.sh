#!/usr/bin/env bash
# bt-le-conn-test.sh — try faster Bluetooth LE connection settings on hci0, for
# devices that drop the link before pairing starts. The Keychron Nape Pro did:
# btmon showed "Connection Failed to be Established (0x3e)" about 250 ms in, with
# the kernel defaults of a 45 ms interval and a 420 ms supervision timeout. The
# Pixel paired it fine; Android uses 7.5-15 ms intervals.
#
# Usage:  sudo ops/bt-le-conn-test.sh          # 7.5-15 ms interval, 5 s timeout
#         sudo ops/bt-le-conn-test.sh reset    # back to the kernel defaults
# Runtime only (debugfs): a reboot or Bluetooth restart undoes it. If it helps,
# the lasting fix is BlueZ's [LE] settings in hardware.bluetooth.settings.
# Idempotent: it writes the same values each run.
#
# 2026-11-14: not made permanent, and it was never confirmed to fix the Nape. The
# Nape advertises only briefly, so a pairing attempt with these settings never
# caught it. It runs on its Keychron Link-KM dongle (3434:d026, switch on "G") instead.
set -euo pipefail

log="$(dirname "$(readlink -f "$0")")/log/bt-le-conn-test.log"
mkdir -p "$(dirname "$log")"
exec > >(tee -a "$log") 2>&1
echo "== $(date -Is) ${*:-test}"
[[ -n ${SUDO_USER:-} ]] && chown "$SUDO_USER": "$log"

[[ $EUID -eq 0 ]] || { echo "needs root: sudo $0 $*"; exit 1; }
d=/sys/kernel/debug/bluetooth/hci0
[[ -d $d ]] || { echo "no $d (debugfs not mounted, or no hci0)"; exit 1; }
cd "$d"

show() { echo "$1:"; grep . conn_min_interval conn_max_interval supervision_timeout | sed 's/^/  /'; }
show before

# Units: intervals in 1.25 ms, timeout in 10 ms. Min must stay <= max, so the
# order of writes matters when moving between ranges.
if [[ ${1:-} == reset ]]; then
    echo 40 > conn_max_interval; echo 24 > conn_min_interval; echo 42 > supervision_timeout
else
    echo 6 > conn_min_interval; echo 12 > conn_max_interval; echo 500 > supervision_timeout
fi

show after
