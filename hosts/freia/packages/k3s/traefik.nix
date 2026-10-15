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
    version = "42.0.0";
    hash = "sha256-+e3Vymmf8PXqsU325P7voV91l6m1bwscAfYImx7suvE=";
    createNamespace = true;
    targetNamespace = "traefik-system";

    values = {
      providers.kubernetesCRD.allowCrossNamespace = true;

      deployment = {
        replicas = 1;
      };

      resources = {
        requests = {
          cpu = "100m";
          memory = "128Mi";
        };
        limits.memory = "1Gi";
      };

      service.spec.externalTrafficPolicy = "Local";

      logs.access.enabled = true;

      experimental.plugins.crowdsec-bouncer = {
        moduleName = "github.com/maxlerebourg/crowdsec-bouncer-traefik-plugin";
        version = "v1.7.1";
      };

      volumes = [
        {
          name = "crowdsec-bouncer-key";
          mountPath = "/etc/crowdsec-bouncer";
          type = "secret";
        }
      ];

      ports = {
        web.http.redirections.entryPoint = {
          to = "websecure";
          scheme = "https";
          permanent = true;
        };

        websecure.http.middlewares = [
          "traefik-system-crowdsec-bouncer@kubernetescrd"
        ];
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
