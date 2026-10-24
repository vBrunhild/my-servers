{
  pkgs,
  lib,
  ...
}: {
  environment.systemPackages = map lib.lowPrio [
    pkgs.jq
    pkgs.k9s
    pkgs.kubectl
    pkgs.kubernetes-helm
  ];

  environment.variables.KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";

  imports = [
    ./k3s
    ./restic.nix
    ./ssh.nix
  ];
}
