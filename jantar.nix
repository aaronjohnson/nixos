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
  };
}
