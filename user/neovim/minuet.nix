{ pkgs, config, ... }:

{
  imports = [
    ../config/language-support.nix
    ../config/neovim.nix
  ];
  programs.nixvim = if (! config.neovim.fat) then {} else {
    extraPlugins = with pkgs.vimPlugins; [
      {
        plugin = minuet-ai-nvim;
        optional = true;
      }
    ];
    extraConfigLua = ''
      local function get_llm_key()
        local f = io.open("/mnt/secrets/llm", "r")
        if not f then return nil end
        local key = f:read("*all")
        f:close()
        return key:gsub("%s+$", "")
      end

      if vim.g.ai_mode == true then
        vim.api.nvim_command("packadd minuet-ai.nvim")
        require("minuet").setup({
          --notify = "debug",
          n_completions = 1,
          provider = "openai_compatible",
          provider_options = {
            openai_compatible = {
              api_key = get_llm_key,
              end_point = "https://llm.slop.unboiled.info/v1/chat/completions",
              model = "qwen3.6-27b-think",
              name = "vllm",
              stream = true,
              optional = {
                max_tokens = 1024,
                temperature = 0.0,
                extra_body = {
                  thinking_token_budget = 512,
                },
              },
            },
          },
          virtualtext = {
            auto_trigger_ft = { "*" },
            keymap = {
              accept = "<Shift-Tab>",
              -- accept_line = "<Tab>",  -- cmp owns <Tab>
              dismiss = "<C-]>",
            },
          },
          duet = {
            provider = "openai_compatible",
            request_timeout = 15,
            editable_region = {
              lines_before = 8,
              lines_after = 15,
              before_region_filter_length = 30,
              after_region_filter_length = 30,
            },
            non_editable_region = {
              context_window = 20000,
              context_ratio = 0.75,
            },
            provider_options = {
              openai_compatible = {
                api_key = get_llm_key,
                end_point = "https://llm.slop.unboiled.info/v1/chat/completions",
                model = "qwen3.6-27b-think",
                name = "vllm",
                stream = false,
                optional = {
                  max_tokens = 4096,
                  temperature = 0.0,
                  extra_body = {
                    thinking_token_budget = 1024,
                  },
                },
              },
            },
            preview = {
              enabled = true,
              priority = 50,
              cursor = '|',
            },
          },
        })

        local duet = require("minuet.duet")

        -- Keymaps for duet: accept (apply) and dismiss
        vim.keymap.set("n", "<Tab>", function()
          if duet.action.is_visible() then
            duet.action.apply()
          else
            vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Tab>", true, true, true), "n", true)
          end
        end, { silent = true, desc = "[minuet] accept duet prediction" })

        vim.keymap.set("n", "<Esc>", function()
          if duet.action.is_visible() then
            duet.action.dismiss()
          else
            vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, true, true), "n", true)
          end
        end, { silent = true, desc = "[minuet] dismiss duet prediction" })

        -- Auto-trigger duet prediction on InsertLeave, BufEnter, CursorHoldI (idle in insert)
        vim.api.nvim_create_autocmd({"InsertLeave", "BufEnter", "CursorHoldI"}, {
          callback = function()
            vim.defer_fn(function()
              duet.action.predict()
            end, 100)
          end,
        })

        -- Recalculate suggestions after 20 seconds of idling in normal mode
        local _duet_idle_timer = nil
        vim.api.nvim_create_autocmd("CursorHold", {
          callback = function()
            if _duet_idle_timer then
              _duet_idle_timer:close()
            end
            _duet_idle_timer = vim.defer_fn(function()
              _duet_idle_timer = nil
              duet.action.predict()
            end, 20000)
          end,
        })
      end
    '';
  };
  home.wraplings = if (! config.neovim.fat) then {} else {
    ai = "nvim --cmd 'lua vim.g.ai_mode = true'";
  };
}
