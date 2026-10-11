# btop on tty11 (Ctrl+Alt+F11) and nvtop on tty10 (Ctrl+Alt+F10), with no
# login, next to jantar on tty12. Ctrl+Alt+F1 returns to Hyprland.
#
# They run as their own unprivileged user: btop and nvtop can kill
# processes, and anyone at the keyboard can reach these consoles (even while
# Hyprland is locked), so they can only signal their own processes, never
# yours. Per-process GPU use in nvtop needs to read other users' fdinfo, so
# nvtop shows the GPU's totals here, not who is using it.
#
# Neither knows when its console is hidden, so each runs under a small
# wrapper that pauses it (SIGSTOP) while another console is on screen and
# resumes it (SIGCONT) on switching to it: one wakeup a second instead of a
# full redraw every two.
{ pkgs, lib, ... }:

let
  # Run `cmd` on ttyN, paused while that tty isn't in the foreground.
  onTty = tty: cmd: pkgs.writeShellScript "on-tty${toString tty}" ''
    # Explicit <&0: bash otherwise gives a background job /dev/null as stdin.
    ${cmd} <&0 &
    pid=$!
    trap 'kill -CONT $pid; kill $pid' TERM INT
    paused=0
    while kill -0 "$pid" 2>/dev/null; do
      if [ "$(cat /sys/class/tty/tty0/active)" = tty${toString tty} ]; then
        [ $paused = 1 ] && kill -CONT "$pid" && paused=0
      else
        [ $paused = 0 ] && kill -STOP "$pid" && paused=1
      fi
      sleep 1
    done
    wait "$pid"
  '';

  service = name: tty: cmd: {
    description = "${name} on tty${toString tty}";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-user-sessions.service" ];
    conflicts = [ "getty@tty${toString tty}.service" "autovt@tty${toString tty}.service" ];
    path = [ pkgs.coreutils ];
    environment = {
      TERM = "linux";
      LANG = "C.UTF-8";
      HOME = "/var/lib/console-tui";
    };
    serviceConfig = {
      ExecStart = onTty tty cmd;
      User = "console-tui";
      Group = "console-tui";
      # systemd opens the tty before dropping to the user, as for a getty.
      StandardInput = "tty";
      StandardOutput = "tty";
      StandardError = "journal";
      TTYPath = "/dev/tty${toString tty}";
      TTYReset = true;
      TTYVHangup = true;
      TTYVTDisallocate = true;
      # Quitting (q, Ctrl+C) just starts it again.
      Restart = "always";
      RestartSec = 2;
      StateDirectory = "console-tui";
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      RestrictAddressFamilies = [ "AF_UNIX" "AF_NETLINK" ];
      IPAddressDeny = "any";
    };
  };
in
{
  users.users.console-tui = {
    isSystemUser = true;
    group = "console-tui";
    # nvtop reads the GPU through its render node (render group) only. Not
    # video: that also opens /dev/dri/card0, and whoever opens it while no one
    # holds the display becomes DRM master, which left Hyprland unable to take
    # the display back after a console switch (2026-10-10).
    extraGroups = [ "render" ];
    home = "/var/lib/console-tui";
    description = "btop and nvtop on tty11 and tty10";
  };
  users.groups.console-tui = { };

  systemd.services.btop-tty11 = service "btop" 11 "${pkgs.btop}/bin/btop --tty";
  systemd.services.nvtop-tty10 = service "nvtop" 10 "${pkgs.nvtopPackages.intel}/bin/nvtop";
}
