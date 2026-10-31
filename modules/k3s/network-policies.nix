{
  flake.modules.nixos.network-policies = {lib, ...}: let
    namespaceFrom = name: {namespaceSelector.matchLabels."kubernetes.io/metadata.name" = name;};
    fromTraefik = namespaceFrom "traefik-system";

    policy = namespace: name: spec: {
      "netpol-${namespace}-${name}" = {
        enable = true;
        content = {
          apiVersion = "networking.k8s.io/v1";
          kind = "NetworkPolicy";
          metadata = {
            inherit name namespace;
          };
          inherit spec;
        };
      };
    };

    denyAll = namespace:
      policy namespace "default-deny" {
        podSelector = {};
        policyTypes = ["Ingress"];
      };

    allow = namespace: name: podLabels: from: ports:
      policy namespace name {
        podSelector.matchLabels = podLabels;
        policyTypes = ["Ingress"];
        ingress = [
          {
            inherit from;
            ports = map (port: {inherit port;}) ports;
          }
        ];
      };
  in {
    services.k3s.manifests = lib.mkMerge [
      (denyAll "authelia")
      (denyAll "craig")
      (denyAll "crowdsec")
      (denyAll "gatus")
      (denyAll "homepage")
      (denyAll "radar")
      (denyAll "vaultwarden")

      (allow "authelia" "authelia" {
        "app.kubernetes.io/name" = "authelia";
      } [fromTraefik] ["http"])
      (allow "craig" "craig" {app = "craig";} [fromTraefik] [9100 9001])
      (allow "craig" "craig-postgres" {app = "craig-postgres";} [{podSelector.matchLabels.app = "craig";}] [5432])
      (allow "craig" "craig-redis" {app = "craig-redis";} [{podSelector.matchLabels.app = "craig";}] [6379])
      (allow "crowdsec" "crowdsec-lapi" {
        k8s-app = "crowdsec";
        type = "lapi";
      } [fromTraefik {podSelector.matchLabels.type = "agent";}] [8080])
      (allow "gatus" "gatus" {app = "gatus";} [fromTraefik] [8080])
      (allow "homepage" "homepage" {app = "homepage";} [fromTraefik] [8080])
      (allow "radar" "radar" {
        "app.kubernetes.io/name" = "radar";
      } [fromTraefik] [9280])
      (allow "vaultwarden" "vaultwarden" {app = "vaultwarden";} [fromTraefik] [80])
    ];
  };
}
