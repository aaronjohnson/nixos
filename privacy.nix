# Mic and camera privacy, for the quickshell bar.
#
# Hardware switches: they cut the devices in hardware and only the EC knows
# the mic switch's position, so nothing emits an event. A root service asks
# the EC every few seconds and rewrites /run/privacy-switches/state only when
# something moves; the bar watches that file, so it wakes only on a change.
# The EC's "camera" value means "streaming now", not the camera switch.
#
# Software kill (Super+F7, `privacy-toggle`): the webcam is de-authorized on
# USB, so it disappears from the system, and the sound card drops to an
# output-only profile with the capture switch off, so the mic has no source.
# Both stay off across reboots until toggled back.
{ pkgs, ... }:

let
  # Framework Laptop Webcam Module (2nd Gen).
  webcam = { vendor = "32ac"; product = "001c"; };
  flag = "/var/lib/camera-off/enabled";

  setWebcam = authorized: ''
    for d in /sys/bus/usb/devices/*; do
      if [ "$(cat "$d/idVendor" 2>/dev/null):$(cat "$d/idProduct" 2>/dev/null)" = "${webcam.vendor}:${webcam.product}" ]; then
        echo ${authorized} > "$d/authorized"
      fi
    done
  '';

  privacy-toggle = pkgs.writeShellApplication {
    name = "privacy-toggle";
    runtimeInputs = with pkgs; [ pipewire wireplumber alsa-utils jq libnotify systemd quickshell ];
    text = ''
      # One key for both: the camera flag decides which way we go.
      card=alsa_card.pci-0000_00_1f.3
      saved="''${XDG_STATE_HOME:-$HOME/.local/state}/privacy-toggle/audio-profile"
      mkdir -p "$(dirname "$saved")"

      dev=$(pw-dump | jq -r --arg c "$card" '.[] | select(.info.props["device.name"]? == $c) | .id')
      profiles() { pw-dump "$dev" | jq -r '.[0].info.params.EnumProfile[] | "\(.index) \(.name)"'; }
      active() { pw-dump "$dev" | jq -r '.[0].info.params.Profile[0] | "\(.index) \(.name)"'; }

      if [ -e ${flag} ]; then
        systemctl start camera-enable.service
        if [ -s "$saved" ]; then wpctl set-profile "$dev" "$(cat "$saved")"; fi
        amixer -q -c 0 sset Capture cap
        notify-send -a privacy -t 4000 "Mic and camera enabled" "Software privacy off"
      else
        read -r idx name < <(active)
        if [[ "$name" == *+input:* ]]; then
          echo "$idx" > "$saved"
          out=''${name%%+input:*}
          new=$(profiles | awk -v n="$out" '$2 == n { print $1 }')
          if [ -n "$new" ]; then wpctl set-profile "$dev" "$new"; fi
        fi
        amixer -q -c 0 sset Capture nocap
        systemctl start camera-disable.service
        notify-send -a privacy -t 4000 "Mic and camera disabled" "Software privacy on"
      fi
      qs ipc call privacy refresh >/dev/null 2>&1 || true
    '';
  };
in
{
  environment.systemPackages = [ privacy-toggle ];

  systemd.services.privacy-switches = {
    description = "Track the mic/camera privacy switch positions";
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.framework-tool pkgs.gawk ];
    serviceConfig = {
      RuntimeDirectory = "privacy-switches";
      RuntimeDirectoryMode = "0755";
      RuntimeDirectoryPreserve = "yes";  # keep the file across restarts
      Restart = "always";
      RestartSec = 10;
    };
    # state holds "<mic> <camera>", each "on" (device connected) or "off".
    script = ''
      prev=
      while :; do
        now=$(framework_tool --privacy 2>/dev/null | awk '
          /Microphone:/ { m = ($2 == "Connected") ? "on" : "off" }
          /Camera:/     { c = ($2 == "Connected") ? "on" : "off" }
          END           { if (m != "" && c != "") print m, c }')
        if [ -n "$now" ] && [ "$now" != "$prev" ]; then
          # In place, not write-and-rename: a rename drops the bar's file watch.
          echo "$now" > /run/privacy-switches/state
          prev=$now
        fi
        sleep 3
      done
    '';
  };

  # ---- Software camera kill ----
  # The flag file is the switch; the bar reads it too. The udev rule keeps
  # the webcam de-authorized at boot and whenever it re-enumerates.
  systemd.services.camera-disable = {
    description = "Software camera kill: de-authorize the webcam";
    serviceConfig = { Type = "oneshot"; StateDirectory = "camera-off"; StateDirectoryMode = "0755"; };
    script = "touch ${flag}\n" + setWebcam "0";
  };
  systemd.services.camera-enable = {
    description = "Software camera kill off: re-authorize the webcam";
    serviceConfig.Type = "oneshot";
    script = "rm -f ${flag}\n" + setWebcam "1";
  };
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="${webcam.vendor}", ATTR{idProduct}=="${webcam.product}", TEST=="${flag}", ATTR{authorized}="0"
  '';

  # Let the logged-in wheel user run just those two units without a password.
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      var unit = action.lookup("unit");
      if (action.id == "org.freedesktop.systemd1.manage-units" &&
          (unit == "camera-disable.service" || unit == "camera-enable.service") &&
          action.lookup("verb") == "start" &&
          subject.isInGroup("wheel") && subject.local && subject.active) {
        return polkit.Result.YES;
      }
    });
  '';
}
