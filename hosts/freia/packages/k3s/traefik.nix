{config, ...}: let
  inherit (config) kubectl;
  secrets = config.age.secrets;
in {
  kubectl.secrets.cloudflare-api-token = {
    namespace = "traefik-system";
    file = secrets.cloudflare-api-token.path;
  };

  services.k3s.autoDeployCharts.traefik-proxy = {
    name = "traefik";
    repo = "https://helm.traefik.io/traefik";
    version = "39.0.8";
    hash = "sha256-M24VAFGdhyf0QJFbqB2pnuMi+ud6GWcf5mEw/B6LcAA=";
    createNamespace = true;
    targetNamespace = "traefik-system";

    values = {
      providers.kubernetesCRD.allowCrossNamespace = true;

      deployment = {
        replicas = 1;
      };

      ports = {
        web.http.redirections.entryPoint = {
          to = "websecure";
          scheme = "https";
          permanent = true;
        };
      };

      additionalArguments = [
        "--certificatesresolvers.cloudflare.acme.dnschallenge=true"
        "--certificatesresolvers.cloudflare.acme.dnschallenge.provider=cloudflare"
        "--certificatesresolvers.cloudflare.acme.email=brunomoretti100@gmail.com"
        "--certificatesresolvers.cloudflare.acme.storage=/data/acme.json"
      ];

      env = [
        {
          name = "CF_DNS_API_TOKEN";
          valueFrom = kubectl.secrets.cloudflare-api-token.valueFrom;
        }
      ];

      persistence = {
        enabled = true;
        name = "data";
        size = "128Mi";
        path = "/data";
      };
    };
  };
}
