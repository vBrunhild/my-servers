{config, ...}: let
  inherit (config.age) secrets;
in {
  kubectl.secrets.headlamp-oidc = {
    namespace = "headlamp";
    key = "OIDC_CLIENT_SECRET";
    file = secrets.headlamp-oidc.path;
    literals = {
      OIDC_CLIENT_ID = "headlamp";
      OIDC_ISSUER_URL = "https://auth.brunhild.org";
      OIDC_SCOPES = "openid,profile,email,groups";
      OIDC_USE_PKCE = "true";
    };
  };

  services.k3s.autoDeployCharts.headlamp = {
    name = "headlamp";
    repo = "https://kubernetes-sigs.github.io/headlamp/";
    version = "0.42.0";
    hash = "sha256-EBS8lsdpYABkXSm7cDNthj2VGysTBoMiDbGXNDi3bEA=";
    createNamespace = true;
    targetNamespace = "headlamp";

    values = {
      ingress.enabled = false;

      resources = {
        requests = {
          cpu = "25m";
          memory = "32Mi";
        };
        limits.memory = "256Mi";
      };

      config.oidc = {
        usePKCE = true;
        secret.create = false;
        externalSecret = {
          enabled = true;
          name = "headlamp-oidc";
        };
      };
    };
  };

  services.k3s.manifests.headlamp-oidc-admin = {
    enable = true;
    content = {
      apiVersion = "rbac.authorization.k8s.io/v1";
      kind = "ClusterRoleBinding";
      metadata.name = "oidc-admin";
      roleRef = {
        apiGroup = "rbac.authorization.k8s.io";
        kind = "ClusterRole";
        name = "cluster-admin";
      };
      subjects = [
        {
          apiGroup = "rbac.authorization.k8s.io";
          kind = "Group";
          name = "oidc:admin";
        }
      ];
    };
  };

  services.k3s.manifests.headlamp-ingress-route = {
    enable = true;
    content = {
      apiVersion = "traefik.io/v1alpha1";
      kind = "IngressRoute";
      metadata = {
        name = "headlamp";
        namespace = "headlamp";
      };
      spec = {
        entryPoints = ["websecure"];
        routes = [
          {
            match = "Host(`headlamp.brunhild.org`)";
            kind = "Rule";
            services = [
              {
                name = "headlamp";
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
}
