{config, ...}: let
  inherit (config) kubectl;
  secrets = config.age.secrets;
in {
  kubectl.secrets.foundry-admin-key = {
    namespace = "foundryvtt";
    file = secrets.foundry-admin-key.path;
  };

  kubectl.secrets.foundry-license-key = {
    namespace = "foundryvtt";
    file = secrets.foundry-license-key.path;
  };

  kubectl.secrets.foundry-password = {
    namespace = "foundryvtt";
    file = secrets.foundry-password.path;
  };

  kubectl.secrets.foundry-username = {
    namespace = "foundryvtt";
    file = secrets.foundry-username.path;
  };

  systemd.tmpfiles.settings."foundryvtt" = {
    "/var/lib/foundryvtt".d = {
      mode = "0755";
      user = "1000";
      group = "1000";
    };
  };

  services.k3s.manifests.foundryvtt-namespace = {
    enable = true;
    content = {
      apiVersion = "v1";
      kind = "Namespace";
      metadata.name = "foundryvtt";
    };
  };

  services.k3s.manifests.foundryvtt-pv = {
    enable = true;
    content = {
      apiVersion = "v1";
      kind = "PersistentVolume";
      metadata = {
        name = "foundryvtt-data";
      };
      spec = {
        capacity.storage = "50Gi";
        accessModes = ["ReadWriteOnce"];
        persistentVolumeReclaimPolicy = "Retain";
        hostPath.path = "/var/lib/foundryvtt";
        storageClassName = "local-path";
      };
    };
  };

  services.k3s.manifests.foundryvtt-pvc = {
    enable = true;
    content = {
      apiVersion = "v1";
      kind = "PersistentVolumeClaim";
      metadata = {
        name = "foundryvtt-data";
        namespace = "foundryvtt";
      };
      spec = {
        accessModes = ["ReadWriteOnce"];
        storageClassName = "local-path";
        resources.requests.storage = "50Gi";
      };
    };
  };

  services.k3s.manifests.foundryvtt-deployment = {
    enable = true;
    content = {
      apiVersion = "apps/v1";
      kind = "Deployment";
      metadata = {
        name = "foundryvtt";
        namespace = "foundryvtt";
      };
      spec = {
        replicas = 1;
        selector.matchLabels.app = "foundryvtt";
        template = {
          metadata.labels.app = "foundryvtt";
          spec = {
            securityContext = {
              runAsUser = 1000;
              runAsGroup = 1000;
              fsGroup = 1000;
            };

            containers = [
              {
                name = "foundryvtt";
                image = "felddy/foundryvtt:13.351";
                ports = [{containerPort = 30000;}];

                resources = {
                  requests = {
                    cpu = "250m";
                    memory = "512Mi";
                  };
                  limits.memory = "4Gi";
                };

                env = [
                  {
                    name = "FOUNDRY_USERNAME";
                    valueFrom = kubectl.secrets.foundry-username.valueFrom;
                  }
                  {
                    name = "FOUNDRY_PASSWORD";
                    valueFrom = kubectl.secrets.foundry-password.valueFrom;
                  }
                  {
                    name = "FOUNDRY_ADMIN_KEY";
                    valueFrom = kubectl.secrets.foundry-admin-key.valueFrom;
                  }
                  {
                    name = "FOUNDRY_LICENSE_KEY";
                    valueFrom = kubectl.secrets.foundry-license-key.valueFrom;
                  }
                  {
                    name = "FOUNDRY_HOSTNAME";
                    value = "foundry.brunhild.org";
                  }
                  {
                    name = "FOUNDRY_PROXY_SSL";
                    value = "true";
                  }
                  {
                    name = "FOUNDRY_PROXY_PORT";
                    value = "443";
                  }
                  {
                    name = "FOUNDRY_TELEMETRY";
                    value = "false";
                  }
                ];

                volumeMounts = [
                  {
                    name = "data";
                    mountPath = "/data";
                  }
                ];

                startupProbe = {
                  httpGet = {
                    path = "/";
                    port = 30000;
                  };
                  failureThreshold = 30;
                  periodSeconds = 10;
                };

                readinessProbe = {
                  httpGet = {
                    path = "/";
                    port = 30000;
                  };
                  initialDelaySeconds = 10;
                  periodSeconds = 10;
                };
              }
            ];

            volumes = [
              {
                name = "data";
                persistentVolumeClaim.claimName = "foundryvtt-data";
              }
            ];
          };
        };
      };
    };
  };

  services.k3s.manifests.foundryvtt-service = {
    enable = true;
    content = {
      apiVersion = "v1";
      kind = "Service";
      metadata = {
        name = "foundryvtt";
        namespace = "foundryvtt";
      };
      spec = {
        selector.app = "foundryvtt";
        ports = [
          {
            port = 80;
            targetPort = 30000;
          }
        ];
      };
    };
  };

  services.k3s.manifests.foundryvtt-ingress-route = {
    enable = true;
    content = {
      apiVersion = "traefik.io/v1alpha1";
      kind = "IngressRoute";
      metadata = {
        name = "foundryvtt";
        namespace = "foundryvtt";
      };
      spec = {
        entryPoints = ["websecure"];
        routes = [
          {
            match = "Host(`foundryvtt.brunhild.org`)";
            kind = "Rule";
            middlewares = [
              {
                name = "authelia";
                namespace = "traefik-system";
              }
            ];
            services = [
              {
                name = "foundryvtt";
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
