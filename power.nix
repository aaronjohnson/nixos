# Sleep, lock screen and hibernation for the Framework 13 Pro.
#
# Install (see ~/nixos-drafts/README.md for the full steps):
#   1. create the swap file and get RESUME_OFFSET (README step 1)
#   2. put the number below, then: sudo cp ~/nixos-drafts/power.nix /etc/nixos/
#   3. add ./power.nix to `imports` in /etc/nixos/configuration.nix
#   4. sudo nixos-rebuild switch
{ pkgs, lib, ... }:

let
  # How long a sleeping laptop waits before hibernating: longDelay while the
  # battery is at or above hibernateThreshold percent (or on AC power),
  # shortDelay below it. `battery-report` (battery-log.nix) shows how fast
  # sleep really drains the battery, which is what to tune these against.
  hibernateThreshold = 50;
  longDelay = "2h";
  shortDelay = "15min";

  # Runs just before each suspend-then-hibernate and writes the delay for this
  # sleep as a sleep.conf drop-in, which systemd-sleep then reads.
  chooseHibernateDelay = pkgs.writeShellApplication {
    name = "choose-hibernate-delay";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      pct=$(cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -n1)
      ac=0
      for s in /sys/class/power_supply/*; do
        if [ "$(cat "$s/type" 2>/dev/null)" = Mains ] && [ "$(cat "$s/online" 2>/dev/null)" = 1 ]; then
          ac=1
        fi
      done
      if [ "$ac" = 1 ] || [ "''${pct:-100}" -ge ${toString hibernateThreshold} ]; then
        delay=${longDelay}
      else
        delay=${shortDelay}
      fi
      mkdir -p /run/systemd/sleep.conf.d
      printf '[Sleep]\nHibernateDelaySec=%s\n' "$delay" > /run/systemd/sleep.conf.d/50-hibernate-delay.conf
      echo "battery ''${pct:-?}%, AC $ac: hibernating after $delay asleep"
    '';
  };
in
{
  # ---- Lock screen and idle ----
  # Gives hyprlock a PAM entry (without it hyprlock can't check your password)
  # and runs hypridle as a user service. Both read their configs from ~/.config/hypr/.
  programs.hyprlock.enable = true;

  # The hypridle service runs with its own short PATH (hyprland, hyprlock, coreutils),
  # so the idle dimming and kbd-fade.sh need brightnessctl added to it explicitly.
  systemd.user.services.hypridle.path = [ pkgs.brightnessctl ];

  # Media keys (play/pause/next) in hyprland.lua need this.
  environment.systemPackages = [ pkgs.playerctl ];

  # ---- Hibernation ----
  # A 64 GB swap file (>= RAM) on the encrypted btrfs volume, so the saved RAM
  # image is encrypted too. Swap otherwise sits unused unless memory runs out.
  swapDevices = [ { device = "/swap/swapfile"; } ];

  # Where the kernel looks for the hibernation image at boot (after you unlock
  # the disk). The offset locates the swap file inside the btrfs volume.
  boot.resumeDevice = "/dev/mapper/enc-pv";
  boot.kernelParams = [ "resume_offset=5514496" ];  

  # Sleep normally, then hibernate after longDelay or shortDelay asleep
  # depending on the battery (see the top of this file), so a closed laptop
  # never drains flat. The value here is only the fallback for when
  # choose-hibernate-delay fails; its drop-in overrides it.
  systemd.sleep.settings.Sleep = {
    HibernateDelaySec = longDelay;
  };
  # "-": if choosing fails, sleep anyway with the fallback.
  systemd.services.systemd-suspend-then-hibernate.serviceConfig.ExecStartPre =
    [ "-${lib.getExe chooseHibernateDelay}" ];

  # Closing the lid: sleep-then-hibernate on battery, plain sleep when plugged in.
  services.logind.settings.Login = {
    HandleLidSwitch = "suspend-then-hibernate";
    HandleLidSwitchExternalPower = "suspend";
  };
}
