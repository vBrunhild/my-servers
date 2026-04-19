{
  age.secrets = {
    cloudflare-api-token = {
      owner = "root";
      file = ./files/cloudflare-api-token.age;
    };

    k3s-token = {
      owner = "root";
      file = ./files/k3s-token.age;
    };
  };
}
