{
  description = "My servers config flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    brunhild.url = "github:vBrunhild/dotfiles";
    deploy-rs.url = "github:serokell/deploy-rs";
    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/*";

    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    ...
  }: let
    forAllSystems = nixpkgs.lib.genAttrs [
      "aarch64-darwin"
      "aarch64-linux"
      "x86_64-darwin"
      "x86_64-linux"
    ];

    allPkgs = forAllSystems (
      system:
        import nixpkgs {inherit system;}
    );

    deployPkgs = forAllSystems (system:
      import nixpkgs {
        inherit system;
        overlays = [
          inputs.deploy-rs.overlays.default
          (self: super: {
            deploy-rs = {
              inherit (allPkgs.${system}) deploy-rs;
              lib = super.deploy-rs.lib;
            };
          })
        ];
      });
  in {
    nixosConfigurations = import ./hosts inputs;

    nixosModules =
      {
        packages = import ./packages;
        secrets = import ./secrets;
      }
      // import ./modules;

    deploy.nodes.freia = {
      hostname = "freia.brunhild.org";
      profiles.system = {
        user = "root";
        sshUser = "root";
        path =
          deployPkgs.x86_64-linux.deploy-rs.lib.activate.nixos
          self.nixosConfigurations.freia;
      };
    };

    checks =
      builtins.mapAttrs (
        system: pkgs:
          pkgs.deploy-rs.lib.deployChecks self.deploy
      )
      deployPkgs;
  };
}
