{
  services.k3s.autoDeployCharts.authelia = {
    name = "authelia";
    repo = "https://charts.authelia.com";
    version = "0.11.5";
    hash = "sha256-OdSSeITp9p4de4oBJQyfKqScxJR1SmlyQUCCFzWmbso=";
    createNamespace = true;
    targetNamespace = "authelia";

    values = {
      ingress.enabled = false;

      pod = {
        replicas = 1;

        extraVolumes = [
          {
            name = "users";
            configMap.name = "authelia-users";
          }
        ];

        extraVolumeMounts = [
          {
            name = "users";
            mountPath = "/config/users_database.yml";
            subPath = "users_database.yml";
            readOnly = true;
          }
        ];
      };

      configMap = {
        theme = "dark";

        authentication_backend.file = {
          enabled = true;
          path = "/config/users_database.yml";
        };

        session = {
          name = "authelia_session";
          expiration = "1h";
          inactivity = "30m";
          cookies = [
            {
              subdomain = "auth";
              domain = "brunhild.org";
              default_redirection_url = "https://brunhild.org";
            }
          ];
        };

        storage.local.enabled = true;

        notifier.filesystem = {
          enabled = true;
          filename = "/tmp/notification.txt";
        };

        access_control = {
          default_policy = "deny";
          rules = [
            {
              domain = "*.brunhild.org";
              policy = "one_factor";
            }
          ];
        };
      };
    };
  };

  services.k3s.manifests.authelia-users = {
    enable = true;
    content = {
      apiVersion = "v1";
      kind = "ConfigMap";
      metadata = {
        name = "authelia-users";
        namespace = "authelia";
      };

      data."users_database.yml" =
        # yaml
        ''
          users:
            brunhild:
              displayname: brunhild
              password: $argon2id$v=19$m=65536,t=3,p=4$pHw4bsB9sMrDJPgUotruoQ$jxYvUkFv4Il/JYDCxy3WILj5CN5JML58Az5HrtBYEAQ
              email: brunomoretti100@gmail.com
              groups:
                - admin
        '';
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
}
