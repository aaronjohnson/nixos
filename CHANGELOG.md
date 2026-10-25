# Observing log of hadron

Kept at the eyepiece. Newest night on top. Each entry is a night's observation of
the system, numbered by NixOS generation: the range of `system-N` profiles switched
that night (boot menu shows the last ten). Weather is as reported by the
instruments, or by the observer when the instruments were the thing being fixed.

## Gen 56–67 · 25 October 2026 · overcast with rain, a twelve-switch night

The busiest night yet, and the first where the sky itself was on the chart: misra
now reads the local weather and turns the bar dark on grey days.

- **External keyboard.** A Keychron K2 Pro left on its Mac setting (for its other
  hosts) now sends F1–F12 here, via a udev hwdb rule, so the Super+F shortcuts work
  without Fn. Replug the keyboard after switching.
- **Password prompts from the bar.** quickshell is now the polkit agent, so pkexec
  prompts match the other popups; hyprpolkitagent is gone. Without quickshell,
  pkexec falls back to a text prompt.
- **A README** describing each file, the desktop keys, and how a change lands and
  switches, with a screenshot of the Super+F2 keys menu.
- **Safer tooling.** npm never runs install scripts (`ignore-scripts=true` in
  `/etc/npmrc`); direnv with nix-direnv enters a project's flake devShell on `cd`.
  Project-specific CLIs moved out of the system and into those devShells.
  `/usr/src` holds other people's checkouts, outside the home directory that
  Claude Code trusts.
- **Google Chrome** with the Claude extension force-installed by policy, for
  Claude in Chrome.
- **misra 0.2 to 0.5**: power alerts carry a chart of the power sensors, the rules
  explain their answers, the weather unit runs as its own system user (location
  kept out of this repo), and misra can now vet Claude Code's shell commands
  before they run, and says which package to add when a command is not found.

## Gen 54–55 · 24 October 2026 · the lid that saw nothing for a week

After a hibernate resume on 17 October the firmware had overwritten the ACPI DSDT,
and from then on every ACPI call failed quietly: no lid events, no battery or
charger status, and eventually a USB-C controller failure that took a dock's
display, keyboard and trackball down. Only a reboot recovered.

- **Fix:** boot with `acpi=copy_dsdt`, the kernel's own suggestion, so the table is
  copied into kernel memory and travels inside the hibernation image.
- **Power button handed to Hyprland:** a tap locks, a hold opens the quickshell
  power menu. A ten-second hold still forces the machine off in firmware.
- Nerd Font symbols as an icon fallback for the bar, kitty and the power menu;
  rclone for moving files to and from Drive.

## Gen 50–53 · 14–18 October 2026 · a second instrument on the mount

- **Idle dimming works.** hypridle's service has a fixed PATH, so its dim and
  keyboard-fade steps couldn't find `brightnessctl`. Now they can.
- **misra arrives:** a sandboxed root service with no capabilities that reads the
  embedded controller and firmware tables, cross-checks them against ACPI and USB-C
  reports with logic rules, and checks again after every resume. Network names
  live in `/var/lib/misra/local.toml`, not here.
- A pair of cloud CLIs were added for web deploys (and moved to per-project
  devShells on 25 October).

## Gen 38–49 · 12–13 October 2026 · clear, with one lesson in what not to probe

- **Privacy switches on the bar.** A root service asks the EC every three seconds
  for the hardware mic and camera switch positions (they send no events) and writes
  the state where quickshell watches it.
- **Software privacy kill (Super+F7):** de-authorises the built-in webcam on USB so
  it disappears, with the setting kept across reboots, and drops the sound card to
  an output-only profile. External cameras and mics are left alone.
- **EC tools instead of GPIO pokes.** `framework-tool` and an upstream `fw-ectool`
  for read-only embedded-controller queries, after probing SoC GPIO lines crashed
  the Wi-Fi/Bluetooth firmware.
- **The NPU gets a workout:** jantar's NPU screen shows how a job moves through the
  hardware, and runs real-workload examples (background blur, Whisper, a Llama
  layer, detection, embeddings). Intel's GPU compute runtime lets OpenVINO compare
  CPU, GPU and NPU on them.
- Printing over driverless IPP, an SSH agent socket so signed commits need no
  prompt, backlight access for idle dimming, a boot menu that keeps ten
  generations, and visible asterisks at the login prompt.

## Gen 16–37 · 10–11 October 2026 · first light

The configuration went into version control: a flake on nixos-unstable for a
Framework Laptop 13 Pro (Intel Core Ultra, Arc graphics, NPU).

- **The base system:** Hyprland under UWSM with greetd/tuigreet, a quickshell bar,
  hyprlock and hypridle, suspend-then-hibernate on lid close to an encrypted swap
  file, a Japanese keyboard and Anthy input through fcitx5, Emacs, and Solarized
  text consoles that follow the Japanese layout too.
- **The NPU, working:** the Intel NPU compiler from
  [nixos-intel-npu](https://github.com/aaronjohnson/nixos-intel-npu) passes all 315
  of Intel's driver tests and runs OpenVINO models. Its binary cache saves the
  rebuild, and a self-hosted Actions runner tests that project on this NPU (pushes
  to main only, never pull requests).
- **jantar,** a polar-dial dashboard on tty12 (Ctrl+Alt+F12): power, storage,
  network, every USB-C port calibrated, NPU dials, zoom into a section.
- **Tried and shelved:** btop and nvtop on their own consoles. Hyprland couldn't
  take the display back after visiting them; `consoles.nix` waits for a better
  night.
- NetworkManager logs DHCP and IPv4 at debug level, after Wi-Fi twice lost its
  address on roaming and the log couldn't say why.

## Gen 1–15 · 8–9 October 2026 · before the log was kept

Installation and early fiddling, unrecorded except in the profiles: NixOS 26.05 at
first, moved to unstable at generation 11. The plates from these nights were
not kept.
