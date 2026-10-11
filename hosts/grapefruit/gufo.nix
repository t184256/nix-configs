{ inputs, pkgs, ... }:

# Qwen3.8-Flash-Next (UD-Q4_K_XL + shared-Q8 MTP), gfx1151-only:
# ~1500-1600 pp, ~32-37 tg to 256k context
let
  gufoServe = inputs.gufo.lib.mkGufoServe {
    system = "x86_64-linux";
    modality = "llm";
    host = "192.168.99.52";
    port = 11111;
    model =
      "${pkgs.qwen38-flash-next-ud-q4kxl}/" +
      "Qwen3.8-Flash-Next-UD-Q4_K_XL-00001-of-00004.gguf";
    mtpModel = pkgs.qwen38-flash-next-mtp-q80;
    servedModelName = "qwen3.8-flash-next";
    context = 262144;
    speculative = "mtp";
    reasoningEffort = "medium";

    extraArgs = [ "--mmproj" (toString pkgs.qwen38-flash-next-mmproj-bf16) ];

    # no explicit sampling options: gufo auto-selects for thinking on and off

    # persists every 2k! writes scale as N^2 with context! 300 GB per convo!
    # basically needs sparser spacing a HDD, and a size cap to become viable
    #cacheDisk = "/var/lib/gufo";
    #cacheDiskStagingBytes = 4 * 1024 * 1024 * 1024;  # cap at ~128k context
    #cacheDiskBytes = 17 * 1024 * 1024 * 1024;  # ~4 snapshots
  };
in
{
  users.groups.gufo = { };
  users.users.gufo = {
    isSystemUser = true;
    group = "gufo";
    extraGroups = [ "video" "render" ];
  };

  systemd.services.gufo = {
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      User = "gufo";
      Group = "gufo";
      Restart = "on-failure";
      RestartSec = "30s";
      ExecStart = [ gufoServe ];
    };
  };

  networking.firewall.allowedTCPPorts = [ 11111 ];

  #environment.persistence."/mnt/persist".directories = [
  #  { directory = "/var/lib/gufo"; user = "gufo"; group = "gufo"; }
  #];
}
