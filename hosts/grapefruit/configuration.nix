{ pkgs, ... }:

{
  networking.hostName = "grapefruit";

  imports = [
    ../../nixos/profiles/2024.nix
    ./disko.nix
    ./hardware.nix
    ./network.nix
    #../../nixos/services/ollama.nix
    ../../nixos/services/nebula ../../nixos/services/nebula/2024.nix
    ../../nixos/services/nps.nix  # rather condition on interactive or something
    #../../nixos/services/sunshine.nix
    #../../nixos/services/syncthing.nix
  ];

  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  hardware.wirelessRegulatoryDatabase = true;

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
        ".mozilla"
      ];
    };
  };

  services.displayManager.autoLogin = { enable = true; user = "monk"; };

  boot.initrd.systemd.enable = true;
}
