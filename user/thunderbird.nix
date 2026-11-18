{ config, lib, ... }:

{
  imports = [
    ./config/no-graphics.nix
    ./config/live.nix
    ./config/roles.nix
  ];

  config = lib.mkIf (config.roles.mua
                && ! config.system.noGraphics
                && ! config.system.live) {
    programs.thunderbird = {
      enable = true;
      profiles.default = {
        isDefault = true;
        # TB wants the public key in its internal keyring .
        # Import it once: Account Settings -> Privacy -> Manage Keys.
        withExternalGnupg = true;  # broken anyway as of Nov 2026, I give up
        #settings."mail.openpgp.load_untested_gpgme_version" = 45;
      };
    };

    home.persistence."/mnt/persist" = {
      directories = [ ".thunderbird" ];
    };

    accounts.email.accounts."monk@unboiled.info".thunderbird.enable = true;
  };
}
