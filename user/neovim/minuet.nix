{ config, ... }:

{
  imports = [
    ../config/language-support.nix
    ../config/neovim.nix
  ];
  programs.nixvim = if (! config.neovim.fat) then {} else {
    plugins.minuet = {
      enable = true;
      settings = {
        provider = "openai_compatible";
        provider_options.openai_compatible = {
          model = "qwen3-coder-sparse";
          end_point = "https://llm.slop.unboiled.info/v1/completions";
          api_key.__raw = ''vim.fn.trim(vim.fn.system("cat /mnt/secrets/llm"))'';
          stream = true;
          optional.max_tokens = 64;
        };
        virtualtext = {
          auto_trigger_ft = [ "python" "lua" "rust" ];
          keymap = {
            accept = "<Tab>";
            accept_line = "<C-y>";
            next = "<C-j>";
            prev = "<C-k>";
            dismiss = "<C-e>";
          };
        };
      };
    };
  };
  home.wraplings = if (! config.neovim.fat) then {} else {
    ai = "nvim --cmd 'lua vim.g.with_minuet = 1'";
  };
}
