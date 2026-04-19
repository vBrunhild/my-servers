{
  lib,
  pkgs,
  inputs,
  ...
}: let
  system = pkgs.stdenv.hostPlatform.system;
in {
  environment.systemPackages = map lib.lowPrio [
    pkgs.bottom
    pkgs.coreutils-full
    pkgs.dust
    pkgs.eza
    pkgs.git
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
