{config, ...}: let
  inherit (config.age) secrets;
in {
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
      };

      persistence = {
        enabled = true;
        storageClass = "local-path";
      };

      configMap = {
        theme = "dark";

        authentication_backend.file = {
          enabled = true;
          path = "/secrets/authelia-users/users_database.yml";
          watch = true;
        };

        session = {
          name = "authelia_session";
          expiration = "8h";
          inactivity = "1h";
          cookies = [
            {
              subdomain = "auth";
              domain = "brunhild.org";
              default_redirection_url = "https://brunhild.org";
            }
          ];
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

        definitions.user_attributes.dozzle_roles.expression = ''"admin" in groups ? ["all"] : []'';

        identity_providers.oidc = {
          enabled = true;

          authorization_policies.dozzle = {
            default_policy = "deny";
            rules = [
              {
                policy = "one_factor";
                subject = "group:admin";
              }
            ];
          };

          claims_policies.dozzle = {
            id_token = ["dozzle_roles"];
            custom_claims.dozzle_roles = {};
          };

          scopes.dozzle_roles.claims = ["dozzle_roles"];

          jwks = [
            {
              key_id = "main";
              algorithm = "RS256";
              use = "sig";
              key.path = "/secrets/authelia-oidc-jwk/oidc.jwk.RS256.pem";
            }
          ];

          clients = [
            {
              client_id = "dozzle";
              client_secret = "$argon2id$v=19$m=65536,t=3,p=4$MOoGvHEx89qVCOUfYlLeLA$ZGa28vudD6yYEZ2jFv0wGEziQZBWZeQjOZzbIe0qwUI";

              client_name = "Dozzle";
              claims_policy = "dozzle";
              public = false;
              authorization_policy = "dozzle";

              redirect_uris = [
                "https://dozzle.brunhild.org/api/auth/callback"
              ];

              scopes = [
                "openid"
                "profile"
                "email"
                "dozzle_roles"
              ];

              token_endpoint_auth_method = "client_secret_basic";
              userinfo_signed_response_alg = "none";
            }
          ];
        };
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
}
