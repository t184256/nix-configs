{ config, pkgs, lib, inputs, ... }:

let
  withLang = lang: builtins.elem lang config.language-support;
  pyDocIgnores = [
    # Defaults, so that I don't get annoyed when writing short scripts.
    # docstrings, overkill for short scripts
    "D100" "D101" "D102" "D103" "D105" "D106" "D107"
    "D203"  # 1 blank line required before class docstring
    "D213"  # multi-line docstring summary should start at the second line
    # Projects that care otherwise are supposed to have a CI.
  ];
  pyStyleIgnores = [
    "W504"  # line break after binary operator
  ];
  pyRuffIgnores = pyDocIgnores;
  pythonPlusDot = pkgs.runCommandCC "python-plus-dot" {
      pname = "python-plus-dot";
      executable = true;
      preferLocalBuild = true;
      nativeBuildInputs = [ pkgs.makeBinaryWrapper ];
  } ''
    makeBinaryWrapper ${pkgs.coreutils}/bin/env $out \
      --add-flags python \
      --prefix PYTHONPATH : .
  '';
  pyfmt = pkgs.writeShellScript "pyfmt" ''
    set -uexo pipefail
    exec ruff format - | ruff --fix --select COM812 - | ruff format -
  '';
in
{
  imports = [ ../config/language-support.nix ];
  nixpkgs.overlays = [ (import ../../overlays/python-lsp-server.nix) ];

  programs.nixvim = {
    keymaps = [
      {
        key = "<space>f";
        mode = "n";
        # ruff format isn't wired to python-lsp-ruff yet
        action = ''
          function()
            if vim.bo.filetype == "python" then
              vim.cmd("%!${pyfmt} <% 2>/dev/null")
            else
              vim.lsp.buf.format { async = true }
            end
          end
        '';
        lua = true;
      }
      {
        key = "<space>a";
        mode = [ "n" "v" ];
        action = "require('actions-preview').code_actions";
        lua = true;
      }
      {
        key = "<space>r";
        mode = "n";
        action = "vim.lsp.buf.rename";
        lua = true;
      }
      {
        key = "<space>w";
        mode = "n";
        action = "function() lsp_lines_toggle() end";
        lua = true;
      }
    ] ++ (if ! withLang "python" then [] else [
      {
        key = "<space>d";  # debug
        mode = "n";
        action = ''
          function() require('neotest').run.run({strategy = 'dap'}) end
        '';
        lua = true;
      }
      {
        key = "<space>i";  # inspect
        mode = [ "n" "v" ];
        action = "require('dap.ui.widgets').hover";
        lua = true;
      }
    ]);

    extraPackages = with pkgs; [
      # TODO: try grammarly, languagetool, marksman, prosemd...
    ] ++ lib.optionals (withLang "c") [
      gnumake # for :make
      cppcheck
    ] ++ lib.optionals (withLang "bash") [
      shellcheck
    ] ++ lib.optionals (withLang "nix") [
      inputs.nixd.packages.${pkgs.system}.default
    ];

    extraPlugins = with pkgs.vimPlugins; [
      actions-preview
    ] ++ (if ! (withLang "python") then [] else [
      neotest neotest-python
    ]);

    plugins = {
      lsp.enable = true;
      lsp-lines.enable = true;

      cmp-nvim-lsp.enable = true;
      cmp-nvim-lsp-signature-help.enable = true;
      telescope.enable = true;

      lsp.servers = {
        #cssls.enable = true;  # requires non-free code now?
        #html.enable = true;  # requires non-free code now?
        #jsonls.enable = true;  # requires non-free code now?
        yamlls.enable = withLang "yaml";

        pylsp.enable = withLang "python";
        pylsp.settings.plugins = {
          pycodestyle.enabled = true;
          pycodestyle.maxLineLength = 79;
          pycodestyle.ignore = pyStyleIgnores;
          pydocstyle.enabled = true;
          pydocstyle.ignore = pyDocIgnores;
          pylsp_mypy.enabled = true;
          rope.enabled = true;
          # TODO: try pylyzer
        };
        ruff-lsp.enable = withLang "python";
        # TODO: pyright, maybe? with a limited set of checks

        bashls.enable = withLang "bash";

        clangd.enable = withLang "c";

        hls.enable = withLang "haskell";

        marksman.enable = withLang "markdown";

        ltex.enable = withLang "prose";
        ltex.settings = {
          additionalRules = {
            enablePickyRules = true;
            motherTongue = "ru-RU";
          };
          completionEnabled = true;
          #diagnosticSeverity = "warning";
        };

        rnix-lsp.enable = withLang "nix";  # TODO: use nixd

        rust-analyzer.enable = withLang "rust";
        rust-analyzer.installCargo = true;
        rust-analyzer.installRustc = true;
      };

      none-ls = {
        enable = true;
        sources = {
          #code_actions.gitsigns.enable = true;
          code_actions.ltrs.enable = withLang "prose";
          code_actions.shellcheck.enable = withLang "bash";
          code_actions.statix.enable = withLang "nix";
          #diagnostics.alex.enable = withLang "prose";  # that's too much
          diagnostics.bandit.enable = withLang "python";
          diagnostics.cppcheck.enable = withLang "c";
          diagnostics.deadnix.enable = withLang "nix";
          diagnostics.gitlint.enable = true;
          diagnostics.markdownlint.enable = withLang "markdown";
          diagnostics.shellcheck.enable = withLang "bash";
          diagnostics.statix.enable = withLang "nix";
          diagnostics.write_good.enable = withLang "prose";
          formatting.beautysh.enable = withLang "bash";
          formatting.markdownlint.enable = withLang "markdown";
          formatting.nixfmt.enable = withLang "nix";
          formatting.nixpkgs_fmt.enable = withLang "nix";
          formatting.shfmt.enable = withLang "bash";
        };
      };
      dap = {  # for neotest
        enable = withLang "python";
        extensions.dap-python.enable = withLang "python";
        extensions.dap-python.adapterPythonPath =
          "${pkgs.python3.withPackages (ps: [ ps.debugpy ] )}/bin/python";
        extensions.dap-python.testRunner = "pytest";
        extensions.dap-virtual-text.enable = withLang "python";
        extensions.dap-ui.enable = withLang "python";
      };
    };
    extraConfigLua = ''
      vim.diagnostic.config({
        virtual_text = true,
        virtual_lines = false
      })
      lsp_lines_toggle = function()
        if not vim.diagnostic.config().virtual_lines then
          vim.diagnostic.config({
            virtual_text = false,
            virtual_lines = { highlight_whole_line = false }
          })
        else
          vim.diagnostic.config({
            virtual_text = true,
            virtual_lines = false
          })
        end
      end
      require("actions-preview").setup {
        diff = {
          algorithm = "patience",
        },
        backend = { "telescope" },
      }
    '' + (if ! withLang "python" then "" else ''
      require("neotest").setup({
        output = {
          enabled = false,
        },
        status = {
          virtual_text = true,
        },
        icons = {
          failed = "○",
          final_child_indent = " ",
          final_child_prefix = "╰",
          non_collapsible = "─",
          passed = "◉",
          running = "◐",
          running_animated = { "◐", "◓", "◑", "◒" },
          skipped = "○",
          unknown = "○",
          watching = "○"
        },
        adapters = {
          require("neotest-python") {
            python = "${pythonPlusDot}",
            runner = "pytest",
          }
        }
      })
    '');
    autoCmd = [
      {
        event = [ "LspAttach" ];
        pattern = [ "test_*.py" ];
        callback.__raw = ''
          function()
            require('neotest').watch.watch(vim.fn.expand('%'))
          end
        '';
      }
    ];
  };
}
