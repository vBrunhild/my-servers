let
  brunhild = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAov1WMz0602zpjhINgrKSOdm0yFdE/JR+fCF0eEFCp3 brunomoretti100@gmail.com";
  freia = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICFJA7SfTlWQMbZB3WLWOv6xn04ou0T86N0A4MjD5bqo root@nixos";
in {
  "files/cloudflare-api-token.age".publicKeys = [brunhild freia];
  "files/foundry-admin-key.age".publicKeys = [brunhild freia];
  "files/foundry-license-key.age".publicKeys = [brunhild freia];
  "files/foundry-password.age".publicKeys = [brunhild freia];
  "files/foundry-username.age".publicKeys = [brunhild freia];
  "files/k3s-token.age".publicKeys = [brunhild freia];
}
