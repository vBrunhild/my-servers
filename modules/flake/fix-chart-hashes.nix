{
  perSystem = {pkgs, ...}: {
    packages.fix-chart-hashes = pkgs.writeShellApplication {
      name = "fix-chart-hashes";
      runtimeInputs = with pkgs; [gnugrep gnused jq];
      text = builtins.readFile ./fix-chart-hashes.sh;
    };
  };
}
