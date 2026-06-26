{ pkgs, config, lib, inputs, ... }:

let
  llm-commit-msg-pkgs =
    inputs.llm-commit-msg.packages.${pkgs.stdenv.hostPlatform.system};
in
{
  imports = [ ../config/roles.nix ../config/neovim.nix ];

  programs.nixvim = lib.mkIf (config.roles.slop && config.neovim.fat) {
    extraPlugins = [ llm-commit-msg-pkgs.neovim-plugin ];
    extraConfigLua = ''
      require("llm-commit-msg").setup({
        bin = "${llm-commit-msg-pkgs.llm-commit-msg}/bin/llm-commit-msg",
        args = {
          "--api-endpoint", "https://llm.slop.unboiled.info",
          "--api-token-file", "/mnt/secrets/llm",
          "--model", "default-nothink",
          "--show-off", "0.001",
        },
        --debug = true,
      })
    '';
  };
}
