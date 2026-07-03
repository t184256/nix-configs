{ inputs, lib, pkgs, ... }:

{
  networking.hostName = "plum";

  imports = [
    ../../nixos/profiles/2024.nix
    ./disko.nix
    "${inputs.nixos-hardware}/common/cpu/amd"
    "${inputs.nixos-hardware}/common/gpu/nvidia"
    ./hardware.nix
    ./network.nix
    ../../nixos/services/nebula ../../nixos/services/nebula/2024.nix
    ../../nixos/services/vllm.nix
    ../../nixos/services/whisper-cpp-cuda.nix
    ../../nixos/services/llama-cpp-mini.nix
    ./bench-vllm.nix
    ./clevis.nix
    ./clevis-highlevel.nix
    ./safe-reboot.nix
    ./cooling/lact.nix
    ./cooling/fancontrol.nix
    ./cooling/measurement/calibrate-fancontroller.nix
    ./cooling/fanlistener.nix
    ./cooling/temps.nix
  ];

  nixpkgs.config.allowUnfreePredicate = pkg:
    lib.hasPrefix "nvidia" (lib.getName pkg) ||
    lib.hasPrefix "cuda" pkg.name;
  # scripts.nix:1202 in nixpkgs compares pythonPackages != pkgs.pypy2Packages,
  # which forces pypy2Packages evaluation. sigh.
  nixpkgs.config.permittedInsecurePackages =
    [
      "pypy2.7-setuptools-44.0.0"
      "pypy2.7-pip-20.3.4"
    ];

  hardware.nvidia.open = true;

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.initrd.systemd.enable = true;
  boot.initrd.systemd.network.enable = true;

  home-manager.users.monk.home.stateVersion = "25.11";
  system.stateVersion = "25.11";

  systemd.tpm2.enable = false;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  systemd.sleep.settings.Sleep.AllowSuspend = false;
  services.displayManager.gdm.autoSuspend = false;

  system.role.desktop.enable = true;
  system.role.physical.enable = true;

  system.role.virtualizer.enable = true;
  system.role.virtualizer.storageLocation = "persist";

  networking.firewall.allowedTCPPorts = [
    8787 # slopfest pi bridge
    9988 # ctl
  ];

  environment.systemPackages = with pkgs; [ amdgpu_top ];
}
