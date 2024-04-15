treeverse: let
  configVmB = {
    pkgs,
    config,
    ...
  }: {
    # Importing a nixos module
    imports = [
      treeverse.repositories.repoA.nixosModuleA
    ];

    # nixos version
    system.stateVersion = "24.05";

    # filesystem layout
    fileSystems = {
      "/".device = "/dev/disk/by-label/nix";
      "/boot".device = "/dev/disk/by-label/ESP";
    };

    # bootloader
    boot.loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };

    # autologin as root
    services.getty.autologinUser = "root";

    # forwarding qemu port 8080 to host
    virtualisation.vmVariant.virtualisation.forwardPorts = [
      {
        host.port = 8080;
        guest.port = 8080;
      }
    ];

    # keyboard layout
    services.xserver.xkb.layout = "fr";
    console.keyMap = "fr";

    # Opening appA port
    networking.firewall.allowedTCPPorts = [8080];
  };
in {
  # vmB: nixos VM running service appA
  vmB = (treeverse.pkgs.nixos configVmB).vm;

  # testB: testing vmB config
  testB = treeverse.pkgs.nixosTest {
    name = "test-vmB";
    nodes = {
      machineWithAppA = configVmB;
      machineWithCurl = {pkgs, ...}: {
        environment.systemPackages = [
          pkgs.curl
        ];
      };
    };
    testScript = ''
      start_all()

      machineWithAppA.wait_for_unit("appA.service")
      machineWithAppA.wait_for_open_port(8080)
      machineWithCurl.wait_for_unit("multi-user.target")

      result = machineWithCurl.succeed("curl http://machineWithAppA:8080")
      expected = "Hello Devoxx!"
      assert expected in result, f"failed: result:«{result}» and expected:«{expected}» differ!"
    '';
  };
}
