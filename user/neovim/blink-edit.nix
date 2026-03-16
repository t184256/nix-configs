{ pkgs, config, ... }:

let
  local = config.systemd.user.sockets ? llama-cpp-sweep;
  llmConfig = if local then ''
    backend = "openai",
    provider = "sweep",
    url = "http://localhost:8765",
    model = "sweep",
  '' else ''
    backend = "openai",
    provider = "sweep",
    url = "https://llm.slop.unboiled.info",
    model = "sweep",
    api_key = (function()
      local f = io.open("/mnt/secrets/llm", "r")
      local k = f and f:read("*a"):gsub("%s+$", "") or nil
      if f then f:close() end
      return k
    end)(),
  '';
in
{
  imports = [
    ../config/language-support.nix
    ../config/neovim.nix
  ];
  programs.nixvim = if (! config.neovim.fat) then {} else {
    extraPlugins = with pkgs.vimPlugins; [
      {
        plugin = blink-edit-nvim;
        optional = true;
      }
    ];
    extraConfigLua = ''
      if (vim.g.with_blink_edit == 1) then
        vim.api.nvim_command "packadd blink-edit-nvim"
        require('blink-edit').setup({
          llm = {
            ${llmConfig}
            temperature = 0.0,
            max_tokens = 8192,
            stop_tokens = { "<|editable_region_end|>", "</s>", "<|endoftext|>" },
            timeout_ms = ${if local then "5000" else "30000"},
          },
          ui = { progress = false },
          prefetch = { enabled = true },
          context = {
            lines_before = 20,
            lines_after = 20,
            same_file = {
              enabled = true,
              max_lines_before = 40,
              max_lines_after = 40,
            },
            history = {
              enabled = true,
              max_items = 10,
              max_tokens = 1024,
              max_files = 4,
            },
            lsp = {
              enabled = true,
              max_definitions = 4,
              max_references = 4,
            },
          },
          normal_mode = {
            enabled = true,
            debounce_ms = 200,
          },
        })
        dofile("${./blink-edit-ui.lua}")
      end
    '';
  };
  home.wraplings = if (! config.neovim.fat) then {} else {
    ai = "nvim --cmd 'lua vim.g.with_blink_edit = 1'";
  };
}
