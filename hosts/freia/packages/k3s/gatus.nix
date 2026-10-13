let
  publicEndpoint = name: url: extra:
    {
      inherit name url;
      group = "Websites";
      interval = "60s";
      conditions = [
        "[STATUS] == 200"
        "[CERTIFICATE_EXPIRATION] > 168h"
      ];
    }
    // extra;

  config = {
    ui = {
      title = "brunhild status";
      header = "brunhild status";
    };

    endpoints = [
      (publicEndpoint "Foundry VTT" "https://foundryvtt.brunhild.org" {
        client.ignore-redirect = true;
        conditions = [
          "[STATUS] == any(302, 401)"
          "[CERTIFICATE_EXPIRATION] > 168h"
        ];
      })
      (publicEndpoint "Authelia" "https://auth.brunhild.org/api/health" {})
      (publicEndpoint "Vaultwarden" "https://vaultwarden.brunhild.org/alive" {})
      (publicEndpoint "Headlamp" "https://headlamp.brunhild.org" {})
      {
        name = "Foundry VTT";
        group = "Applications";
        url = "http://foundryvtt.foundryvtt.svc.cluster.local";
        interval = "60s";
        client.ignore-redirect = true;
        conditions = ["[STATUS] == any(200, 302)"];
      }
    ];
  };
in {
  services.k3s.manifests.gatus-namespace = {
    enable = true;
    content = {
      apiVersion = "v1";
      kind = "Namespace";
      metadata.name = "gatus";
    };
  };

  services.k3s.manifests.gatus-config = {
    enable = true;
    content = {
      apiVersion = "v1";
      kind = "ConfigMap";
      metadata = {
        name = "gatus-config";
        namespace = "gatus";
      };
      data."config.yaml" = builtins.toJSON config;
    };
  };

  services.k3s.manifests.gatus-deployment = {
    enable = true;
    content = {
      apiVersion = "apps/v1";
      kind = "Deployment";
      metadata = {
        name = "gatus";
        namespace = "gatus";
      };
      spec = {
        replicas = 1;
        selector.matchLabels.app = "gatus";
        template = {
          metadata.labels.app = "gatus";
          spec = {
            containers = [
              {
                name = "gatus";
                image = "twinproduction/gatus:v5.37.0";
                ports = [{containerPort = 8080;}];

                resources = {
                  requests = {
                    cpu = "10m";
                    memory = "32Mi";
                  };
                  limits.memory = "128Mi";
                };

                volumeMounts = [
                  {
                    name = "config";
                    mountPath = "/config";
                    readOnly = true;
                  }
                ];

                readinessProbe = {
                  httpGet = {
                    path = "/health";
                    port = 8080;
                  };
                  initialDelaySeconds = 5;
                  periodSeconds = 10;
                };

                livenessProbe = {
                  httpGet = {
                    path = "/health";
                    port = 8080;
                  };
                  initialDelaySeconds = 15;
                  periodSeconds = 30;
                };
              }
            ];

            volumes = [
              {
                name = "config";
                configMap.name = "gatus-config";
              }
            ];
          };
        };
      };
    };
  };

  services.k3s.manifests.gatus-service = {
    enable = true;
    content = {
      apiVersion = "v1";
      kind = "Service";
      metadata = {
        name = "gatus";
        namespace = "gatus";
      };
      spec = {
        selector.app = "gatus";
        ports = [
          {
            port = 80;
            targetPort = 8080;
          }
        ];
      };
    };
  };

  services.k3s.manifests.gatus-ingress-route = {
    enable = true;
    content = {
      apiVersion = "traefik.io/v1alpha1";
      kind = "IngressRoute";
      metadata = {
        name = "gatus";
        namespace = "gatus";
      };
      spec = {
        entryPoints = ["websecure"];
        routes = [
          {
            match = "Host(`status.brunhild.org`)";
            kind = "Rule";
            services = [
              {
                name = "gatus";
                port = 80;
              }
            ];
          }
        ];
        tls.certResolver = "cloudflare";
      };
    };
  };
}
