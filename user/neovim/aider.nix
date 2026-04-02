{ pkgs, config, ... }:


{
  imports = [ ../config/neovim.nix ];
  programs.nixvim = if (! config.neovim.fat) then {} else {
    extraPlugins = with pkgs.vimPlugins; [ aider-nvim ];

    extraConfigLua = ''
      local function read_secret(path)
        local ok, lines = pcall(vim.fn.readfile, path)
        return ok and lines[1] or ""
      end

      vim.env.HOSTED_VLLM_API_KEY = read_secret("/mnt/secrets/llm")
      vim.env.HOSTED_VLLM_API_BASE = "https://llm.slop.unboiled.info/v1"
      vim.env.OPENAI_API_KEY = read_secret("/mnt/secrets/whisper")
      vim.env.OPENAI_API_BASE = "https://whisper.slop.unboiled.info/v1"

      require("aider").setup({
        auto_manage_context = true,
        default_bindings = false,
      })

      local _prev_buf
      local _aider_buf

      local function aider_close()
        if _prev_buf and vim.api.nvim_buf_is_valid(_prev_buf) then
          vim.api.nvim_win_set_buf(0, _prev_buf)
        end
      end

      function aider_open()
        _prev_buf = vim.api.nvim_get_current_buf()
        if not (_aider_buf and vim.api.nvim_buf_is_valid(_aider_buf)) then
          vim.cmd("AiderOpen")
          _aider_buf = vim.api.nvim_get_current_buf()
          local _buf = {buffer = _aider_buf}
          vim.keymap.set("t", "<Esc>", aider_close, _buf)
          vim.keymap.set("t", "<PageUp>", "<C-\\><C-n><C-b>", _buf)
          vim.keymap.set("t", "<PageDown>", "<C-\\><C-n><C-f>", _buf)
          local scrolloff = vim.wo.scrolloff
          vim.api.nvim_create_autocmd("TermEnter", {
            buffer = _aider_buf,
            callback = function() vim.wo.scrolloff = 0 end,
          })
          vim.api.nvim_create_autocmd("TermLeave", {
            buffer = _aider_buf,
            callback = function() vim.wo.scrolloff = scrolloff end,
          })
          --local chan = vim.b.terminal_job_id
          --vim.defer_fn(function() vim.fn.chansend(chan, "/tokens\n") end, 500)
          vim.cmd("close")
        end
        vim.api.nvim_win_set_buf(0, _aider_buf)
        vim.cmd("normal! G")
        vim.schedule(function()
          if vim.fn.mode() ~= "t" then vim.cmd("startinsert") end
        end)
      end

      vim.o.jumpoptions = vim.o.jumpoptions .. ",view"
      vim.keymap.set("n", "<space>A", aider_open)
    '';
  };
}
