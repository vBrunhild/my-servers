{
  config,
  inputs,
  ...
}: {
  imports = [inputs.flake-parts.flakeModules.modules];

  flake.nixosModules = {
    inherit (config.flake.modules.nixos) kubectl packages secrets;
  };
}
