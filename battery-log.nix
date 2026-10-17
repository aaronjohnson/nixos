# Battery log: how fast the battery drains each day, awake and asleep, and
# whether each hibernation actually came back.
#
#   battery-report        per-day summary
#   battery-report 20     ... plus the last 20 sleeps
#
# The data is two CSV files in /var/lib/battery-log/:
#   samples.csv  every 10 minutes while awake: time, percent, status, AC
#   sleeps.csv   one row per sleep: start and end time and percent, the
#                hibernate delay chosen (power.nix) and how it ended:
#                suspend, hibernate, or no-resume
#
# no-resume means the laptop went to sleep and next booted from scratch: the
# hibernation image was not restored, so whatever was open is gone. It is
# also announced in `journalctl -u battery-log-boot`. no-resume-kernel-changed
# means the default boot entry has a different kernel from the one that
# hibernated (a nixos-rebuild in between), and a kernel won't restore an image
# written by another one.
{ pkgs, lib, ... }:

let
  dir = "/var/lib/battery-log";

  batteryLog = pkgs.writeShellApplication {
    name = "battery-log";
    runtimeInputs = [ pkgs.coreutils pkgs.gnugrep pkgs.systemd ];
    text = ''
      dir=${dir}
      mkdir -p "$dir"
      [ -s "$dir/samples.csv" ] || echo "time,percent,status,ac" > "$dir/samples.csv"
      [ -s "$dir/sleeps.csv" ] || echo "start,end,start_percent,end_percent,ac,hibernate_delay,ended" > "$dir/sleeps.csv"

      pct() { cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -n1; }
      status() { cat /sys/class/power_supply/BAT*/status 2>/dev/null | head -n1; }
      ac() {
        for s in /sys/class/power_supply/*; do
          if [ "$(cat "$s/type" 2>/dev/null)" = Mains ] && [ "$(cat "$s/online" 2>/dev/null)" = 1 ]; then
            echo 1; return
          fi
        done
        echo 0
      }
      kernel() { readlink -f /run/booted-system/kernel; }

      case "''${1:-}" in
        sample)
          echo "$(date +%s),$(pct),$(status),$(ac)" >> "$dir/samples.csv"
          ;;

        # Before any sleep: remember how it started.
        pre-sleep)
          echo "$(date +%s),$(pct),$(ac),$(kernel)" > "$dir/pending"
          ;;

        # Back from a sleep in the same boot (suspend, or a restored hibernation).
        post-resume)
          [ -f "$dir/pending" ] || exit 0
          IFS=, read -r start spct sac _ < "$dir/pending"
          delay=$(grep -oP 'HibernateDelaySec=\K.*' /run/systemd/sleep.conf.d/50-hibernate-delay.conf 2>/dev/null || echo -)
          if journalctl -t systemd-sleep --since "@$start" -o cat | grep -q "sleep operation 'hibernate'"; then
            ended=hibernate
          else
            ended=suspend
          fi
          echo "$start,$(date +%s),$spct,$(pct),$sac,$delay,$ended" >> "$dir/sleeps.csv"
          rm "$dir/pending"
          ;;

        # At boot: a leftover pending sleep means it never came back.
        boot)
          [ -f "$dir/pending" ] || exit 0
          IFS=, read -r start spct sac skernel < "$dir/pending"
          rm "$dir/pending"
          # Unless the last boot's last word on sleep was a return from it
          # (a sleep that was cancelled, then a normal shutdown).
          last=$(journalctl -b -1 -t systemd-sleep -o cat -n 1 2>/dev/null || true)
          case "$last" in *"System returned"*) exit 0 ;; esac
          if [ "$skernel" = "$(kernel)" ]; then ended=no-resume; else ended=no-resume-kernel-changed; fi
          boot=$(grep -oP '^btime \K[0-9]+' /proc/stat)
          echo "$start,$boot,$spct,$(pct),$sac,-,$ended" >> "$dir/sleeps.csv"
          echo "The sleep that began $(date -d "@$start") was not resumed: booted fresh ($ended)"
          ;;

        *)
          echo "usage: battery-log sample|pre-sleep|post-resume|boot" >&2
          exit 1
          ;;
      esac
    '';
  };

  batteryReport = pkgs.writeScriptBin "battery-report" ''
    #!${pkgs.python3}/bin/python3
    """Per-day battery drain from ${dir}; with a number N, also the last N sleeps."""
    import csv
    import sys
    from collections import defaultdict
    from datetime import datetime

    DIR = "${dir}"
    GAP = 15 * 60  # samples further apart than this have a sleep or shutdown between them


    def rows(name):
        try:
            with open(f"{DIR}/{name}") as f:
                return list(csv.DictReader(f))
        except FileNotFoundError:
            return []


    def day(t):
        return datetime.fromtimestamp(t).strftime("%Y-%m-%d %a")


    def hm(secs):
        return f"{int(secs // 3600)}h{int(secs % 3600 // 60):02d}"


    def seconds(delay):
        """A systemd time span as written by choose-hibernate-delay: 2h, 15min, 90s."""
        for unit, mult in (("min", 60), ("h", 3600), ("s", 1)):
            if delay.endswith(unit) and delay[:-len(unit)].isdigit():
                return int(delay[:-len(unit)]) * mult
        return None


    def rate(pct, secs):
        return f"{pct / (secs / 3600):5.1f}%/h" if secs >= 600 else "      -"


    # Awake on battery: consecutive samples, both off AC, close together.
    awake = defaultdict(lambda: [0, 0])  # day -> [seconds, percent used]
    samples = [s for s in rows("samples.csv") if s["percent"]]
    for a, b in zip(samples, samples[1:]):
        t0, t1 = int(a["time"]), int(b["time"])
        if a["ac"] == b["ac"] == "0" and 0 < t1 - t0 <= GAP:
            awake[day(t0)][0] += t1 - t0
            awake[day(t0)][1] += int(a["percent"]) - int(b["percent"])

    # Asleep, by the day each sleep began. Drain counts only sleeps begun off AC,
    # and of a hibernated sleep only the suspended part (hibernation draws ~nothing).
    asleep = defaultdict(lambda: {"n": 0, "secs": 0, "pct": 0, "hib": 0, "lost": 0})
    sleeps = [s for s in rows("sleeps.csv") if s["start_percent"] and s["end_percent"]]
    for s in sleeps:
        d = asleep[day(int(s["start"]))]
        d["n"] += 1
        d["hib"] += s["ended"] == "hibernate"
        d["lost"] += s["ended"].startswith("no-resume")
        used = int(s["start_percent"]) - int(s["end_percent"])
        if s["ac"] == "0" and used >= 0:
            secs = int(s["end"]) - int(s["start"])
            if s["ended"] == "hibernate" and seconds(s["hibernate_delay"]):
                secs = min(secs, seconds(s["hibernate_delay"]))
            d["secs"] += secs
            d["pct"] += used

    print(f"{' ':15}  {'awake on battery':^22}  {'suspended (begun on battery)':^34}")
    print(f"{'day':15}  {'time':>6} {'used':>5} {'rate':>9}  "
          f"{'sleeps':>6} {'time':>6} {'used':>5} {'rate':>9} {'hib':>3} {'lost':>4}")
    for d in sorted(set(awake) | set(asleep)):
        aw, sl = awake[d], asleep[d]
        print(f"{d:15}  {hm(aw[0]):>6} {aw[1]:>4}% {rate(aw[1], aw[0]):>9}  "
              f"{sl['n']:>6} {hm(sl['secs']):>6} {sl['pct']:>4}% {rate(sl['pct'], sl['secs']):>9} "
              f"{sl['hib']:>3} {sl['lost']:>4}")

    secs = sum(d["secs"] for d in asleep.values())
    pct = sum(d["pct"] for d in asleep.values())
    if secs >= 3600:
        r = pct / (secs / 3600)
        print(f"\nSuspended on battery overall: {r:.1f}%/h, so waiting 2h to hibernate costs "
              f"about {2 * r:.1f}% and waiting 15min about {r / 4:.1f}%.")
    lost = sum(d["lost"] for d in asleep.values())
    if lost:
        print(f"{lost} sleep(s) were not resumed (booted fresh): see the 'ended' column below.")

    if len(sys.argv) > 1:
        print(f"\n{'start':16}  {'length':>6}  {'from':>4} {'to':>4}  {'AC':2}  {'delay':>6}  ended")
        for s in sleeps[-int(sys.argv[1]):]:
            t0, t1 = int(s["start"]), int(s["end"])
            print(f"{datetime.fromtimestamp(t0):%Y-%m-%d %H:%M}  {hm(t1 - t0):>6}  "
                  f"{s['start_percent']:>3}% {s['end_percent']:>3}%  {s['ac']:2}  "
                  f"{s['hibernate_delay']:>6}  {s['ended']}")
  '';
in
{
  environment.systemPackages = [ batteryReport ];

  # Started on the way into any sleep and stopped on the way out, like NixOS's
  # sleep-actions. (Not powerManagement.powerDownCommands: that also runs at
  # shutdown, which would look like a sleep that never came back.)
  systemd.services.battery-log-sleep = {
    description = "Log battery use across a sleep";
    wantedBy = [ "sleep.target" ];
    before = [ "sleep.target" ];
    unitConfig.StopWhenUnneeded = true;
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${lib.getExe batteryLog} pre-sleep";
      ExecStop = "${lib.getExe batteryLog} post-resume";
    };
  };

  systemd.services.battery-log-boot = {
    description = "Note a sleep that never resumed";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${lib.getExe batteryLog} boot";
    };
  };

  systemd.services.battery-sample = {
    description = "Log the battery level";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${lib.getExe batteryLog} sample";
    };
  };
  systemd.timers.battery-sample = {
    wantedBy = [ "timers.target" ];
    timerConfig.OnCalendar = "*:0/10";
  };
}
