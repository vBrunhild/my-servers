{inputs, ...}: {
  flake.modules.nixos.foundry-vtt = {
    config,
    pkgs,
    ...
  }: let
    inherit (config) kubectl;
    secrets = config.age.secrets;

    namespace = "foundryvtt";

    security = import ./_security.nix;

    proxyImage = inputs.foundry-auth-proxy.packages.${pkgs.stdenv.hostPlatform.system}.image;

    proxyConfig = {
      foundryURL = "http://127.0.0.1:30000";
      listen = ":8080";
      userHeader = "Remote-User";
      onUnmapped = "fallthrough";
      trustedProxies = ["10.42.0.0/16"];
      usersFile = "/secrets/users/value";
    };
  in {
    homepage.apps.foundryvtt = {
      title = "Foundry VTT";
      url = "https://foundryvtt.brunhild.org";
      icon = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/foundry-vtt.png";
      groups = ["admin" "foundryvtt"];
    };

    services.k3s.images = [proxyImage];

    kubectl.secrets = {
      foundry-admin-key = {
        inherit namespace;
        file = secrets.foundry-admin-key.path;
      };

      foundry-license-key = {
        inherit namespace;
        file = secrets.foundry-license-key.path;
      };

      foundry-password = {
        inherit namespace;
        file = secrets.foundry-password.path;
      };

      foundry-username = {
        inherit namespace;
        file = secrets.foundry-username.path;
      };

      foundry-auth-proxy-users = {
        inherit namespace;
        file = secrets.foundry-auth-proxy-users.path;
      };
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
        metadata = {
          name = "foundryvtt";
          labels = security.namespaceLabels;
        };
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
          strategy = {
            type = "Recreate";
            rollingUpdate = null;
          };
          selector.matchLabels.app = "foundryvtt";
          template = {
            metadata = {
              labels.app = "foundryvtt";
              annotations = {
                "checksum/auth-proxy-config" = builtins.hashString "sha256" (builtins.toJSON proxyConfig);
                "checksum/auth-proxy-image" = builtins.baseNameOf proxyImage;
              };
            };
            spec = {
              automountServiceAccountToken = false;
              securityContext =
                security.pod
                // {
                  runAsUser = 1000;
                  runAsGroup = 1000;
                  fsGroup = 1000;
                };

              containers = [
                {
                  name = "foundryvtt";
                  image = "felddy/foundryvtt:13.351";
                  ports = [{containerPort = 30000;}];

                  securityContext = security.container // {runAsNonRoot = true;};

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
                      value = "foundryvtt.brunhild.org";
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
                      path = "/api/status";
                      port = 30000;
                    };
                    failureThreshold = 30;
                    periodSeconds = 10;
                  };

                  readinessProbe = {
                    httpGet = {
                      path = "/api/status";
                      port = 30000;
                    };
                    initialDelaySeconds = 10;
                    periodSeconds = 10;
                  };

                  livenessProbe = {
                    httpGet = {
                      path = "/api/status";
                      port = 30000;
                    };
                    periodSeconds = 30;
                    timeoutSeconds = 5;
                  };
                }
                {
                  name = "auth-proxy";
                  image = "${proxyImage.imageName}:${proxyImage.imageTag}";
                  imagePullPolicy = "Never";
                  ports = [{containerPort = 8080;}];

                  resources = {
                    requests = {
                      cpu = "10m";
                      memory = "8Mi";
                    };
                    limits.memory = "64Mi";
                  };

                  securityContext =
                    security.container
                    // {
                      runAsNonRoot = true;
                      readOnlyRootFilesystem = true;
                    };

                  volumeMounts = [
                    {
                      name = "auth-proxy-config";
                      mountPath = "/etc/foundry-auth-proxy";
                      readOnly = true;
                    }
                    {
                      name = "auth-proxy-users";
                      mountPath = "/secrets/users";
                      readOnly = true;
                    }
                  ];

                  readinessProbe = {
                    httpGet = {
                      path = "/api/status";
                      port = 8080;
                    };
                    initialDelaySeconds = 10;
                    periodSeconds = 10;
                  };

                  livenessProbe = {
                    tcpSocket.port = 8080;
                    initialDelaySeconds = 10;
                    periodSeconds = 30;
                  };
                }
              ];

              volumes = [
                {
                  name = "data";
                  persistentVolumeClaim.claimName = "foundryvtt-data";
                }
                {
                  name = "auth-proxy-config";
                  configMap.name = "foundryvtt-auth-proxy";
                }
                {
                  name = "auth-proxy-users";
                  secret.secretName = "foundry-auth-proxy-users";
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
              targetPort = 8080;
            }
          ];
        };
      };
    };

    services.k3s.manifests.foundryvtt-auth-proxy-config = {
      enable = true;
      content = {
        apiVersion = "v1";
        kind = "ConfigMap";
        metadata = {
          name = "foundryvtt-auth-proxy";
          inherit namespace;
        };
        data."config.json" = builtins.toJSON proxyConfig;
      };
    };

    services.k3s.manifests.foundryvtt-network-policy = {
      enable = true;
      content = {
        apiVersion = "networking.k8s.io/v1";
        kind = "NetworkPolicy";
        metadata = {
          name = "foundryvtt";
          inherit namespace;
        };
        spec = {
          podSelector.matchLabels.app = "foundryvtt";
          policyTypes = ["Ingress"];
          ingress = [
            {
              from = [
                {namespaceSelector.matchLabels."kubernetes.io/metadata.name" = "traefik-system";}
                {namespaceSelector.matchLabels."kubernetes.io/metadata.name" = "gatus";}
              ];
              ports = [{port = 8080;}];
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
  };
}
