{
  config,
  pkgs,
  ...
}: let
  kubectl = "${pkgs.kubectl}/bin/kubectl --kubeconfig /etc/rancher/k3s/k3s.yaml -n foundryvtt";
  replicasFile = "/run/restic-backups-b2/foundryvtt-replicas";
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

    backupPrepareCommand = ''
      ${kubectl} get deployment foundryvtt -o jsonpath='{.spec.replicas}' > ${replicasFile}
      ${kubectl} scale deployment foundryvtt --replicas=0
      if [ -n "$(${kubectl} get pods -l app=foundryvtt -o name)" ]; then
        ${kubectl} wait --for=delete pod -l app=foundryvtt --timeout=120s
      fi
    '';

    backupCleanupCommand = ''
      if [ -f ${replicasFile} ]; then
        ${kubectl} scale deployment foundryvtt --replicas="$(cat ${replicasFile})"
      fi
    '';

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
