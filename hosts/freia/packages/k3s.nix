{config, ...}: {
  services.k3s = {
    enable = true;
    role = "server";
    tokenFile = config.age.secrets.k3s-token.path;
    extraFlags = [
      "--disable=servicelb"
      "--disable=traefik"
    ];
  };
}
