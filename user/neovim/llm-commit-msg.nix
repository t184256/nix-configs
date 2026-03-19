{ pkgs, config, inputs, ... }:

let
  llm-commit-msg-pkgs = inputs.llm-commit-msg.packages.${pkgs.system};
in
{
  imports = [ ../config/neovim.nix ];
  programs.nixvim = if (! config.neovim.fat) then {} else {
    extraPlugins = [ llm-commit-msg-pkgs.neovim-plugin ];
    extraConfigLua = ''
      require("llm-commit-msg").setup({
        bin = "${llm-commit-msg-pkgs.llm-commit-msg}/bin/llm-commit-msg",
        args = {
          "--api-endpoint", "https://llm.slop.unboiled.info",
          "--api-token-file", "/mnt/secrets/llm",
          "--model", "qwen3.5-coder-dense-blitz",
          "--show-off", "0.001",
        },
        --debug = true,
      })
    '';
  };
}
