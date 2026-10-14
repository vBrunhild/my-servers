{lib, ...}: let
  secrets = lib.genAttrs [
    "authelia-oidc-jwk"
    "authelia-storage-key"
    "authelia-users"
    "cloudflare-api-token"
    "craig-bot-token"
    "craig-postgres-password"
    "crowdsec-bouncer-key"
    "dozzle-oidc"
    "foundry-admin-key"
    "foundry-license-key"
    "foundry-password"
    "foundry-username"
    "k3s-token"
    "restic-b2"
    "vaultwarden-admin-token"
  ];
in {
  age.secrets = secrets (secret: {
    owner = "root";
    file = ./files/${secret}.age;
  });
}
