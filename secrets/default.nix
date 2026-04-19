{lib, ...}: let
  secrets = lib.genAttrs [
    "cloudflare-api-token"
    "foundry-admin-key"
    "foundry-license-key"
    "foundry-password"
    "foundry-username"
    "k3s-token"
  ];
in {
  age.secrets = secrets (secret: {
    owner = "root";
    file = ./files/${secret}.age;
  });
}
