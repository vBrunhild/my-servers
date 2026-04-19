{
  services.vault = {
    enable = true;
    address = "0.0.0.0:8200";
    storageBackend = "file";
    extraConfig =
      # hcl
      ''
        ui = true;
      '';
  };
}
