# phone-fallback: when Wi-Fi has no internet, borrow the Pixel's over
# Bluetooth tethering (slow, a few Mbps, but cheap on both batteries), and
# hand back as soon as a real network has internet again. The phone's
# full-speed Wi-Fi hotspot stays a manual switch on the phone; it outranks
# every local Wi-Fi (priority 50, see ops/wifi-priority.sh), so turning it
# on upgrades without touching the laptop.
#
# Added 2026-11-11 after a guest Wi-Fi with no internet outranked the
# hotspot and left the laptop stranded: NetworkManager had no connectivity
# check, so it called that Wi-Fi "full" and never looked elsewhere.
#
# The NM profile "Pixel-BT" is made once by hand after pairing (see
# ops/phone-fallback-setup.sh); until it exists this does nothing.
# Pause it:  systemctl stop phone-fallback.timer   (comes back at boot)
{ pkgs, ... }:

let
  fallback = pkgs.writeShellApplication {
    name = "phone-fallback";
    runtimeInputs = [ pkgs.networkmanager pkgs.coreutils pkgs.gnugrep ];
    text = ''
      bt=Pixel-BT
      fail=/run/phone-fallback/last-fail
      backoff=300   # seconds to leave the phone alone after a failed connect

      nmcli -t -f NAME con show | grep -qxF "$bt" || exit 0

      # Does any non-Bluetooth device reach the internet by itself?
      others_full() {
        local dev type st
        while IFS=: read -r dev type st; do
          case "$type" in bt|loopback) continue ;; esac
          [[ $st == connected ]] || continue
          nmcli -g GENERAL.IP4-CONNECTIVITY dev show "$dev" | grep -q full && return 0
        done < <(nmcli -t -f DEVICE,TYPE,STATE dev)
        return 1
      }

      if [[ -n $(nmcli -g GENERAL.STATE con show "$bt" 2>/dev/null) ]]; then
        if others_full; then
          echo "a network has internet again: dropping $bt"
          nmcli con down "$bt" || true
        fi
        exit 0
      fi

      # Fall back only on none/limited. A captive portal (cafe login page)
      # is left alone, or its login page would go out over the phone.
      case "$(nmcli networking connectivity)" in none|limited) ;; *) exit 0 ;; esac
      [[ $(nmcli radio wifi) == enabled ]] || exit 0   # Wi-Fi off on purpose
      if [[ -f $fail ]] && (( $(date +%s) - $(stat -c %Y "$fail") < backoff )); then
        exit 0
      fi

      echo "no internet: bringing up $bt"
      if ! nmcli -w 30 con up "$bt"; then
        echo "$bt failed (phone away, or Bluetooth tethering off); retry in ''${backoff}s"
        touch "$fail"
      fi
    '';
  };
in
{
  # Without a check NM calls any Wi-Fi with a default route "full".
  # Re-checked every 60 s while full, and sooner while not.
  networking.networkmanager.settings.connectivity = {
    uri = "http://nmcheck.gnome.org/check_network_status.txt";
    response = "NetworkManager is online";
    interval = 60;
  };

  systemd.services.phone-fallback = {
    description = "Fall back to Pixel Bluetooth tethering when Wi-Fi has no internet";
    after = [ "NetworkManager.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${fallback}/bin/phone-fallback";
      RuntimeDirectory = "phone-fallback";
      RuntimeDirectoryPreserve = true;   # keep the backoff stamp between runs
    };
  };

  # Upgrades (dropping the phone) are noticed by this poll; falling back is
  # also triggered at once by the dispatcher hook below.
  systemd.timers.phone-fallback = {
    wantedBy = [ "timers.target" ];
    timerConfig = { OnBootSec = "1min"; OnUnitActiveSec = "30s"; };
  };

  networking.networkmanager.dispatcherScripts = [{
    type = "basic";
    source = pkgs.writeShellScript "phone-fallback-hook" ''
      [ "$2" = connectivity-change ] || exit 0
      exec ${pkgs.systemd}/bin/systemctl start --no-block phone-fallback.service
    '';
  }];
}
