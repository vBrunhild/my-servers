{
  lib,
  pkgs,
  inputs,
  ...
}: let
  system = pkgs.stdenv.hostPlatform.system;
in {
  environment.systemPackages = map lib.lowPrio [
    inputs.brunhild.packages.${system}.neovim
    pkgs.bottom
    pkgs.coreutils-full
    pkgs.dust
    pkgs.eza
    pkgs.ripgrep
  ];

  programs.nh.enable = true;

  programs.bash = {
    enable = true;

    shellInit =
      # bash
      ''
        [ -z "$PS1" ] && return
      '';
  };
}
