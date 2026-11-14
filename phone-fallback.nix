# phone-fallback: keep the laptop online when the Wi-Fi it is on has no
# internet. Each run (every 30 s, and at once when NM's internet check
# changes), in order:
#
#  1. Upgrade: Wi-Fi joined but dead (none/limited) and a saved Wi-Fi with a
#     higher autoconnect priority is in range (the phone hotspot at 50) ->
#     switch to it. NetworkManager never leaves a joined network for a
#     better one by itself; this is the step that lets "turn the hotspot on"
#     rescue the laptop. 5 min backoff per attempt.
#  2. Hand back: on the phone's Bluetooth tether and any other device has
#     full internet -> drop the tether.
#  3. Fall back: no internet (none/limited) -> bring up the tether (slow, a
#     few Mbps, cheap on both batteries). 5 min backoff if the phone is away.
#
# Never acts on a captive portal (the cafe login page must go out over that
# Wi-Fi) or with the Wi-Fi radio switched off. States, diagram and the
# escape ladder: docs/uplinks.md; the manual levers: `uplink` (dotfiles).
#
# Added 2026-11-11 after a guest Wi-Fi with no internet outranked the
# hotspot and left the laptop stranded: NetworkManager had no connectivity
# check, so it called that Wi-Fi "full" and never looked elsewhere.
#
# The NM profile "Pixel-BT" is made once by hand after pairing (see
# ops/phone-fallback-setup.sh); until it exists step 3 does nothing.
# Pause it:  systemctl stop phone-fallback.timer   (comes back at boot)
{ pkgs, ... }:

let
  fallback = pkgs.writeShellApplication {
    name = "phone-fallback";
    runtimeInputs = [ pkgs.networkmanager pkgs.coreutils pkgs.gnugrep pkgs.gawk ];
    text = ''
      bt=Pixel-BT
      run=/run/phone-fallback
      backoff=300   # seconds between attempts at the same fix

      recent() { [[ -f $run/$1 ]] && (( $(date +%s) - $(stat -c %Y "$run/$1") < backoff )); }
      conn_of() { nmcli -g GENERAL.IP4-CONNECTIVITY dev show "$1" 2>/dev/null; }

      wifi=$(nmcli -t -f DEVICE,TYPE dev | awk -F: '$2=="wifi"{print $1; exit}')

      # 1. Upgrade off a dead Wi-Fi to a better saved one in range.
      if [[ -n $wifi && $(nmcli radio wifi) == enabled ]] && ! recent last-upgrade; then
        here=$(nmcli -g GENERAL.CONNECTION dev show "$wifi")
        case "$(conn_of "$wifi")" in *"(none)"*|*"(limited)"*) dead=1 ;; *) dead=0 ;; esac
        if [[ -n $here && $dead == 1 ]]; then
          herep=$(nmcli -g connection.autoconnect-priority con show "$here")
          seen=$(nmcli -g SSID dev wifi list --rescan no | sed 's/\\:/:/g')
          best="" bestp=$herep
          while IFS= read -r line; do
            [[ ''${line##*:} == 802-11-wireless ]] || continue
            name=''${line%:*}; name=''${name//\\:/:}
            [[ $name == "$here" ]] && continue
            mapfile -t f < <(nmcli -g connection.autoconnect,connection.autoconnect-priority,802-11-wireless.ssid con show "$name")
            [[ ''${f[0]} == yes ]] || continue
            grep -qxF -- "''${f[2]}" <<<"$seen" || continue
            if (( f[1] > bestp )); then best=$name bestp=''${f[1]}; fi
          done < <(nmcli -t -f NAME,TYPE con show)
          if [[ -n $best ]]; then
            echo "'$here' has no internet; '$best' (priority $bestp) is in range: switching"
            touch "$run/last-upgrade"
            nmcli -w 30 con up "$best" || echo "'$best' failed; staying put for ''${backoff}s"
            exit 0
          fi
        fi
      fi

      nmcli -t -f NAME con show | grep -qxF "$bt" || exit 0

      # Does any non-Bluetooth device reach the internet by itself?
      others_full() {
        local dev type st
        while IFS=: read -r dev type st; do
          case "$type" in bt|loopback) continue ;; esac
          [[ $st == connected ]] || continue
          conn_of "$dev" | grep -q full && return 0
        done < <(nmcli -t -f DEVICE,TYPE,STATE dev)
        return 1
      }

      # 2. Hand back.
      if [[ -n $(nmcli -g GENERAL.STATE con show "$bt" 2>/dev/null) ]]; then
        if others_full; then
          echo "a network has internet again: dropping $bt"
          nmcli con down "$bt" || true
        fi
        exit 0
      fi

      # 3. Fall back, only on none/limited.
      case "$(nmcli networking connectivity)" in none|limited) ;; *) exit 0 ;; esac
      [[ $(nmcli radio wifi) == enabled ]] || exit 0   # Wi-Fi off on purpose
      recent last-fail && exit 0

      echo "no internet: bringing up $bt"
      if ! nmcli -w 30 con up "$bt"; then
        echo "$bt failed (phone away, or Bluetooth tethering off); retry in ''${backoff}s"
        touch "$run/last-fail"
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
