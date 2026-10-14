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
    ./dozzle.nix
    ./foundry-vtt.nix
    ./gatus.nix
    ./traefik.nix
    ./vaultwarden.nix
  ];
}
