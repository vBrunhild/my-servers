{config, ...}: let
  modules = config.flake.modules.nixos;
in {
  flake.modules.nixos.k3s = {
    config,
    lib,
    pkgs,
    ...
  }: {
    imports = [modules.kubectl];

    environment.systemPackages = map lib.lowPrio [
      pkgs.jq
      pkgs.k9s
      pkgs.kubectl
      pkgs.kubernetes-helm
    ];

    environment.variables.KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";

    services.k3s = {
      enable = true;
      role = "server";
      tokenFile = config.age.secrets.k3s-token.path;
      extraFlags = [
        "--disable=traefik"
      ];
    };
  };
}
