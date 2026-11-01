{
  container = {
    allowPrivilegeEscalation = false;
    capabilities.drop = ["ALL"];
  };

  pod.seccompProfile.type = "RuntimeDefault";

  namespaceLabels = {
    "pod-security.kubernetes.io/enforce" = "baseline";
    "pod-security.kubernetes.io/warn" = "restricted";
    "pod-security.kubernetes.io/audit" = "restricted";
  };

  nonRoot = uid: {
    runAsNonRoot = true;
    runAsUser = uid;
    runAsGroup = uid;
  };
}
