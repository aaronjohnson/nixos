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
  };
}
