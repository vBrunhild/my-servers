{
  pkgs,
  lib,
  ...
}: {
  environment.systemPackages = map lib.lowPrio [
    pkgs.jq
    pkgs.kubectl
    pkgs.kubernetes-helm
  ];

  imports = [
    ./k3s
    ./ssh.nix
  ];
}
