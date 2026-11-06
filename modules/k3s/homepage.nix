{
  flake.modules.nixos.homepage = {
    config,
    lib,
    ...
  }: let
    inherit (lib) types mkOption;

    security = import ./_security.nix;

    namespace = "homepage";

    apps =
      lib.sortOn (app: lib.toLower app.title)
      (lib.attrValues (lib.filterAttrs (_: app: app.enable) config.homepage.apps));

    condition = groups:
      if groups == []
      then "true"
      else "or ${lib.concatMapStringsSep " " (group: ''(has "${group}" $groups)'') groups}";

    tile = app: ''
      {{if ${condition app.groups}}}{{$any = true}}
      <a class="tile" href="${lib.escapeXML app.url}">
        ${lib.optionalString (app.icon != null) ''<img src="${lib.escapeXML app.icon}" alt="">''}
        <div>
          <h2>${lib.escapeXML app.title}</h2>
          ${lib.optionalString (app.description != null) "<p>${lib.escapeXML app.description}</p>"}
        </div>
      </a>
      {{end}}
    '';

    page = ''
      {{$groups := splitList "," (.Req.Header.Get "Remote-Groups")}}
      {{$any := false}}
      <!doctype html>
      <html lang="en">
      <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>brunhild</title>
        <style>
          :root {
            color-scheme: dark;
            --bg: #121212;
            --card: #1e1e1e;
            --card-hover: #2a2a2a;
            --border: #2f2f2f;
            --text: #e6e6e6;
            --muted: #9a9a9a;
            --accent: #1976d2;
          }
          * { box-sizing: border-box; }
          body {
            margin: 0;
            min-height: 100vh;
            background: var(--bg);
            color: var(--text);
            font-family: system-ui, -apple-system, "Segoe UI", Roboto, sans-serif;
          }
          main { max-width: 960px; margin: 0 auto; padding: 48px 16px; }
          header {
            display: flex;
            flex-wrap: wrap;
            gap: 8px;
            justify-content: space-between;
            align-items: baseline;
            margin-bottom: 32px;
          }
          h1 { margin: 0; font-size: 1.75rem; font-weight: 600; }
          header span { color: var(--muted); }
          header a { color: var(--accent); text-decoration: none; margin-left: 12px; }
          .grid {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(220px, 1fr));
            gap: 16px;
          }
          .tile {
            display: flex;
            gap: 14px;
            align-items: center;
            padding: 16px;
            background: var(--card);
            border: 1px solid var(--border);
            border-radius: 10px;
            color: inherit;
            text-decoration: none;
            transition: background 0.15s, border-color 0.15s;
          }
          .tile:hover { background: var(--card-hover); border-color: var(--accent); }
          .tile img { width: 40px; height: 40px; flex-shrink: 0; }
          .tile h2 { margin: 0; font-size: 1rem; font-weight: 600; }
          .tile p { margin: 4px 0 0; font-size: 0.85rem; color: var(--muted); }
          .empty { color: var(--muted); }
        </style>
      </head>
      <body>
        <main>
          <header>
            <h1>brunhild</h1>
            <span>Signed in as {{html (.Req.Header.Get "Remote-Name")}}<a href="https://auth.brunhild.org/logout">Log out</a></span>
          </header>
          <div class="grid">
            ${lib.concatMapStrings tile apps}
          </div>
          {{if not $any}}<p class="empty">No apps available.</p>{{end}}
        </main>
      </body>
      </html>
    '';

    caddyfile = ''
      :8080 {
        respond /healthz 200
        root * /srv
        templates
        header Cache-Control "no-store"
        file_server
      }
    '';

    configData = {
      Caddyfile = caddyfile;
      "index.html" = page;
    };
  in {
    options.homepage.apps = mkOption {
      description = "Apps listed on the homepage";
      default = {};
      type = types.attrsOf (types.submodule ({name, ...}: {
        options = {
          enable = mkOption {
            type = types.bool;
            default = true;
            description = "Whether to show the app on the homepage";
          };

          title = mkOption {
            type = types.str;
            default = name;
          };

          url = mkOption {
            type = types.str;
          };

          description = mkOption {
            type = types.nullOr types.str;
            default = null;
          };

          icon = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "Image URL for the app's icon";
          };

          groups = mkOption {
            type = types.listOf types.str;
            default = ["admin"];
            description = "Groups that see the app; an empty list shows it to every logged-in user";
          };
        };
      }));
    };

    config = lib.mkIf (apps != []) {
      services.k3s.manifests.homepage-namespace = {
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

      services.k3s.manifests.homepage-config = {
        enable = true;
        content = {
          apiVersion = "v1";
          kind = "ConfigMap";
          metadata = {
            name = "homepage-config";
            inherit namespace;
          };
          data = configData;
        };
      };

      services.k3s.manifests.homepage-deployment = {
        enable = true;
        content = {
          apiVersion = "apps/v1";
          kind = "Deployment";
          metadata = {
            name = "homepage";
            inherit namespace;
          };
          spec = {
            replicas = 1;
            selector.matchLabels.app = "homepage";
            template = {
              metadata = {
                labels.app = "homepage";
                annotations."checksum/config" = builtins.hashString "sha256" (builtins.toJSON configData);
              };
              spec = {
                automountServiceAccountToken = false;
                securityContext = security.pod;

                containers = [
                  {
                    name = "caddy";
                    image = "caddy:2.11.9-alpine";
                    ports = [{containerPort = 8080;}];

                    securityContext =
                      security.container
                      // security.nonRoot 65534
                      // {
                        readOnlyRootFilesystem = true;
                        capabilities = security.container.capabilities // {add = ["NET_BIND_SERVICE"];};
                      };

                    resources = {
                      requests = {
                        cpu = "10m";
                        memory = "16Mi";
                      };
                      limits.memory = "64Mi";
                    };

                    volumeMounts = [
                      {
                        name = "caddyfile";
                        mountPath = "/etc/caddy";
                        readOnly = true;
                      }
                      {
                        name = "site";
                        mountPath = "/srv";
                        readOnly = true;
                      }
                      {
                        name = "caddy-data";
                        mountPath = "/data";
                      }
                      {
                        name = "caddy-config";
                        mountPath = "/config";
                      }
                    ];

                    readinessProbe = {
                      httpGet = {
                        path = "/healthz";
                        port = 8080;
                      };
                      initialDelaySeconds = 2;
                      periodSeconds = 10;
                    };

                    livenessProbe = {
                      httpGet = {
                        path = "/healthz";
                        port = 8080;
                      };
                      initialDelaySeconds = 10;
                      periodSeconds = 30;
                    };
                  }
                ];

                volumes = [
                  {
                    name = "caddy-data";
                    emptyDir = {};
                  }
                  {
                    name = "caddy-config";
                    emptyDir = {};
                  }
                  {
                    name = "caddyfile";
                    configMap = {
                      name = "homepage-config";
                      items = [
                        {
                          key = "Caddyfile";
                          path = "Caddyfile";
                        }
                      ];
                    };
                  }
                  {
                    name = "site";
                    configMap = {
                      name = "homepage-config";
                      items = [
                        {
                          key = "index.html";
                          path = "index.html";
                        }
                      ];
                    };
                  }
                ];
              };
            };
          };
        };
      };

      services.k3s.manifests.homepage-service = {
        enable = true;
        content = {
          apiVersion = "v1";
          kind = "Service";
          metadata = {
            name = "homepage";
            inherit namespace;
          };
          spec = {
            selector.app = "homepage";
            ports = [
              {
                port = 80;
                targetPort = 8080;
              }
            ];
          };
        };
      };

      services.k3s.manifests.homepage-ingress-route = {
        enable = true;
        content = {
          apiVersion = "traefik.io/v1alpha1";
          kind = "IngressRoute";
          metadata = {
            name = "homepage";
            inherit namespace;
          };
          spec = {
            entryPoints = ["websecure"];
            routes = [
              {
                match = "Host(`home.brunhild.org`)";
                kind = "Rule";
                middlewares = [
                  {
                    name = "authelia";
                    namespace = "traefik-system";
                  }
                ];
                services = [
                  {
                    name = "homepage";
                    port = 80;
                  }
                ];
              }
            ];
            tls.certResolver = "cloudflare";
          };
        };
      };
    };
  };
}
