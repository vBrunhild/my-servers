{lib, ...}: let
  secrets = lib.genAttrs [
    "cloudflare-api-token"
    "k3s-token"
  ];
in {
  age.secrets = secrets (secret: {
    owner = "root";
    file = ./files/${secret}.age;
  });
}
