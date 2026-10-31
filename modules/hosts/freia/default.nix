{
  config,
  inputs,
  withSystem,
  ...
}: let
  modules = config.flake.modules.nixos;
in {
  configurations.nixos.freia.module = {modulesPath, ...}: {
    imports = [
      (modulesPath + "/installer/scan/not-detected.nix")
      (modulesPath + "/profiles/qemu-guest.nix")
      ./_disk.nix
      ./_hardware.nix
      ./_networking.nix
      inputs.determinate.nixosModules.default
      inputs.disko.nixosModules.disko
      modules.nix
      modules.packages
      modules.secrets
      modules.k3s
      modules.homepage
      modules.authelia
      modules.craig
      modules.crowdsec
      modules.foundry-vtt
      modules.gatus
      modules.radar
      modules.traefik
      modules.vaultwarden
      modules.restic
      modules.ssh
    ];

    boot.loader.grub = {
      device = "/dev/sda";
      efiSupport = true;
      efiInstallAsRemovable = true;
    };

    users.users.root = {
      extraGroups = ["podman"];
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAov1WMz0602zpjhINgrKSOdm0yFdE/JR+fCF0eEFCp3 brunomoretti100@gmail.com"
      ];
    };

    system.stateVersion = "25.11";
  };

  flake.deploy.nodes.freia = withSystem "x86_64-linux" ({deployPkgs, ...}: {
    hostname = "freia.brunhild.org";
    profiles.system = {
      user = "root";
      sshUser = "root";
      path =
        deployPkgs.deploy-rs.lib.activate.nixos
        config.flake.nixosConfigurations.freia;
    };
  });
}
