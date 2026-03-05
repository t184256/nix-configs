{ pkgs, config, ... }:

{
  imports = [
    ../config/language-support.nix
    ../config/neovim.nix
  ];
  programs.nixvim = if (! config.neovim.fat) then {} else {
    extraPlugins = with pkgs.vimPlugins; [
      {
        plugin = avante-nvim;
        optional = true;
      }
    ];
    extraConfigLua = ''
      if (vim.g.with_avante == 1) then
        vim.api.nvim_command "packadd avante.nvim"
        require('avante').setup({
          provider = "openai",
          auto_suggestions_provider = "openai",
          behaviour = {
            auto_suggestions = true,
          },
          mappings = {
            suggestion = {
              accept = "<C-l>",
              next = "<C-]>",
              prev = "<C-\\>",
            },
          },
          --suggestion = {
          --  debounce = 150,
          --  throttle = 150,
          --},
          providers = {
            openai = {
              endpoint = "https://llm.slop.unboiled.info",
              model = "qwen3-coder-sparse",
              api_key_name = "cmd:cat /mnt/secrets/llm",
              context_window = 65536,
              timeout = 120000,
              use_response_api = false,
              support_previous_response_id = false,
              extra_request_body = {
                temperature = 0.75,
                max_completion_tokens = 32768,
              },
            },
          },
        })
      end
    '';
  };
  home.wraplings = if (! config.neovim.fat) then {} else {
    ai = "nvim --cmd 'lua vim.g.with_avante = 1'";
  };
}
