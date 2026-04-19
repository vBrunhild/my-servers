{config, ...}: {
  services.k3s = {
    enable = true;
    role = "server";
    tokenFile = config.age.secrets.k3s-token.path;
    extraFlags = [
      "--disable=traefik"
      "--kube-apiserver-arg=oidc-issuer-url=https://auth.brunhild.org"
      "--kube-apiserver-arg=oidc-client-id=headlamp"
      "--kube-apiserver-arg=oidc-username-claim=preferred_username"
      "--kube-apiserver-arg=oidc-username-prefix=oidc:"
      "--kube-apiserver-arg=oidc-groups-claim=groups"
      "--kube-apiserver-arg=oidc-groups-prefix=oidc:"
    ];
  };

  imports = [
    ./authelia.nix
    ./foundry-vtt.nix
    ./headlamp.nix
    ./traefik.nix
  ];
}
