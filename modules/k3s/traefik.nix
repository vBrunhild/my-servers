{
  flake.modules.nixos.traefik = {config, ...}: let
    inherit (config) kubectl;
    secrets = config.age.secrets;

    security = import ./_security.nix;
  in {
    services.k3s.manifests.traefik-namespace = {
      enable = true;
      content = {
        apiVersion = "v1";
        kind = "Namespace";
        metadata = {
          name = "traefik-system";
          labels = security.namespaceLabels;
        };
      };
    };

    kubectl.secrets.cloudflare-api-token = {
      namespace = "traefik-system";
      file = secrets.cloudflare-api-token.path;
    };

    services.k3s.autoDeployCharts.traefik-proxy = {
      name = "traefik";
      repo = "https://helm.traefik.io/traefik";
      version = "42.2.0";
      hash = "sha256-A+x3Lgyqs589Jl2xQBT1aDKrQg2pjWIQ+D0++QjAd+U=";
      createNamespace = true;
      targetNamespace = "traefik-system";

      values = {
        providers.kubernetesCRD.allowCrossNamespace = true;

        deployment = {
          replicas = 1;
        };

        resources = {
          requests = {
            cpu = "100m";
            memory = "128Mi";
          };
          limits.memory = "1Gi";
        };

        service.spec.externalTrafficPolicy = "Local";

        accessLog.enabled = true;

        experimental.plugins.crowdsec-bouncer = {
          moduleName = "github.com/maxlerebourg/crowdsec-bouncer-traefik-plugin";
          version = "v1.8.1";
        };

        volumes = [
          {
            name = "crowdsec-bouncer-key";
            mountPath = "/etc/crowdsec-bouncer";
            type = "secret";
          }
        ];

        ports = {
          web.http.redirections.entryPoint = {
            to = "websecure";
            scheme = "https";
            permanent = true;
          };

          websecure.http.middlewares = [
            "traefik-system-crowdsec-bouncer@kubernetescrd"
          ];
        };

        additionalArguments = [
          "--certificatesresolvers.cloudflare.acme.dnschallenge=true"
          "--certificatesresolvers.cloudflare.acme.dnschallenge.provider=cloudflare"
          "--certificatesresolvers.cloudflare.acme.email=brunomoretti100@gmail.com"
          "--certificatesresolvers.cloudflare.acme.storage=/data/acme.json"
        ];

        env = [
          {
            name = "CF_DNS_API_TOKEN";
            valueFrom = kubectl.secrets.cloudflare-api-token.valueFrom;
          }
        ];

        persistence = {
          enabled = true;
          name = "data";
          size = "128Mi";
          path = "/data";
        };
      };
    };
  };
}
