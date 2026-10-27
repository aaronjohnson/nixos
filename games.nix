# Games: Steam for buying and playing, Godot and Aseprite for making them.
#
# Steam runs in its own FHS sandbox with 32-bit libraries, which needs
# hardware.graphics.enable32Bit (set in configuration.nix) and unfree
# packages (allowed there too). Proton runs Windows games; turn it on per
# game, or for all titles under Settings → Compatibility.
#
# Nothing here runs until a game does: gamemode only raises CPU/GPU
# governors while a game asks for it (launch option `gamemoderun %command%`),
# so the battery-saving defaults in power.nix hold the rest of the time.
# Remote Play and local game transfers stay off: they'd open firewall ports.
# One narrow exception below: khel builds for the Steam Deck.
{ pkgs, ... }:

{
  programs.steam.enable = true;
  # gamescope: a micro-compositor that runs a game at a lower resolution
  # and upscales it, a big battery and heat saving on the laptop panel.
  # Launch option: `gamescope -w 1280 -h 800 -F fsr -- %command%`.
  programs.gamescope.enable = true;
  programs.gamemode.enable = true;

  # `khel serve` hands the game's latest build to the Steam Deck over
  # the home Wi-Fi (the Deck has no password, so no SSH). Port 8765 is
  # let in only from the home network, and nothing listens on it except
  # while `khel serve` runs.
  networking.firewall.extraCommands = ''
    iptables -A nixos-fw -p tcp --dport 8765 -s 192.168.88.0/24 -j nixos-fw-accept
  '';
  networking.firewall.extraStopCommands = ''
    iptables -D nixos-fw -p tcp --dport 8765 -s 192.168.88.0/24 -j nixos-fw-accept || true
  '';

  environment.systemPackages = [
    # Game engine, GDScript; exports to Linux/Windows/web, and Steam via
    # the GodotSteam addon when a game is ready to publish.
    pkgs.godot
    # Pixel art and sprite animation; exports sprite sheets Godot imports.
    pkgs.aseprite
  ];
}
