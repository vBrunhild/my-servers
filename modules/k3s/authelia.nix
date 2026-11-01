{
  flake.modules.nixos.authelia = {config, ...}: let
    inherit (config.age) secrets;

    security = import ./_security.nix;
  in {
    homepage.apps.authelia = {
      title = "Account";
      url = "https://auth.brunhild.org/settings";
      icon = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/authelia.svg";
      groups = [];
    };

    kubectl.secrets.authelia-oidc-jwk = {
      namespace = "authelia";
      key = "oidc.jwk.RS256.pem";
      file = secrets.authelia-oidc-jwk.path;
    };

    kubectl.secrets.authelia-storage-key = {
      namespace = "authelia";
      key = "storage.encryption.key";
      file = secrets.authelia-storage-key.path;
    };

    kubectl.secrets.authelia-users = {
      namespace = "authelia";
      key = "users_database.yml";
      file = secrets.authelia-users.path;
    };

    services.k3s.autoDeployCharts.authelia = {
      name = "authelia";
      repo = "https://charts.authelia.com";
      version = "0.11.22";
      hash = "sha256-8uI/3Ezad2/pbwqmlZq5ySfGyP5n2Aam0/2tvF++RF0=";
      createNamespace = true;
      targetNamespace = "authelia";

      values = {
        ingress.enabled = false;

        secret.additionalSecrets = {
          authelia-oidc-jwk = {};
          authelia-storage-key = {};
          authelia-users = {};
        };

        pod = {
          annotations = security.ignoreReadOnlyRootFs;
          kind = "Deployment";
          replicas = 1;
          strategy.type = "Recreate";
          resources = {
            requests = {
              cpu = "50m";
              memory = "64Mi";
            };
            limits.memory = "512Mi";
          };

          securityContext = {
            inherit (security) container pod;
          };
        };

        persistence = {
          enabled = true;
          storageClass = "local-path";
        };

        configMap = {
          theme = "dark";

          server.endpoints.authz.forward-auth = {
            implementation = "ForwardAuth";
            authn_strategies = [
              {
                name = "HeaderAuthorization";
                schemes = ["Basic"];
              }
              {name = "CookieSession";}
            ];
          };

          authentication_backend.file = {
            enabled = true;
            watch = true;
            path = "/secrets/authelia-users/users_database.yml";
          };

          session = {
            name = "authelia_session";
            expiration = "8h";
            inactivity = "1h";
            cookies = [
              {
                subdomain = "auth";
                domain = "brunhild.org";
                default_redirection_url = "https://home.brunhild.org";
              }
            ];
            redis = {
              enabled = true;
              host = "authelia-redis.authelia.svc.cluster.local";
              password.disabled = true;
            };
          };

          storage = {
            local.enabled = true;
            encryption_key.secret_name = "authelia-storage-key";
          };

          notifier.filesystem = {
            enabled = true;
            filename = "/tmp/notification.txt";
          };

          access_control = {
            default_policy = "deny";
            rules = [
              {
                domain = "home.brunhild.org";
                policy = "one_factor";
              }
              {
                domain = "foundryvtt.brunhild.org";
                subject = ["group:admin" "group:foundryvtt"];
                policy = "one_factor";
              }
              {
                domain = "*.brunhild.org";
                subject = "group:admin";
                policy = "one_factor";
              }
            ];
          };
        };
      };
    };

    services.k3s.manifests.authelia-namespace = {
      enable = true;
      content = {
        apiVersion = "v1";
        kind = "Namespace";
        metadata = {
          name = "authelia";
          labels = security.namespaceLabels;
        };
      };
    };

    services.k3s.manifests.authelia-default-service-account = {
      enable = true;
      content = {
        apiVersion = "v1";
        kind = "ServiceAccount";
        metadata = {
          name = "default";
          namespace = "authelia";
        };
        automountServiceAccountToken = false;
      };
    };

    services.k3s.manifests.authelia-redis-pvc = {
      enable = true;
      content = {
        apiVersion = "v1";
        kind = "PersistentVolumeClaim";
        metadata = {
          name = "authelia-redis-data";
          namespace = "authelia";
        };
        spec = {
          accessModes = ["ReadWriteOnce"];
          storageClassName = "local-path";
          resources.requests.storage = "100Mi";
        };
      };
    };

    services.k3s.manifests.authelia-redis-deployment = {
      enable = true;
      content = {
        apiVersion = "apps/v1";
        kind = "Deployment";
        metadata = {
          name = "authelia-redis";
          namespace = "authelia";
        };
        spec = {
          replicas = 1;
          strategy.type = "Recreate";
          selector.matchLabels.app = "authelia-redis";
          template = {
            metadata.labels.app = "authelia-redis";
            spec = {
              automountServiceAccountToken = false;
              securityContext = security.pod;

              containers = [
                {
                  name = "redis";
                  image = "redis:7.4.11-bookworm";
                  args = ["--save" "60 1"];
                  ports = [{containerPort = 6379;}];

                  securityContext =
                    security.container
                    // security.nonRoot 999
                    // {readOnlyRootFilesystem = true;};

                  resources = {
                    requests = {
                      cpu = "10m";
                      memory = "16Mi";
                    };
                    limits.memory = "128Mi";
                  };

                  volumeMounts = [
                    {
                      name = "data";
                      mountPath = "/data";
                    }
                  ];

                  readinessProbe = {
                    exec.command = ["redis-cli" "ping"];
                    initialDelaySeconds = 5;
                    periodSeconds = 10;
                  };

                  livenessProbe = {
                    exec.command = ["redis-cli" "ping"];
                    initialDelaySeconds = 15;
                    periodSeconds = 30;
                    timeoutSeconds = 5;
                  };
                }
              ];

              volumes = [
                {
                  name = "data";
                  persistentVolumeClaim.claimName = "authelia-redis-data";
                }
              ];
            };
          };
        };
      };
    };

    services.k3s.manifests.authelia-redis-service = {
      enable = true;
      content = {
        apiVersion = "v1";
        kind = "Service";
        metadata = {
          name = "authelia-redis";
          namespace = "authelia";
        };
        spec = {
          selector.app = "authelia-redis";
          ports = [{port = 6379;}];
        };
      };
    };

    services.k3s.manifests.authelia-redis-network-policy = {
      enable = true;
      content = {
        apiVersion = "networking.k8s.io/v1";
        kind = "NetworkPolicy";
        metadata = {
          name = "authelia-redis";
          namespace = "authelia";
        };
        spec = {
          podSelector.matchLabels.app = "authelia-redis";
          policyTypes = ["Ingress"];
          ingress = [
            {
              from = [{podSelector.matchLabels."app.kubernetes.io/name" = "authelia";}];
              ports = [{port = 6379;}];
            }
          ];
        };
      };
    };

    services.k3s.manifests.authelia-ingress-route = {
      enable = true;
      content = {
        apiVersion = "traefik.io/v1alpha1";
        kind = "IngressRoute";
        metadata = {
          name = "authelia";
          namespace = "authelia";
        };
        spec = {
          entryPoints = ["websecure"];
          routes = [
            {
              match = "Host(`auth.brunhild.org`)";
              kind = "Rule";
              services = [
                {
                  name = "authelia";
                  port = 80;
                }
              ];
            }
          ];
          tls = {
            certResolver = "cloudflare";
          };
        };
      };
    };

    services.k3s.manifests.authelia-middleware = {
      enable = true;
      content = {
        apiVersion = "traefik.io/v1alpha1";
        kind = "Middleware";
        metadata = {
          name = "authelia";
          namespace = "traefik-system";
          labels = {
            "app.kubernetes.io/instance" = "authelia";
            "app.kubernetes.io/name" = "authelia";
          };
        };
        spec.forwardAuth = {
          address = "http://authelia.authelia.svc.cluster.local/api/authz/forward-auth";
          trustForwardHeader = true;
          maxResponseBodySize = 8192;
          authResponseHeaders = [
            "Remote-User"
            "Remote-Groups"
            "Remote-Email"
            "Remote-Name"
          ];
        };
      };
    };
  };
}
