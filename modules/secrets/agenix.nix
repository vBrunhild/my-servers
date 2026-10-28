{inputs, ...}: let
  files = ../../secrets/files;
in {
  flake.modules.nixos.secrets = {lib, ...}: let
    secrets = lib.genAttrs [
      "authelia-oidc-jwk"
      "authelia-storage-key"
      "authelia-users"
      "cloudflare-api-token"
      "craig-bot-token"
      "craig-postgres-password"
      "crowdsec-bouncer-key"
      "foundry-admin-key"
      "foundry-auth-proxy-users"
      "foundry-license-key"
      "foundry-password"
      "foundry-username"
      "headlamp-oidc"
      "k3s-token"
      "restic-b2"
      "vaultwarden-admin-token"
    ];
  in {
    imports = [inputs.agenix.nixosModules.default];

    age.secrets = secrets (secret: {
      owner = "root";
      file = files + "/${secret}.age";
    });
  };
}
