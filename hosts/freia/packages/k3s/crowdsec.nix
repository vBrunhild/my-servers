{config, ...}: let
  inherit (config) kubectl;
  inherit (config.age) secrets;
in {
  kubectl.secrets.crowdsec-bouncer-key = {
    namespace = "crowdsec";
    key = "api-key";
    file = secrets.crowdsec-bouncer-key.path;
  };

  kubectl.secrets.crowdsec-bouncer-key-traefik = {
    name = "crowdsec-bouncer-key";
    namespace = "traefik-system";
    key = "api-key";
    file = secrets.crowdsec-bouncer-key.path;
  };

  services.k3s.autoDeployCharts.crowdsec = {
    name = "crowdsec";
    repo = "https://crowdsecurity.github.io/helm-charts";
    version = "0.24.2";
    hash = "sha256-s97Skcl5Nz/9MozcQwK3H7FPFm/+SzOTU98ojUFHSVk=";
    createNamespace = true;
    targetNamespace = "crowdsec";

    values = {
      container_runtime = "containerd";

      config.parsers.s02-enrich."whitelist-self.yaml" = builtins.toJSON {
        name = "local/whitelist-self";
        description = "Never ban the server's own public IP";
        whitelist = {
          reason = "freia public IP";
          ip = ["161.97.80.162"];
        };
      };

      lapi = {
        resources = {
          requests = {
            cpu = "50m";
            memory = "128Mi";
          };
          limits.memory = "384Mi";
        };

        persistentVolume = {
          data.storageClassName = "local-path";
          config.storageClassName = "local-path";
        };

        env = [
          {
            name = "BOUNCER_KEY_traefik";
            valueFrom = kubectl.secrets.crowdsec-bouncer-key.valueFrom;
          }
        ];
      };

      agent = {
        resources = {
          requests = {
            cpu = "50m";
            memory = "128Mi";
          };
          limits.memory = "256Mi";
        };

        acquisition = [
          {
            namespace = "traefik-system";
            podName = "traefik-proxy-*";
            program = "traefik";
            poll_without_inotify = true;
          }
          {
            namespace = "authelia";
            podName = "authelia-*";
            program = "authelia";
            poll_without_inotify = true;
          }
        ];

        env = [
          {
            name = "COLLECTIONS";
            value = "crowdsecurity/traefik LePresidente/authelia";
          }
        ];
      };
    };
  };

  services.k3s.manifests.crowdsec-bouncer-middleware = {
    enable = true;
    content = {
      apiVersion = "traefik.io/v1alpha1";
      kind = "Middleware";
      metadata = {
        name = "crowdsec-bouncer";
        namespace = "traefik-system";
      };
      spec.plugin.crowdsec-bouncer = {
        enabled = true;
        crowdsecMode = "stream";
        crowdsecLapiScheme = "http";
        crowdsecLapiHost = "crowdsec-service.crowdsec.svc.cluster.local:8080";
        crowdsecLapiKeyFile = "/etc/crowdsec-bouncer/api-key";
        updateMaxFailure = -1;
        streamStartupBlock = false;
      };
    };
  };
}
