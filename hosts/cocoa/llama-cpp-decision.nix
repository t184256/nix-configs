{ pkgs, lib, ... }:

# just the decision model: d1-3B on /v1/systemone.
# I don't care about performance much,
# since I'm not exactly sure what decision models are
# and whether I really need them.

let
  models = pkgs.writeText "llama.ini" ''
    [*]
    load-mode = none
    flash-attn = on
    cache-type-k = q8_0
    cache-type-v = q8_0
    batch-size = 8192
    ubatch-size = 2048

    [d1-3B]
    alias = decision
    model = ${pkgs.d1-3b-q4km}
    # image support, ~500 MB
    mmproj = ${pkgs.d1-3b-mmproj-q80}
    load-on-startup = true
    ctx-size = 32768
    parallel = 1
  '';
in
{
  services.llama-cpp = {
    enable = true;
    package = pkgs.llama-cpp-vulkan;
    openFirewall = true;
    settings = {
      host = "192.168.99.7";
      port = 11113;
      models-dir = "/var/lib/llama";
      models-preset = models;
      models-max = 1;
      n-gpu-layers = 999;
      jinja = true;
      offline = true;
    };
  };
  users.groups.llama-cpp = { };
  users.users.llama-cpp = {
    isSystemUser = true;
    group = "llama-cpp";
    extraGroups = [ "video" "render" ];
  };

  systemd.services.llama-cpp = {
    wants = [ "nebula@unboiled.service" ];
    after = [ "nebula@unboiled.service" ];
    serviceConfig = {
      ReadWritePaths = [ "/var/lib/llama" ];
      DynamicUser = lib.mkForce false;
      User = "llama-cpp";
      Group = "llama-cpp";
      Environment = [
        "XDG_CACHE_HOME=/var/lib/llama/.cache"
        "LD_LIBRARY_PATH=/run/opengl-driver/lib"
      ];
    };
  };

  environment.persistence."/mnt/persist".directories = [
    { directory = "/var/lib/llama"; user = "llama-cpp"; group = "llama-cpp"; }
  ];
}
