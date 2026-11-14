# ant, Anthropic's command-line client (Claude API, Managed Agents, `ant auth login`).
# Not in nixpkgs (nixpkgs' `ant` is Apache Ant), so built here from source.
# To update: set version, put lib.fakeHash in both hashes, build, copy the hashes it reports.
{ lib, buildGoModule, fetchFromGitHub }:

buildGoModule rec {
  pname = "anthropic-cli";
  version = "2.9.0";

  src = fetchFromGitHub {
    owner = "anthropics";
    repo = "anthropic-cli";
    rev = "v${version}";
    hash = "sha256-bjc2xaiyV5Lj+c8Oksmu3/Ij3J5+qj5Qak+yRlF4lJA=";
  };
  vendorHash = "sha256-j5JWaXTl6eDWVfcyyctZsFOWMdawmnqOAsCBSqig/jI=";

  subPackages = [ "cmd/ant" ];
  env.CGO_ENABLED = 0;
  ldflags = [ "-s" "-w" "-X main.version=${version}" ];
  doCheck = false;

  meta = {
    description = "Anthropic's command-line client";
    homepage = "https://github.com/anthropics/anthropic-cli";
    license = lib.licenses.asl20;
    mainProgram = "ant";
  };
}
