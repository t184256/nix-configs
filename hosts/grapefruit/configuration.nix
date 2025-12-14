{ pkgs, inputs, ... }:

{
  networking.hostName = "grapefruit";

  imports = [
    ../../nixos/profiles/2024.nix
    ./disko.nix
    "${inputs.nixos-hardware}/framework/desktop/amd-ai-max-300-series"
    ./hardware.nix
    ./network.nix
    ../../nixos/services/llama-cpp.nix
    ../../nixos/services/nebula ../../nixos/services/nebula/2024.nix
    ../../nixos/services/nps.nix  # rather condition on interactive or something
    #../../nixos/services/sunshine.nix
    #../../nixos/services/syncthing.nix
  ];

  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernelParams = [
    "amd_iommu=off"  # kills VFIO for speed
    "amd.gttsize=110592"
    "amdttm.pages_limit=27648000"
    "amdttm.page_pool_size=27648000"
    "ttm.pages_limit=27648000"
    "ttm.page_pool_size=27648000"
  ];
  hardware.graphics.enable = true;
  hardware.wirelessRegulatoryDatabase = true;
  #hardware.amdgpu.opencl.enable = true;
  #hardware.amdgpu.overdrive.enable = true;
  #hardware.amdgpu.overdrive.ppfeaturemask = "0xf7fd7fff";  # -PP_GFXOFF_MASK
  #services.lact.enable = true;
  environment.systemPackages = with pkgs; [
    rocmPackages.amdsmi
    rocmPackages.rocminfo
    rocmPackages.rocm-smi
    amdgpu_top
    radeontop
  ];

  # Enable sound with pipewire.
  #sound.enable = true;
  #services.pulseaudio.enable = false;
  #security.rtkit.enable = true;
  #services.pipewire = {
  #  enable = true;
  #  alsa.enable = true;
  #  alsa.support32Bit = true;
  #  pulse.enable = true;
  #};

  system.role = {
    #deployer.enable = true;
    desktop.enable = true;
    physical.enable = true;
    #physical.portable = true;
    #yubikey.enable = true;
  };
  #services.syncthing = {
  #  user = "monk";
  #  group = "users";
  #  settings.options.localAnnounceEnabled = true;
  #};

  system.stateVersion = "26.05";
  home-manager.users.monk.home.stateVersion = "26.05";

  home-manager.users.monk.neovim.fat = true;
  home-manager.users.monk.language-support = [
    "nix" "bash" "prose" "python" "typst" "yaml"
  ];

  home-manager.users.monk.home.sessionVariables.SSH_AUTH_SOCK =
    "/run/user/1000/gnupg/S.gpg-agent.ssh";

  #home-manager.users.monk.home.persistence."/mnt/storage/sync" = {
  #  directories = [
  #    { directory = "code"; method = "symlink"; }
  #    { directory = "notes"; method = "symlink"; }
  #  ];
  #};
  environment.persistence."/mnt/persist" = {
    users.monk = {
      directories = [
        ".config/gh"
        ".local/share/password-store"
        ".localai"
        ".mozilla"
      ];
    };
  };

  #home-manager.users.monk.services.local-ai = {
  #  enable = true;
  #};

  services.displayManager.autoLogin = { enable = true; user = "monk"; };

  boot.initrd.systemd.enable = true;

  programs.nix-ld.enable = true;
}
