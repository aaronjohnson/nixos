# Sleep, lock screen and hibernation for the Framework 13 Pro.
#
# Install (see ~/nixos-drafts/README.md for the full steps):
#   1. create the swap file and get RESUME_OFFSET (README step 1)
#   2. put the number below, then: sudo cp ~/nixos-drafts/power.nix /etc/nixos/
#   3. add ./power.nix to `imports` in /etc/nixos/configuration.nix
#   4. sudo nixos-rebuild switch
{ pkgs, ... }:

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
  # acpi=copy_dsdt: keep the firmware's ACPI table (DSDT) in kernel memory, so it is saved in
  # the hibernation image. Without it, resuming on 2026-10-17 found the firmware had reused the
  # DSDT's memory ("The DSDT has been corrupted or replaced"): every ACPI method failed from then
  # on (lid, battery and charger status, the USB-C controller), until a reboot.
  boot.kernelParams = [ "resume_offset=5514496" "acpi=copy_dsdt" ];

  # Sleep normally, then hibernate after 2 hours asleep (or sooner if the
  # battery runs low), so a closed laptop never drains flat.
  systemd.sleep.settings.Sleep = {
    HibernateDelaySec = "2h";
  };

  # Closing the lid: sleep-then-hibernate on battery, plain sleep when plugged in.
  services.logind.settings.Login = {
    HandleLidSwitch = "suspend-then-hibernate";
    HandleLidSwitchExternalPower = "suspend";
  };
}
