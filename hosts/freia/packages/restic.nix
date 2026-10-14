{
  config,
  lib,
  pkgs,
  ...
}: let
  stoppedApps = ["foundryvtt" "vaultwarden"];

  kubectl = app: "${pkgs.kubectl}/bin/kubectl --kubeconfig /etc/rancher/k3s/k3s.yaml -n ${app}";
  replicasFile = app: "/run/restic-backups-b2/${app}-replicas";

  stopApp = app: ''
    ${kubectl app} get deployment ${app} -o jsonpath='{.spec.replicas}' > ${replicasFile app}
    ${kubectl app} scale deployment ${app} --replicas=0
    if [ -n "$(${kubectl app} get pods -l app=${app} -o name)" ]; then
      ${kubectl app} wait --for=delete pod -l app=${app} --timeout=120s
    fi
  '';

  restoreApp = app: ''
    if [ -f ${replicasFile app} ]; then
      ${kubectl app} scale deployment ${app} --replicas="$(cat ${replicasFile app})"
    fi
  '';
in {
  services.restic.backups.b2 = {
    environmentFile = config.age.secrets.restic-b2.path;
    initialize = true;

    paths = [
      "/var/lib/foundryvtt"
      "/var/lib/rancher/k3s/storage"
    ];

    exclude = [
      "/var/lib/foundryvtt/container_cache"
      "/var/lib/foundryvtt/Logs"
    ];

    backupPrepareCommand = lib.concatMapStrings stopApp stoppedApps;

    backupCleanupCommand = lib.concatMapStrings restoreApp stoppedApps;

    pruneOpts = [
      "--keep-daily 7"
      "--keep-weekly 4"
      "--keep-monthly 6"
    ];

    checkOpts = ["--read-data-subset=5%"];

    timerConfig = {
      OnCalendar = "04:00";
      RandomizedDelaySec = "15m";
      Persistent = true;
    };
  };
}
