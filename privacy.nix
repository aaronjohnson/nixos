# Mic and camera privacy switches, for the quickshell bar.
#
# The switches cut the devices in hardware and only the EC knows their
# position (the webcam stays on USB with its switch off), so nothing emits
# an event. A root service asks the EC every few seconds and rewrites
# /run/privacy-switches/state only when a switch moves; the bar watches that
# file, so it wakes only on a change. Reading the EC needs root, hence the
# service rather than the bar running framework_tool itself.
{ pkgs, ... }:

{
  systemd.services.privacy-switches = {
    description = "Track the mic/camera privacy switch positions";
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.framework-tool pkgs.gawk ];
    serviceConfig = {
      RuntimeDirectory = "privacy-switches";
      RuntimeDirectoryMode = "0755";
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
          echo "$now" > /run/privacy-switches/state.new
          mv /run/privacy-switches/state.new /run/privacy-switches/state
          prev=$now
        fi
        sleep 3
      done
    '';
  };
}
