{
  flake.modules.nixos.nix = {
    nix = {
      gc.automatic = false;
      settings = {
        auto-optimise-store = true;
        builders-use-substitutes = true;
        allowed-users = ["@wheel"];
        trusted-users = ["@wheel" "root"];
        accept-flake-config = true;
        keep-derivations = true;
        keep-outputs = true;
        warn-dirty = false;
        sandbox = true;
        max-jobs = "auto";
        keep-going = true;
        log-lines = 20;
        extra-experimental-features = [
          "flakes"
          "nix-command"
          "pipe-operators"
        ];
        substituters = [
          "https://cache.nixos.org"
          "https://nix-community.cachix.org"
        ];
        trusted-public-keys = [
          "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        ];
      };
    };

    systemd.services.nix-daemon = {
      enable = true;
      environment.TMPDIR = "/var/tmp";
    };

    nixpkgs = {
      config = {
        allowUnfree = true;
        allowBroken = true;
      };
    };
  };
}
