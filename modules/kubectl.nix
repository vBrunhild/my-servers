{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) types mkOption;
in {
  options.kubectl.secrets = mkOption {
    description = "Kubectl secrets";
    default = {};
    type = types.attrsOf (types.submodule ({
      name,
      config,
      ...
    }: {
      options = {
        file = mkOption {
          type = types.path;
          description = "Path to file containing the secret value";
        };

        namespace = mkOption {
          type = types.str;
          default = "default";
        };

        name = mkOption {
          type = types.str;
          default = name;
        };

        key = mkOption {
          type = types.str;
          default = "value";
        };

        literals = mkOption {
          type = types.attrsOf types.str;
          default = {};
          description = "Extra non-sensitive key/value pairs to include in the secret";
        };

        valueFrom = mkOption {
          readOnly = true;
          default = {secretKeyRef = {inherit (config) key name;};};
        };
      };
    }));
  };

  config = lib.mkIf (config.kubectl.secrets != {}) {
    systemd.services =
      lib.mapAttrs' (
        attrName: secretConfig:
          lib.nameValuePair "kubectl-secret-${attrName}" {
            description = "Synce secret '${attrName}' into Kubernetes";
            wantedBy = ["multi-user.target" "k3s.service"];
            after = ["k3s.service"];
            requisite = ["k3s.service"];

            script = ''
              export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

              ${pkgs.kubectl}/bin/kubectl create namespace ${secretConfig.namespace} \
                --dry-run=client -o yaml \
                | ${pkgs.kubectl}/bin/kubectl apply -f -

              ${pkgs.kubectl}/bin/kubectl create secret generic ${secretConfig.name} \
                --from-file=${secretConfig.key}=${secretConfig.file} \
                ${lib.concatStringsSep " " (lib.mapAttrsToList (k: v: "--from-literal=${lib.escapeShellArg "${k}=${v}"}") secretConfig.literals)} \
                --namespace=${secretConfig.namespace} \
                --save-config --dry-run=client -o yaml \
                | ${pkgs.kubectl}/bin/kubectl apply -f -
            '';
          }
      )
      config.kubectl.secrets;

    systemd.paths = lib.mapAttrs' (
      attrName: secretConfig:
        lib.nameValuePair "kubectl-secret-${attrName}" {
          description = "Watch secret file for '${attrName}'";
          wantedBy = ["multi-user.target"];
          pathConfig = {
            PathChanged = secretConfig.file;
            Unit = "kubectl-secret-${attrName}.service";
          };
        }
    )
    config.kubectl.secrets;
  };
}
