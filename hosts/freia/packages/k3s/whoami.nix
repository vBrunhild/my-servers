{
  services.k3s.autoDeployCharts.whoami = {
    name = "whoami";
    repo = "https://cowboysysop.github.io/charts/";
    version = "6.0.0";
    hash = "sha256-oSOkvHDWOFLNdWuf2sK9Ec0cRzvF24eD0vnhYsfTHHk=";

    values = {
      ingress.enabled = false;
    };
  };

  services.k3s.manifests.whoami-ingress-route = {
    enable = true;
    content = {
      apiVersion = "traefik.io/v1alpha1";
      kind = "IngressRoute";
      metadata = {
        name = "whoami";
        namespace = "default";
      };
      spec = {
        entryPoints = ["websecure"];
        routes = [
          {
            match = "Host(`whoami.brunhild.org`)";
            kind = "Rule";
            services = [
              {
                name = "whoami";
                port = 80;
              }
            ];
            middlewares = [
              {
                name = "authelia";
                namespace = "traefik-system";
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
