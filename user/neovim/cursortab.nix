{ pkgs, config, ... }:

{
  imports = [
    ../config/language-support.nix
    ../config/neovim.nix
  ];
  programs.nixvim = if (! config.neovim.fat) then {} else {
    extraPlugins = with pkgs.vimPlugins; [
      {
        plugin = cursortab-nvim;
        optional = true;
      }
    ];
    extraConfigLua = ''
      if (vim.g.with_cursortab == 1) then
        vim.api.nvim_command "packadd cursortab-nvim"
        local f = io.open("/mnt/secrets/llm", "r")
        if f then
          vim.env.CURSORTAB_API_KEY = f:read("*a"):gsub("%s+$", "")
          f:close()
        end
        require('cursortab').setup({
          log_level = "trace",
          behavior = {
            idle_completion_delay = 50,
            text_change_debounce = 50,
            enabled_modes = { "insert", "normal" },
            cursor_prediction = {
              enabled = true,
              auto_advance = true,
              proximity_threshold = 2,
            },
          },
          keymaps = {
            accept = "<tab>",
            partial_accept = "<shift-tab>",
          },
          provider = {
            type = "zeta-2",
            model = "zeta";
            --type = "sweep";
            --model = "sweep";
            url = "https://llm.slop.unboiled.info",
            api_key_env = "CURSORTAB_API_KEY",
            temperature = 0.0,
            top_k = 50,
            context_size = 4096,
            max_tokens = 256,
            completion_timeout = 10000,
          },
        })
      end
    '';
  };
  home.wraplings = if (! config.neovim.fat) then {} else {
    ai = "nvim --cmd 'lua vim.g.with_cursortab = 1'";
  };
}
