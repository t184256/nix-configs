{ pkgs, config, ... }:

let
  local = config.systemd.user.sockets ? llama-cpp-sweep;
  llmConfig = if local then ''
    backend = "openai",
    provider = "sweep",
    url = "http://localhost:8765",
    model = "sweep-next-edit-1.5B",
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
      if (vim.g.with_sweep == 1) then
        vim.api.nvim_command "packadd blink-edit-nvim"
        require('blink-edit').setup({
          llm = {
            ${llmConfig}
            temperature = 0.0,
            max_tokens = 512,
            timeout_ms = ${if local then "5000" else "30000"},
          },
          keymaps = {
            accept = "<Tab>",
            accept_line = "<C-y>",
            dismiss = "<C-e>",
          },
        })
      end
    '';
  };
  home.wraplings = if (! config.neovim.fat) then {} else {
    ai = "nvim --cmd 'lua vim.g.with_sweep = 1'";
  };
}
