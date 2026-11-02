{
  flake.modules.nixos.vaultwarden = {config, ...}: let
    inherit (config) kubectl;
    secrets = config.age.secrets;

    security = import ./_security.nix;
  in {
    homepage.apps.vaultwarden = {
      title = "Vaultwarden";
      url = "https://vaultwarden.brunhild.org";
      icon = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/vaultwarden.svg";
    };

    kubectl.secrets.vaultwarden-admin-token = {
      namespace = "vaultwarden";
      file = secrets.vaultwarden-admin-token.path;
    };

    services.k3s.manifests.vaultwarden-namespace = {
      enable = true;
      content = {
        apiVersion = "v1";
        kind = "Namespace";
        metadata = {
          name = "vaultwarden";
          labels = security.namespaceLabels;
        };
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
          annotations = security.ignoreChecks ["readOnlyRootFs" "runAsRoot"];
        };
        spec = {
          replicas = 1;
          strategy.type = "Recreate";
          selector.matchLabels.app = "vaultwarden";
          template = {
            metadata.labels.app = "vaultwarden";
            spec = {
              automountServiceAccountToken = false;
              securityContext = security.pod;

              containers = [
                {
                  name = "vaultwarden";
                  image = "vaultwarden/server:1.37.5";
                  ports = [{containerPort = 80;}];

                  securityContext =
                    security.container
                    // {capabilities = security.container.capabilities // {add = ["NET_BIND_SERVICE"];};};

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
  };
}
