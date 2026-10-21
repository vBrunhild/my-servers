{config, ...}: let
  inherit (config) kubectl;
  inherit (config.age) secrets;
in {
  kubectl.secrets.dozzle-oidc = {
    namespace = "dozzle";
    file = secrets.dozzle-oidc.path;
  };

  services.k3s.manifests.dozzle-namespace = {
    enable = true;
    content = {
      apiVersion = "v1";
      kind = "Namespace";
      metadata.name = "dozzle";
    };
  };

  services.k3s.manifests.dozzle-service-account = {
    enable = true;
    content = {
      apiVersion = "v1";
      kind = "ServiceAccount";
      metadata = {
        name = "dozzle";
        namespace = "dozzle";
      };
    };
  };

  services.k3s.manifests.dozzle-cluster-role = {
    enable = true;
    content = {
      apiVersion = "rbac.authorization.k8s.io/v1";
      kind = "ClusterRole";
      metadata.name = "dozzle";
      rules = [
        {
          apiGroups = [""];
          resources = ["pods" "pods/log" "nodes"];
          verbs = ["get" "list" "watch"];
        }
        {
          apiGroups = ["apps"];
          resources = ["deployments" "replicasets" "daemonsets" "statefulsets"];
          verbs = ["get"];
        }
        {
          apiGroups = ["batch"];
          resources = ["jobs" "cronjobs"];
          verbs = ["get"];
        }
        {
          apiGroups = ["metrics.k8s.io"];
          resources = ["pods"];
          verbs = ["get" "list"];
        }
      ];
    };
  };

  services.k3s.manifests.dozzle-cluster-role-binding = {
    enable = true;
    content = {
      apiVersion = "rbac.authorization.k8s.io/v1";
      kind = "ClusterRoleBinding";
      metadata.name = "dozzle";
      roleRef = {
        apiGroup = "rbac.authorization.k8s.io";
        kind = "ClusterRole";
        name = "dozzle";
      };
      subjects = [
        {
          kind = "ServiceAccount";
          name = "dozzle";
          namespace = "dozzle";
        }
      ];
    };
  };

  services.k3s.manifests.dozzle-pvc = {
    enable = true;
    content = {
      apiVersion = "v1";
      kind = "PersistentVolumeClaim";
      metadata = {
        name = "dozzle-data";
        namespace = "dozzle";
      };
      spec = {
        accessModes = ["ReadWriteOnce"];
        storageClassName = "local-path";
        resources.requests.storage = "1Gi";
      };
    };
  };

  services.k3s.manifests.dozzle-deployment = {
    enable = true;
    content = {
      apiVersion = "apps/v1";
      kind = "Deployment";
      metadata = {
        name = "dozzle";
        namespace = "dozzle";
      };
      spec = {
        replicas = 1;
        strategy.type = "Recreate";
        selector.matchLabels.app = "dozzle";
        template = {
          metadata.labels.app = "dozzle";
          spec = {
            serviceAccountName = "dozzle";

            containers = [
              {
                name = "dozzle";
                image = "amir20/dozzle:v11.3.4";
                ports = [{containerPort = 8080;}];

                resources = {
                  requests = {
                    cpu = "10m";
                    memory = "32Mi";
                  };
                  limits.memory = "256Mi";
                };

                env = [
                  {
                    name = "DOZZLE_MODE";
                    value = "k8s";
                  }
                  {
                    name = "DOZZLE_AUTH_PROVIDER";
                    value = "oidc";
                  }
                  {
                    name = "DOZZLE_AUTH_OIDC_ISSUER";
                    value = "https://auth.brunhild.org";
                  }
                  {
                    name = "DOZZLE_AUTH_OIDC_CLIENT_ID";
                    value = "dozzle";
                  }
                  {
                    name = "DOZZLE_AUTH_OIDC_CLIENT_SECRET";
                    valueFrom = kubectl.secrets.dozzle-oidc.valueFrom;
                  }
                  {
                    name = "DOZZLE_AUTH_OIDC_NAME";
                    value = "Authelia";
                  }
                  {
                    name = "DOZZLE_AUTH_OIDC_SCOPES";
                    value = "dozzle_roles";
                  }
                  {
                    name = "DOZZLE_AUTH_LOGOUT_URL";
                    value = "https://auth.brunhild.org/logout";
                  }
                  {
                    name = "DOZZLE_ENABLE_MCP";
                    value = "true";
                  }
                  {
                    name = "DOZZLE_NO_ANALYTICS";
                    value = "true";
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
                    path = "/healthcheck";
                    port = 8080;
                  };
                  initialDelaySeconds = 5;
                  periodSeconds = 10;
                };
              }
            ];

            volumes = [
              {
                name = "data";
                persistentVolumeClaim.claimName = "dozzle-data";
              }
            ];
          };
        };
      };
    };
  };

  services.k3s.manifests.dozzle-service = {
    enable = true;
    content = {
      apiVersion = "v1";
      kind = "Service";
      metadata = {
        name = "dozzle";
        namespace = "dozzle";
      };
      spec = {
        selector.app = "dozzle";
        ports = [
          {
            port = 80;
            targetPort = 8080;
          }
        ];
      };
    };
  };

  services.k3s.manifests.dozzle-ingress-route = {
    enable = true;
    content = {
      apiVersion = "traefik.io/v1alpha1";
      kind = "IngressRoute";
      metadata = {
        name = "dozzle";
        namespace = "dozzle";
      };
      spec = {
        entryPoints = ["websecure"];
        routes = [
          {
            match = "Host(`dozzle.brunhild.org`)";
            kind = "Rule";
            services = [
              {
                name = "dozzle";
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
