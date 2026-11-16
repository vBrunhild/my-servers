{
  flake.modules.nixos.victoria-metrics = let
    security = import ./_security.nix;

    namespace = "monitoring";
    uid = 65534;

    kubeletJob = {
      scheme = "https";
      tls_config = {
        ca_file = "/var/run/secrets/kubernetes.io/serviceaccount/ca.crt";
        insecure_skip_verify = true;
      };
      bearer_token_file = "/var/run/secrets/kubernetes.io/serviceaccount/token";
      kubernetes_sd_configs = [{role = "node";}];
    };
  in {
    homepage.apps.victoria-metrics = {
      title = "Metrics";
      url = "https://metrics.brunhild.org/vmui";
      icon = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/victoriametrics.png";
      groups = ["admin"];
    };

    services.k3s.manifests.monitoring-namespace = {
      enable = true;
      content = {
        apiVersion = "v1";
        kind = "Namespace";
        metadata = {
          name = namespace;
          labels = security.namespaceLabels;
        };
      };
    };

    services.k3s.autoDeployCharts.victoria-metrics = {
      name = "victoria-metrics-single";
      repo = "https://victoriametrics.github.io/helm-charts";
      version = "0.51.0";
      hash = "sha256-I5ku3I6oFUi5jWqsuUxKY+XyuggdTEpUlXIssMu+Lig=";
      createNamespace = true;
      targetNamespace = namespace;

      values = {
        server = {
          fullnameOverride = "victoria-metrics";
          retentionPeriod = "7d";
          annotations = security.ignoreChecks ["automountServiceAccountToken"];

          extraArgs = {
            "storage.minFreeDiskSpaceBytes" = "1GB";
          };

          persistentVolume = {
            storageClassName = "local-path";
            size = "2Gi";
          };

          resources = {
            requests = {
              cpu = "50m";
              memory = "128Mi";
            };
            limits.memory = "512Mi";
          };

          podSecurityContext =
            {enabled = true;}
            // security.pod
            // {fsGroup = uid;};

          securityContext =
            {enabled = true;}
            // security.container
            // security.nonRoot uid
            // {readOnlyRootFilesystem = true;};

          scrape = {
            enabled = true;
            config = {
              global.scrape_interval = "60s";
              scrape_configs = [
                {
                  job_name = "victoriametrics";
                  static_configs = [{targets = ["localhost:8428"];}];
                }
                {
                  job_name = "kube-state-metrics";
                  static_configs = [{targets = ["kube-state-metrics.${namespace}.svc:8080"];}];
                }
                (kubeletJob
                  // {
                    job_name = "kubernetes-nodes-cadvisor";
                    metrics_path = "/metrics/cadvisor";
                    honor_timestamps = false;
                    relabel_configs = [
                      {
                        action = "labelmap";
                        regex = "__meta_kubernetes_node_label_(.+)";
                      }
                    ];
                    metric_relabel_configs = [
                      {
                        source_labels = ["__name__"];
                        action = "drop";
                        regex = "container_(blkio_.*|tasks_state|file_descriptors|sockets|threads.*|ulimits_soft|memory_failures_total|network_.*_(errors|dropped)_total)";
                      }
                    ];
                  })
              ];
            };
          };
        };
      };
    };

    services.k3s.manifests.victoria-metrics-ingress-route = {
      enable = true;
      content = {
        apiVersion = "traefik.io/v1alpha1";
        kind = "IngressRoute";
        metadata = {
          name = "victoria-metrics";
          inherit namespace;
        };
        spec = {
          entryPoints = ["websecure"];
          routes = [
            {
              match = "Host(`metrics.brunhild.org`)";
              kind = "Rule";
              middlewares = [
                {
                  name = "authelia";
                  namespace = "traefik-system";
                }
              ];
              services = [
                {
                  name = "victoria-metrics";
                  port = 8428;
                }
              ];
            }
          ];
          tls.certResolver = "cloudflare";
        };
      };
    };

    services.k3s.autoDeployCharts.kube-state-metrics = {
      name = "kube-state-metrics";
      repo = "https://prometheus-community.github.io/helm-charts";
      version = "8.8.0";
      hash = "sha256-G3QtiZ0tX3fT7xIvFKhVktyKt2wTwVuxGzxxnx3p/ys=";
      createNamespace = true;
      targetNamespace = namespace;

      values = {
        fullnameOverride = "kube-state-metrics";
        annotations = security.ignoreChecks ["automountServiceAccountToken"];

        collectors = ["daemonsets" "deployments" "jobs" "nodes" "pods" "replicasets" "statefulsets"];

        resources = {
          requests = {
            cpu = "10m";
            memory = "32Mi";
          };
          limits.memory = "128Mi";
        };
      };
    };
  };
}
