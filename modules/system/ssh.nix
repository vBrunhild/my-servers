{
  flake.modules.nixos.ssh = {
    services.openssh = {
      enable = true;
      settings = {
        KbdInteractiveAuthentication = false;
        PasswordAuthentication = false;
        PermitRootLogin = "prohibit-password";
        AllowUsers = ["root"];
        MaxAuthTries = 3;
        X11Forwarding = false;
        AllowAgentForwarding = false;
        AllowTcpForwarding = "local";
        ClientAliveInterval = 300;
        ClientAliveCountMax = 2;
      };
    };

    services.fail2ban = {
      enable = true;
      maxretry = 3;
      bantime = "24h";
      ignoreIP = [
        "127.0.0.0/8"
        "10.42.0.0/16"
        "161.97.80.162"
      ];
      bantime-increment = {
        enable = true;
        maxtime = "168h";
      };
    };
  };
}
