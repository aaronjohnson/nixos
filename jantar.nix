# jantar: polar-dial system dashboard on its own text console.
# Ctrl+Alt+F12 shows it (no login); Ctrl+Alt+F1 returns to Hyprland.
# It samples all the time and only draws while VT12 is on screen.
{ ... }:

{
  services.jantar = {
    enable = true;
    tty = 12;
    backend = "cairo";
    # Read the CI runner's step/progress for the footer.
    extraGroups = [ "github-runner" ];
    # RAPL power breakdown (platform, package, cores, graphics, memory). This
    # gives the jantar group read access to counters the kernel keeps
    # root-only since the Platypus attack; jantar has no network access.
    # Decided 2026-10-10.
    powercap = true;
    # Calibrated 2026-10-10 by moving the FIDO key (USB 2) between bays.
    usbBays = {
      "3-3" = "port1"; # right front
      "3-4" = "port2"; # left front
      "3-5" = "port3"; # left back
    };
  };
}
