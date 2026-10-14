{config, ...}: let
  inherit (config) kubectl;
  inherit (config.age) secrets;

  namespace = "craig";
  downloadDomain = "craig.brunhild.org";
  applicationId = "1562613445302419576";

  rewardTiers = {
    "0" = {
      recordHours = 24;
      downloadExpiryHours = 720;
      features = ["mix" "auto" "glowers" "eccontinuous" "ecflac" "mp3"];
      sizeLimitMult = 5;
    };
  };

  env = name: value: {inherit name value;};
in {
  kubectl.secrets.craig-bot-token = {
    inherit namespace;
    file = secrets.craig-bot-token.path;
  };

  kubectl.secrets.craig-postgres-password = {
    inherit namespace;
    file = secrets.craig-postgres-password.path;
  };

  services.k3s.manifests.craig-namespace = {
    enable = true;
    content = {
      apiVersion = "v1";
      kind = "Namespace";
      metadata.name = namespace;
    };
  };

  services.k3s.manifests.craig-postgres-pvc = {
    enable = true;
    content = {
      apiVersion = "v1";
      kind = "PersistentVolumeClaim";
      metadata = {
        name = "craig-postgres-data";
        inherit namespace;
      };
      spec = {
        accessModes = ["ReadWriteOnce"];
        storageClassName = "local-path";
        resources.requests.storage = "1Gi";
      };
    };
  };

  services.k3s.manifests.craig-data-pvc = {
    enable = true;
    content = {
      apiVersion = "v1";
      kind = "PersistentVolumeClaim";
      metadata = {
        name = "craig-data";
        inherit namespace;
      };
      spec = {
        accessModes = ["ReadWriteOnce"];
        storageClassName = "local-path";
        resources.requests.storage = "20Gi";
      };
    };
  };

  services.k3s.manifests.craig-postgres-deployment = {
    enable = true;
    content = {
      apiVersion = "apps/v1";
      kind = "Deployment";
      metadata = {
        name = "craig-postgres";
        inherit namespace;
      };
      spec = {
        replicas = 1;
        strategy.type = "Recreate";
        selector.matchLabels.app = "craig-postgres";
        template = {
          metadata.labels.app = "craig-postgres";
          spec = {
            containers = [
              {
                name = "postgres";
                image = "postgres:17.11-bookworm";
                ports = [{containerPort = 5432;}];

                resources = {
                  requests = {
                    cpu = "50m";
                    memory = "64Mi";
                  };
                  limits.memory = "512Mi";
                };

                env = [
                  (env "POSTGRES_USER" "craig")
                  (env "POSTGRES_DB" "craig")
                  (env "PGDATA" "/var/lib/postgresql/data/pgdata")
                  {
                    name = "POSTGRES_PASSWORD";
                    valueFrom = kubectl.secrets.craig-postgres-password.valueFrom;
                  }
                ];

                volumeMounts = [
                  {
                    name = "data";
                    mountPath = "/var/lib/postgresql/data";
                  }
                ];

                readinessProbe = {
                  exec.command = ["pg_isready" "-U" "craig" "-d" "craig"];
                  initialDelaySeconds = 5;
                  periodSeconds = 10;
                };
              }
            ];

            volumes = [
              {
                name = "data";
                persistentVolumeClaim.claimName = "craig-postgres-data";
              }
            ];
          };
        };
      };
    };
  };

  services.k3s.manifests.craig-postgres-service = {
    enable = true;
    content = {
      apiVersion = "v1";
      kind = "Service";
      metadata = {
        name = "craig-postgres";
        inherit namespace;
      };
      spec = {
        selector.app = "craig-postgres";
        ports = [{port = 5432;}];
      };
    };
  };

  services.k3s.manifests.craig-redis-deployment = {
    enable = true;
    content = {
      apiVersion = "apps/v1";
      kind = "Deployment";
      metadata = {
        name = "craig-redis";
        inherit namespace;
      };
      spec = {
        replicas = 1;
        selector.matchLabels.app = "craig-redis";
        template = {
          metadata.labels.app = "craig-redis";
          spec.containers = [
            {
              name = "redis";
              image = "redis:7.4.11-bookworm";
              ports = [{containerPort = 6379;}];

              resources = {
                requests = {
                  cpu = "20m";
                  memory = "32Mi";
                };
                limits.memory = "256Mi";
              };

              readinessProbe = {
                exec.command = ["redis-cli" "ping"];
                initialDelaySeconds = 5;
                periodSeconds = 10;
              };
            }
          ];
        };
      };
    };
  };

  services.k3s.manifests.craig-redis-service = {
    enable = true;
    content = {
      apiVersion = "v1";
      kind = "Service";
      metadata = {
        name = "craig-redis";
        inherit namespace;
      };
      spec = {
        selector.app = "craig-redis";
        ports = [{port = 6379;}];
      };
    };
  };

  services.k3s.manifests.craig-deployment = {
    enable = true;
    content = {
      apiVersion = "apps/v1";
      kind = "Deployment";
      metadata = {
        name = "craig";
        inherit namespace;
      };
      spec = {
        replicas = 1;
        strategy.type = "Recreate";
        selector.matchLabels.app = "craig";
        template = {
          metadata.labels.app = "craig";
          spec = {
            enableServiceLinks = false;

            containers = [
              {
                name = "craig";
                image = "ghcr.io/craigchat/craig:master@sha256:a147abc377d94ac5ba0252f014633f9ca17418e2ee3a13a32da86230c73e3b1d";
                ports = [
                  {
                    name = "ferret";
                    containerPort = 9100;
                  }
                  {
                    name = "ennuizel";
                    containerPort = 9001;
                  }
                ];

                resources = {
                  requests = {
                    cpu = "100m";
                    memory = "512Mi";
                  };
                  limits.memory = "2Gi";
                };

                env = [
                  {
                    name = "POSTGRES_PASSWORD";
                    valueFrom = kubectl.secrets.craig-postgres-password.valueFrom;
                  }
                  (env "DATABASE_URL" "postgresql://craig:$(POSTGRES_PASSWORD)@craig-postgres:5432/craig?schema=public")
                  (env "REDIS_HOST" "craig-redis")
                  (env "REDIS_PORT" "6379")

                  {
                    name = "BOT_TOKEN";
                    valueFrom = kubectl.secrets.craig-bot-token.valueFrom;
                  }
                  (env "BOT_APPLICATION_ID" applicationId)
                  (env "PUBLIC_DISCORD_CLIENT_ID" applicationId)
                  (env "BOT_STATUS_TEXT" "Recording VCs")
                  (env "LOGGER_LEVEL" "info")

                  (env "DOWNLOAD_PROTOCOL" "https")
                  (env "DOWNLOAD_DOMAIN" downloadDomain)
                  (env "PUBLIC_HOSTNAME" downloadDomain)
                  (env "PUBLIC_ENNUIZEL_API_HOSTNAME" downloadDomain)
                  (env "WEBAPP_ENABLED" "false")

                  (env "REWARD_TIERS_JSON" (builtins.toJSON rewardTiers))
                  (env "TASKS_TIMEZONE" "America/Sao_Paulo")
                  (env "TASKS_IGNORE" "refreshPatrons")
                ];

                volumeMounts = [
                  {
                    name = "data";
                    mountPath = "/data";
                  }
                ];

                readinessProbe = {
                  httpGet = {
                    path = "/api/health";
                    port = 9100;
                  };
                  initialDelaySeconds = 20;
                  periodSeconds = 10;
                };

                livenessProbe = {
                  httpGet = {
                    path = "/api/health";
                    port = 9100;
                  };
                  initialDelaySeconds = 120;
                  periodSeconds = 30;
                };
              }
            ];

            volumes = [
              {
                name = "data";
                persistentVolumeClaim.claimName = "craig-data";
              }
            ];
          };
        };
      };
    };
  };

  services.k3s.manifests.craig-service = {
    enable = true;
    content = {
      apiVersion = "v1";
      kind = "Service";
      metadata = {
        name = "craig";
        inherit namespace;
      };
      spec = {
        selector.app = "craig";
        ports = [
          {
            name = "ferret";
            port = 9100;
            targetPort = 9100;
          }
          {
            name = "ennuizel";
            port = 9001;
            targetPort = 9001;
          }
        ];
      };
    };
  };

  services.k3s.manifests.craig-ingress-route = {
    enable = true;
    content = {
      apiVersion = "traefik.io/v1alpha1";
      kind = "IngressRoute";
      metadata = {
        name = "craig";
        inherit namespace;
      };
      spec = {
        entryPoints = ["websecure"];
        routes = [
          {
            match = "Host(`${downloadDomain}`)";
            kind = "Rule";
            services = [
              {
                name = "craig";
                port = 9100;
              }
            ];
          }
          {
            match = "Host(`${downloadDomain}`) && Path(`/api/ennuizel`)";
            kind = "Rule";
            services = [
              {
                name = "craig";
                port = 9001;
              }
            ];
          }
        ];
        tls.certResolver = "cloudflare";
      };
    };
  };
}
