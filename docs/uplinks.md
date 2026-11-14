# Uplinks: how hadron stays online, and how to get unstuck

Everything here works offline. Read it in a terminal: `less ~/nixos/docs/uplinks.md`.
The automatic part is `phone-fallback.nix`; the manual levers are `uplink`
(in dotfiles, `uplink help`). Network names live in `~/.config/uplinks.env`,
never in this repo (it is public).

## The priority ladder

NetworkManager joins the highest-priority saved Wi-Fi in range **when it has
none**. It never leaves a joined network for a better one by itself: step 1
of phone-fallback does that, and only when the joined one is dead.

| priority | uplink | notes |
|---:|---|---|
| 100 | Starlink | planned |
| 50 | phone Wi-Fi hotspot | full speed; a manual switch on the phone |
| 20 | local Wi-Fi we were given | guest networks, friends' homes (`ops/wifi-priority.sh`) |
| 0–10 | cafes, everything else | |
| — | phone Bluetooth tether | not a Wi-Fi; only phone-fallback brings it up |

## States

Each state is named by what NM's internet check (every 60 s) says about the
Wi-Fi, and whether the Bluetooth tether is up.

```
                       Wi-Fi joins, check passes
        ┌──────────────────────────────────────────────────────┐
        │                                                      ▼
  ┌───────────┐  no Wi-Fi /    ┌──────────────┐  check   ┌──────────┐
  │  NO WIFI  │  check fails   │  WIFI DEAD   │◀─fails───│  ONLINE  │
  │  (none)   │──────────────▶ │(none/limited)│          │  (full)  │
  └───────────┘                └──────────────┘          └──────────┘
        │                        │1          │3               ▲  ▲
        │                        │ better    │ no better      │  │
        │3                       │ saved     │ Wi-Fi          │  │
        │                        │ Wi-Fi in  ▼                │  │
        │                        │ range  ┌──────────────┐    │  │
        └──────────────────────▶ │        │  PHONE BT    │─2──┘  │
                                 │        │ (tether up,  │ any other
                                 │        │  slow)       │ device full:
                                 │        └──────────────┘ drop tether
                                 │               │ connect fails
                                 ▼               ▼
                          switch to it    ┌──────────────┐
                          (e.g. hotspot)  │ PHONE AWAY   │ wait 5 min,
                          5 min backoff ──│ (backoff)    │ then try 3 again
                          then ONLINE     └──────────────┘
                          or DEAD again

  Left alone on purpose:
    LOGIN PAGE (portal)   cafe sign-in; the page must load over that Wi-Fi.
    WIFI OFF (radio off)  offline by choice; no fallback.
    PAUSED                `uplink pause`; nothing automatic until resume/boot.
```

Numbers are phone-fallback's steps, tried in order each run (every 30 s, and
at once when the internet check changes): **1** upgrade off a dead Wi-Fi to a
higher-priority one in range, **2** hand back from the tether once anything
else has full internet, **3** fall back to the tether.

What you see: the top bar's Wi-Fi % turns orange with "no internet" or
"login page"; a yellow **phone bt** chip while on the tether; an orange
**phone away** while it waits to retry. `uplink` prints the same in a terminal.

## Escape ladder: stuck? Go down until it works

1. **Look.** `uplink`: what you're on, whether it has internet, what's in range.
2. **Turn on the phone hotspot.** Within 30 s step 1 moves to it. Or force it:
   `uplink hotspot`.
3. **Use the tether now:** `uplink phone` (ignores the 5 min backoff).
4. **Leave this Wi-Fi for good:** `uplink skip`. It stops auto-joining
   (`autoconnect no`) and NM picks the next best. Undo: `uplink unskip NAME`.
   This replaces moving the `.nmconnection` file out of
   `/etc/NetworkManager/system-connections` (still works, needs sudo).
5. **Automation misbehaving** (flapping, tether you don't want):
   `uplink pause`; `uplink resume` or a reboot brings it back.
6. **Big hammer:** `uplink reset` (tether down, Wi-Fi radio off and on).
7. **Last resort:** reboot. Every fix above survives it except pause.

Logs: `journalctl -u phone-fallback` (what the automation did and why),
`journalctl -u NetworkManager -u bluetooth` (the gory detail).

## Known edges

- After a switch, reboot or wake, the tether may come up for a few seconds
  while the Wi-Fi rejoins, then drop. Harmless.
- The tether needs the phone's **Bluetooth tethering** on and the laptop's
  **Internet sharing** toggle on its Bluetooth page (`ops/phone-fallback-setup.sh`).
  The phone has gone unreachable for a while once (2026-11-13), cause unknown.
- A saved Wi-Fi only counts as "in range" from NM's last scan, which can be a
  couple of minutes old.
- Hotspot rename planned (to lowercase `network`): steps in `~/.config/uplinks.env`.
