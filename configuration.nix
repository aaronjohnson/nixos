# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, lib, pkgs, claude-code-flake, ... }: {

  # Solarized Dark on the text consoles (Ctrl+Alt+F2…)
  console.colors = [
    "002b36" "dc322f" "859900" "b58900" "268bd2" "d33682" "2aa198" "eee8d5"
    "073642" "cb4b16" "586e75" "657b83" "839496" "6c71c4" "93a1a1" "fdf6e3"
  ];

  # Intel NPU driver plus its model compiler (from the nixos-intel-npu flake).
  hardware.intel-npu-compiler.enable = true;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Binary cache for nixos-intel-npu (filled by its CI, incl. this laptop's runner).
  nix.settings.extra-substituters = [ "https://nixos-intel-npu.cachix.org" ];
  nix.settings.extra-trusted-public-keys = [
    "nixos-intel-npu.cachix.org-1:ikhkuI/crInBQxA1PBUQAupWk13HfJCDAIYHHn7/g3A="
  ];

  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ./github-runner.nix   # self-hosted CI runner for nixos-intel-npu
      ./power.nix
      ./jantar.nix          # dashboard on VT12 (Ctrl+Alt+F12)
      # ./consoles.nix      # btop on VT11, nvtop on VT10: off for now (Hyprland lost the
      #                     # display on returning from them, 2026-10-10)
    ];

  environment.sessionVariables = {
    WLR_NO_HARDWARE_CURSORS = "1";
    NIXOS_OZONE_WL = "1";
  };

  programs.uwsm.enable = true;

  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  environment.variables.EDITOR = "emacs -nw";

  environment.systemPackages = with pkgs; [
    btop
    nvtopPackages.intel
    fbcat grim      # fbcat provides fbgrab (console screenshots)
    file            # identify file types
    bc              # command-line calculator
    tofi
    yazi
    wl-clipboard
    git
    gh
    vim
    iw
    hyprpolkitagent
    mako hyprlock hypridle hyprshot hyprpaper pavucontrol
    hyprsunset hyprpicker blueman
    ((emacsPackagesFor emacs-pgtk).emacsWithPackages (p: [
      p.solarized-theme   # GUI Emacs follows the light/dark switch (see ~/.emacs.d/init.el)
      p.nix-mode          # colours and indents .nix files
    ]))
    quickshell
    kitty
    pkgs.claude-code
    rofi
    brightnessctl
    waybar
    tuigreet
    nodejs
  ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Use latest kernel.
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.initrd.kernelModules = [ "xe" "i915" ];

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  hardware.enableRedistributableFirmware = true;

  # networking.hostName = "nixos"; # Define your hostname.
  networking.hostName = "hadron";

  # Configure network connections interactively with nmcli or nmtui.
  networking.networkmanager.enable = true;
  # Log why a connection fails, not just that it did: INFO overall, and the
  # DHCP and IPv4 address steps in detail (they only log on lease events, so
  # this stays small). Added after a Wi-Fi roam lost its address on
  # 2026-10-10 and the WARN-level log couldn't say why.
  networking.networkmanager.logLevel = "INFO";
  networking.networkmanager.settings.logging.domains = "DEFAULT,DHCP4:DEBUG,DHCP6:DEBUG,IP4:DEBUG";
  #networking.wireless.enable = false;

  # Set your time zone.
  # time.timeZone = "Europe/Amsterdam";

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Select internationalisation properties.
  # i18n.defaultLocale = "en_US.UTF-8";
  # console = {
  #   font = "Lat2-Terminus16";
  #   keyMap = "us";
  #   useXkbConfig = true; # use xkb.options in tty.
  # };

  # Enable the X11 windowing system.
  services.xserver.enable = true;

  services.displayManager.gdm.enable = false;

  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --cmd '${pkgs.uwsm}/bin/uwsm start hyprland.desktop'";
        user = "greeter";
      };
    };
  };

  security.pam.services.greetd.enableGnomeKeyring = true;

  systemd.services.greetd.serviceConfig = {
    Type = "idle";
    StandardInput = "tty";
    StandardOutput = "tty";
    StandardError = "tty";
    TTYReset = true;
    TTYVHangup = true;
    TTYVDisallocate = true;
  };

  services.desktopManager.gnome = {
    enable = true;
    extraGSettingsOverrides = ''
      [org.gnome.mutter]
      experimental-features=['scale-monitor-framebuffer']
    '';
  };

  nixpkgs.config.allowUnfree = true;
  services.fwupd.enable = true;

  time.timeZone = "America/Los_Angeles";

  # Text consoles (and the boot unlock prompt) use the same Japanese layout as the desktop.
  console.useXkbConfig = true;

  services.xserver.xkb = {
    layout = "jp";
    model = "jp106";
    options = "ctrl:nocaps"; # Caps Lock (英数) as an extra Ctrl, as in Hyprland
    variant = "";
  };
  
  i18n.inputMethod = {
     enable = true;
     type = "fcitx5";
     fcitx5.waylandFrontend = true;
     fcitx5.addons = with pkgs; [
       fcitx5-anthy
       #fcitx5-configtool
       fcitx5-gtk
     ];
  };

  # Configure keymap in X11
  # services.xserver.xkb.layout = "us";
  # services.xserver.xkb.options = "eurosign:e,caps:escape";

  # Enable CUPS to print documents.
  # services.printing.enable = true;

  # Enable sound.
  # services.pulseaudio.enable = true;
  # OR
  # services.pipewire = {
  #   enable = true;
  #   pulse.enable = true;
  # };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.amj = {
    isNormalUser = true;
    uid = 1000;
    description = "Aaron";
    extraGroups = [ "wheel" "networkmanager" "video" ]; # video: /dev/fb0 for hud --fb
  };

  # users.users.alice = {
  #   isNormalUser = true;
  #   extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
  #   packages = with pkgs; [
  #     tree
  #   ];
  # };

  # programs.firefox.enable = true;

  # List packages installed in system profile.
  # You can use https://search.nixos.org/ to find more packages (and options).
  # environment.systemPackages = with pkgs; [
  #   vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
  #   wget
  # ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  # system.copySystemConfiguration = true;

  # This option defines the first version of NixOS you have installed on this particular machine,
  # and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
  #
  # Most users should NEVER change this value after the initial install, for any reason,
  # even if you've upgraded your system to a new NixOS release.
  #
  # This value does NOT affect the Nixpkgs version your packages and OS are pulled from,
  # so changing it will NOT upgrade your system - see https://nixos.org/manual/nixos/stable/#sec-upgrading for how
  # to actually do that.
  #
  # This value being lower than the current NixOS release does NOT mean your system is
  # out of date, out of support, or vulnerable.
  #
  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "26.05"; # Did you read the comment?

}
