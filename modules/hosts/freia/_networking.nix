{
  networking = {
    useDHCP = false;
    firewall.allowedTCPPorts = [22 80 443];

    interfaces.ens18 = {
      ipv4.addresses = [
        {
          address = "161.97.80.162";
          prefixLength = 18;
        }
      ];
    };

    defaultGateway = {
      address = "161.97.64.1";
      interface = "ens18";
    };

    nameservers = [
      "8.8.8.8"
      "8.8.4.4"
    ];
  };
}
