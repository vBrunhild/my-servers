{
  container = {
    allowPrivilegeEscalation = false;
    capabilities.drop = ["ALL"];
  };

  pod.seccompProfile.type = "RuntimeDefault";

  nonRoot = uid: {
    runAsNonRoot = true;
    runAsUser = uid;
    runAsGroup = uid;
  };
}
