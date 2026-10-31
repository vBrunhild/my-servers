{
  flake.modules.nixos.hardening = {
    security.protectKernelImage = true;

    boot.kernel.sysctl = {
      "net.ipv4.conf.all.send_redirects" = 0;
      "net.ipv4.conf.default.send_redirects" = 0;
      "net.ipv6.conf.all.accept_redirects" = 0;
      "net.ipv6.conf.default.accept_redirects" = 0;
      "net.core.bpf_jit_harden" = 2;
      "fs.suid_dumpable" = 0;
    };
  };
}
