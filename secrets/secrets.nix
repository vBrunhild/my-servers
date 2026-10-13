let
  brunhild = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAov1WMz0602zpjhINgrKSOdm0yFdE/JR+fCF0eEFCp3 brunomoretti100@gmail.com";
  freia = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICFJA7SfTlWQMbZB3WLWOv6xn04ou0T86N0A4MjD5bqo root@nixos";
in {
  "files/authelia-oidc-jwk.age".publicKeys = [brunhild freia];
  "files/authelia-storage-key.age".publicKeys = [brunhild freia];
  "files/authelia-users.age".publicKeys = [brunhild freia];
  "files/cloudflare-api-token.age".publicKeys = [brunhild freia];
  "files/foundry-admin-key.age".publicKeys = [brunhild freia];
  "files/foundry-license-key.age".publicKeys = [brunhild freia];
  "files/foundry-password.age".publicKeys = [brunhild freia];
  "files/foundry-username.age".publicKeys = [brunhild freia];
  "files/headlamp-oidc.age".publicKeys = [brunhild freia];
  "files/k3s-token.age".publicKeys = [brunhild freia];
  "files/restic-b2.age".publicKeys = [brunhild freia];
  "files/vaultwarden-admin-token.age".publicKeys = [brunhild freia];
}
