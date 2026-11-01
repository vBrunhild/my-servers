{
  flake.modules.nixos.radar = let
    security = import ./_security.nix;
  in {
    homepage.apps.radar = {
      title = "Radar";
      url = "https://radar.brunhild.org";
      icon = "https://radarhq.io/radar/icon-512.png";
      groups = ["admin"];
    };

    services.k3s.manifests.radar-namespace = {
      enable = true;
      content = {
        apiVersion = "v1";
        kind = "Namespace";
        metadata = {
          name = "radar";
          labels = security.namespaceLabels;
        };
      };
    };

    services.k3s.autoDeployCharts.radar = {
      name = "radar";
      repo = "https://skyhook-io.github.io/helm-charts";
      version = "1.19.0";
      hash = "sha256-thugS++e9Z5JvtE/zljET+e9BdFAJuecZkCjkN3o2Kc=";
      createNamespace = true;
      targetNamespace = "radar";

      values = {
        ingress.enabled = false;

        extraArgs = [
          "--mcp-read-only"
          "--prometheus-url=http://victoria-metrics.monitoring.svc:8428"
        ];

        podAnnotations = security.ignoreChecks ["automountServiceAccountToken"];

        resources = {
          requests = {
            cpu = "50m";
            memory = "128Mi";
          };
          limits.memory = "512Mi";
        };

        auth.mode = "none";
        allowedHosts = ["radar.brunhild.org"];
      };
    };

    services.k3s.manifests.radar-ingress-route = {
      enable = true;
      content = {
        apiVersion = "traefik.io/v1alpha1";
        kind = "IngressRoute";
        metadata = {
          name = "radar";
          namespace = "radar";
        };
        spec = {
          entryPoints = ["websecure"];
          routes = [
            {
              match = "Host(`radar.brunhild.org`)";
              kind = "Rule";
              middlewares = [
                {
                  name = "authelia";
                  namespace = "traefik-system";
                }
              ];
              services = [
                {
                  name = "radar";
                  port = 9280;
                }
              ];
            }
          ];
          tls.certResolver = "cloudflare";
        };
      };
    };
  };
}
