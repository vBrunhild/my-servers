{config, ...}: {
  services.k3s = {
    enable = true;
    role = "server";
    tokenFile = config.age.secrets.k3s-token.path;
    extraFlags = [
      "--disable=traefik"
    ];
  };

  imports = [
    ./authelia.nix
    ./traefik.nix
    ./whoami.nix
  ];
}
