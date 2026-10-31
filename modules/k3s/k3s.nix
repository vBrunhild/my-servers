{config, ...}: let
  modules = config.flake.modules.nixos;
in {
  flake.modules.nixos.k3s = {
    config,
    lib,
    pkgs,
    ...
  }: let
    auditPolicy = pkgs.writeText "k3s-audit-policy.json" (builtins.toJSON {
      apiVersion = "audit.k8s.io/v1";
      kind = "Policy";
      omitStages = ["RequestReceived"];
      rules = [
        {
          level = "Metadata";
          resources = [
            {
              group = "";
              resources = ["secrets"];
            }
          ];
        }
        {
          level = "None";
          verbs = ["get" "list" "watch"];
        }
        {level = "Metadata";}
      ];
    });
  in {
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
        "--secrets-encryption"
        "--protect-kernel-defaults"
        "--kube-apiserver-arg=audit-policy-file=${auditPolicy}"
        "--kube-apiserver-arg=audit-log-path=/var/lib/rancher/k3s/server/logs/audit.log"
        "--kube-apiserver-arg=audit-log-maxage=14"
        "--kube-apiserver-arg=audit-log-maxbackup=5"
        "--kube-apiserver-arg=audit-log-maxsize=50"
      ];
    };
  };
}
