# misra: cross-checks power and network sensors with logic rules (~/src/misra).
# State for the bar/HUD in /run/misra/state.json; alerts as notifications;
# snapshots in /var/lib/misra/snapshots (automatic on a new power fault).
# Uplink names live in /var/lib/misra/local.toml, deliberately not here:
# this repo is public.
{ ... }:

{
  services.misra.enable = true;
}
