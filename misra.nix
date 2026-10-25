# misra: cross-checks power and network sensors with logic rules (~/src/misra).
# State for the bar/HUD in /run/misra/state.json; alerts as notifications;
# snapshots in /var/lib/misra/snapshots (automatic on a new power fault).
# Uplink names live in /var/lib/misra/local.toml, and the location for the
# weather in /var/lib/misra/weather.toml (misra's ops/weather-location),
# deliberately not here: this repo is public.
# Weather: grey days turn the bar dark (misra rules/sky.lp), fetched by a
# separate unprivileged unit; the daemon itself has no network.
{ ... }:

{
  services.misra.enable = true;
  services.misra.weather.enable = true;
}
