{
  nixpkgs,
  self,
  ...
}: let
  inherit (self) inputs;
in {
  freia = nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    specialArgs = {
      inherit inputs;
      flake = self;
    };
    modules = [
      ./freia
      inputs.agenix.nixosModules.default
      inputs.determinate.nixosModules.default
      inputs.disko.nixosModules.disko
      self.nixosModules.kubectl
      self.nixosModules.packages
      self.nixosModules.secrets
    ];
  };
}
