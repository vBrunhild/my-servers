{config, ...}: let
  inherit (config) kubectl;
  secrets = config.age.secrets;
in {
  kubectl.secrets.vaultwarden-admin-token = {
    namespace = "vaultwarden";
    file = secrets.vaultwarden-admin-token.path;
  };

  services.k3s.manifests.vaultwarden-namespace = {
    enable = true;
    content = {
      apiVersion = "v1";
      kind = "Namespace";
      metadata.name = "vaultwarden";
    };
  };

  services.k3s.manifests.vaultwarden-pvc = {
    enable = true;
    content = {
      apiVersion = "v1";
      kind = "PersistentVolumeClaim";
      metadata = {
        name = "vaultwarden-data";
        namespace = "vaultwarden";
      };
      spec = {
        accessModes = ["ReadWriteOnce"];
        storageClassName = "local-path";
        resources.requests.storage = "1Gi";
      };
    };
  };

  services.k3s.manifests.vaultwarden-deployment = {
    enable = true;
    content = {
      apiVersion = "apps/v1";
      kind = "Deployment";
      metadata = {
        name = "vaultwarden";
        namespace = "vaultwarden";
      };
      spec = {
        replicas = 1;
        strategy.type = "Recreate";
        selector.matchLabels.app = "vaultwarden";
        template = {
          metadata.labels.app = "vaultwarden";
          spec = {
            containers = [
              {
                name = "vaultwarden";
                image = "vaultwarden/server:1.37.4";
                ports = [{containerPort = 80;}];

                resources = {
                  requests = {
                    cpu = "50m";
                    memory = "64Mi";
                  };
                  limits.memory = "512Mi";
                };

                env = [
                  {
                    name = "DOMAIN";
                    value = "https://vaultwarden.brunhild.org";
                  }
                  {
                    name = "SIGNUPS_ALLOWED";
                    value = "false";
                  }
                  {
                    name = "INVITATIONS_ALLOWED";
                    value = "true";
                  }
                  {
                    name = "SHOW_PASSWORD_HINT";
                    value = "false";
                  }
                  {
                    name = "ADMIN_TOKEN";
                    valueFrom = kubectl.secrets.vaultwarden-admin-token.valueFrom;
                  }
                ];

                volumeMounts = [
                  {
                    name = "data";
                    mountPath = "/data";
                  }
                ];

                readinessProbe = {
                  httpGet = {
                    path = "/alive";
                    port = 80;
                  };
                  initialDelaySeconds = 5;
                  periodSeconds = 10;
                };

                livenessProbe = {
                  httpGet = {
                    path = "/alive";
                    port = 80;
                  };
                  initialDelaySeconds = 30;
                  periodSeconds = 30;
                };
              }
            ];

            volumes = [
              {
                name = "data";
                persistentVolumeClaim.claimName = "vaultwarden-data";
              }
            ];
          };
        };
      };
    };
  };

  services.k3s.manifests.vaultwarden-service = {
    enable = true;
    content = {
      apiVersion = "v1";
      kind = "Service";
      metadata = {
        name = "vaultwarden";
        namespace = "vaultwarden";
      };
      spec = {
        selector.app = "vaultwarden";
        ports = [
          {
            port = 80;
            targetPort = 80;
          }
        ];
      };
    };
  };

  services.k3s.manifests.vaultwarden-ingress-route = {
    enable = true;
    content = {
      apiVersion = "traefik.io/v1alpha1";
      kind = "IngressRoute";
      metadata = {
        name = "vaultwarden";
        namespace = "vaultwarden";
      };
      spec = {
        entryPoints = ["websecure"];
        routes = [
          {
            match = "Host(`vaultwarden.brunhild.org`)";
            kind = "Rule";
            services = [
              {
                name = "vaultwarden";
                port = 80;
              }
            ];
          }
          {
            match = "Host(`vaultwarden.brunhild.org`) && PathPrefix(`/admin`)";
            kind = "Rule";
            middlewares = [
              {
                name = "authelia";
                namespace = "traefik-system";
              }
            ];
            services = [
              {
                name = "vaultwarden";
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
