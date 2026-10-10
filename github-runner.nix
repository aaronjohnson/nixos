# Self-hosted GitHub Actions runner for aaronjohnson/nixos-intel-npu: builds the
# NPU compiler from source and runs Intel's NPU tests on this laptop's NPU.
#
# The workflow only sends work here for pushes to main and manual runs, never
# for pull requests, so code from other people's PRs can't run on this machine.
#
# The token file is NOT in this repo. Create a fine-grained personal access token
# (github.com > Settings > Developer settings > Fine-grained tokens) for the
# repository aaronjohnson/nixos-intel-npu with "Administration: Read and write"
# (that covers self-hosted runners), then:
#   sudo install -d -m 700 /var/lib/github-runner-secrets
#   echo -n 'github_pat_…' | sudo tee /var/lib/github-runner-secrets/nixos-intel-npu.token >/dev/null
#   sudo chmod 600 /var/lib/github-runner-secrets/nixos-intel-npu.token
{ config, pkgs, ... }:

{
  services.github-runners.nixos-intel-npu = {
    enable = true;
    url = "https://github.com/aaronjohnson/nixos-intel-npu";
    tokenFile = "/var/lib/github-runner-secrets/nixos-intel-npu.token";
    # Matches runs-on: [self-hosted, nixos, intel-npu] in the workflow.
    extraLabels = [
      "nixos"
      "intel-npu"
    ];
    replace = true;
    # A fixed user instead of systemd's DynamicUser, whose state and logs sit in
    # root-only /var/lib/private. With a fixed group, the logs (including live job
    # output under pages/) can be group-readable, and amj is in that group.
    user = "github-runner";
    group = "github-runner";
    serviceOverrides = {
      LogsDirectoryMode = "0750";
      # The module default (0066) makes the logs unreadable even to the group.
      UMask = "0027";
    };
    # nix for the builds, cachix so the workflow can push results to the cache.
    extraPackages = [
      config.nix.package
      pkgs.cachix
    ];
  };

  users.users.github-runner = {
    isSystemUser = true;
    group = "github-runner";
  };
  users.groups.github-runner = { };
  # Read-only access to the runner's logs for amj.
  users.users.amj.extraGroups = [ "github-runner" ];
}
