{ config, pkgs, lib, inputs, ... }:

let
  withLang = lang: builtins.elem lang config.language-support;
  pyIgnores = [
    # Defaults, so that I don't get annoyed when writing short scripts.
    "D100" "D101" "D102" "D103"  # docstrings, overkill for short scripts
    "W504"  # line break after binary operator
    # Projects that care otherwise are supposed to have a CI.
  ];
in
{
  imports = [ ../config/language-support.nix ];

  programs.nixvim = {
    maps.normal."<space>f" = {
      action = "function() vim.lsp.buf.format { async = true } end";
      lua = true;
    };

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

    plugins = {
      lsp.enable = true;

      cmp-nvim-lsp.enable = true;
      cmp-nvim-lsp-signature-help.enable = true;

      lsp.servers = {
        cssls.enable = true;
        html.enable = true;
        jsonls.enable = true;
        yamlls.enable = true;

        pylsp.enable = withLang "python";
        pylsp.settings.plugins = {
          pycodestyle.enabled = true;
          pycodestyle.maxLineLength = 79;
          pycodestyle.ignore = pyIgnores;
          pydocstyle.enabled = true;
          pydocstyle.ignore = pyIgnores;
          pylsp_mypy.enabled = true;
          #pylsp_mypy.strict = true;
          rope.enabled = true;
          ruff.enabled = true;
          ruff.lineLength = 79;
          ruff.extendIgnore = pyIgnores;
          yapf.enabled = true;
          # TODO: try pylyzer
        };
        # TODO: pyright, maybe? with a limited set of checks

        bashls.enable = withLang "bash";

        clangd.enable = withLang "c";

        hls.enable = withLang "haskell";

        rnix-lsp.enable = withLang "nix";  # TODO: use nixd

        rust-analyzer.enable = withLang "rust";
      };

      null-ls = {
        enable = true;
        sources = {
          code_actions.shellcheck.enable = withLang "bash";
          code_actions.statix.enable = withLang "nix";
          diagnostics.cppcheck.enable = withLang "c";
          diagnostics.deadnix.enable = withLang "nix";
          diagnostics.gitlint.enable = true;
          diagnostics.shellcheck.enable = withLang "bash";
          diagnostics.statix.enable = withLang "nix";
          formatting.nixfmt.enable = withLang "nix";
          formatting.nixpkgs_fmt.enable = withLang "nix";
          formatting.shfmt.enable = withLang "bash";
        };
      };
    };
  };
}
