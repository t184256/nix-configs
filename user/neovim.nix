{ config, pkgs, lib, inputs, ... }:

let
  withLang = lang: builtins.elem lang config.language-support;
in
{
  imports = [ ./config/language-support.nix ];
  nixpkgs.overlays = [ (import ../overlays/vim-plugins.nix) ];

  programs.neovim = {
    enable = true;

    withRuby = false;
    withNodeJs = false;

    extraPackages = with pkgs; [
      yaml-language-server
      # TODO: try grammarly, languagetool, marksman, prosemd...
    ] ++ lib.optionals (withLang "bash") [
      nodePackages.bash-language-server
    ] ++ lib.optionals (withLang "c") [
      gnumake  # for :make
      ccls
    ] ++ lib.optionals (withLang "haskell") [
      haskell-language-server
    ] ++ lib.optionals (withLang "nix") [
      inputs.nixd.packages.${pkgs.system}.default
    ] ++ lib.optionals (withLang "python") (with python3Packages; [
      # TODO: switch to pyright alone, TODO: or at least make flake8 quieter
      pyright python-lsp-server flake8 pycodestyle autopep8
    ]) ++ lib.optionals (withLang "rust") [
      rust-analyzer
    ];

    plugins = with pkgs.vimPlugins; [
      # fancy plugins: treesitter
      # playground  # :TSHighlightCapturesUnderCursor,
                    # :help treesitter-highlight-groups
      {
        plugin = (nvim-treesitter.withPlugins (plugins: with plugins;
          [ dockerfile git_rebase meson
            regex sql
            html markdown markdown_inline
            json json5 toml yaml
          ]
          ++ lib.optionals (withLang "bash") [ bash ]
          ++ lib.optionals (withLang "c") [ c ]
          ++ lib.optionals (withLang "haskell") [ haskell ]
          ++ lib.optionals (withLang "nix") [ nix ]
          ++ lib.optionals (withLang "python") [ python ]
          ++ lib.optionals (withLang "rust") [ rust ]
        ));
        type = "lua";
        config = ''
          require'nvim-treesitter.configs'.setup {
            highlight = {
              enable = true,
              --additional_vim_regex_highlighting = false,
            };
          }
          --vim.api.nvim_set_hl(0, "@none", { link = "Normal" })
        '';
      }

      # fancy plugins: LSP
      {
        plugin = nvim-lspconfig;
        type = "lua";
        config = ''

          local lspconfig = require('lspconfig')
          local lsp_defaults = lspconfig.util.default_config
          -- https://github.com/neovim/nvim-lspconfig/issues/2640
          local lspconfigs = require('lspconfig.configs')
          if not lspconfigs.nixd then
            lspconfigs.nixd = {
              default_config = {
                cmd = { 'nixd' },
                filetypes = { 'nix' },
                root_dir = function(fname)
                  return (lspconfig.util.find_git_ancestor(fname)
                          or vim.loop.os_homedir())
                end,
                settings = {},
                init_options = {},
              }
            }
          end

          lsp_defaults.capabilities = vim.tbl_deep_extend(
            'force',
            lsp_defaults.capabilities,
            require('cmp_nvim_lsp').default_capabilities()
          )

          local opts = { noremap=true, silent=true }
          vim.keymap.set('n', '<space>e', vim.diagnostic.open_float, opts)
          vim.keymap.set('n', '[d', vim.diagnostic.goto_prev, opts)
          vim.keymap.set('n', ']d', vim.diagnostic.goto_next, opts)
          vim.keymap.set('n', '<space>q', vim.diagnostic.setloclist, opts)
          local on_attach = function(_client, bufnr)
            vim.api.nvim_buf_set_option(bufnr, 'omnifunc',
                                        'v:lua.vim.lsp.omnifunc')
            local bufopts = { noremap=true, silent=true, buffer=bufnr }
            vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, bufopts)
            vim.keymap.set('n', 'gd', vim.lsp.buf.definition, bufopts)
            vim.keymap.set('n', 'gr', vim.lsp.buf.references, bufopts)
            vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, bufopts)
            vim.keymap.set('n', 'K', vim.lsp.buf.hover, bufopts)
            vim.keymap.set('n', '<C-k>', vim.lsp.buf.signature_help, bufopts)
            vim.keymap.set('n', '<space>r', vim.lsp.buf.rename, bufopts)
            vim.keymap.set('n', '<space>a', vim.lsp.buf.code_action, bufopts)
            vim.keymap.set('n', '<space>f', function()
              vim.lsp.buf.format { async = true }
            end, bufopts)
          end

          lspconfig.yamlls.setup{on_attach=on_attach}
        '' + lib.optionalString (withLang "bash") ''
          lspconfig.bashls.setup{on_attach=on_attach}
        '' + lib.optionalString (withLang "c") ''
          lspconfig.ccls.setup{on_attach=on_attach}
        '' + lib.optionalString (withLang "haskell") ''
          lspconfig.hls.setup{on_attach=on_attach}
        '' + lib.optionalString (withLang "nix") ''
          lspconfig.nixd.setup{on_attach=on_attach}
        '' + lib.optionalString (withLang "python") ''
          lspconfig.pylsp.setup{
            on_attach = on_attach,
            settings = {
              pylsp = {
                plugins = {
                  flake8 = {
                    enabled = true,
                    -- pyright overlap
                    ignore = {'F811', 'F401', 'F821', 'F841'},
                  },
                  pycodestyle = {
                    enabled=true,
                  },
                },
              },
            },
          }
          lspconfig.pyright.setup{
            on_attach = on_attach,
            settings = {
              python = {
                analysis = {
                  typeCheckingMode = 'basic',
                  diagnosticSeverityOverrides = {
                    reportConstantRedefinition = 'warning',
                    reportDuplicateImport = 'warning',
                    reportMissingSuperCall = 'warning',
                    reportUnnecessaryCast = 'warning',
                    reportUnnecessaryComparison = 'warning',
                    reportUnnecessaryContains = 'warning',
                    reportCallInDefaultInitializer = 'info',
                    reportFunctionMemberAccess = 'info',
                    reportImportCycles = 'info',
                    reportMatchNotExhaustive = 'info',
                    reportShadowedImports = 'info',
                    reportUninitializedInstanceVariable = 'info',
                    reportUnnecessaryIsInstance = 'info',
                    reportUnusedClass = 'info',
                    reportUnusedFunction = 'info',
                    reportUnusedImport = 'info',
                    reportUnusedVariable = 'info',
                  },
                },
              },
            },
          }
        '' + lib.optionalString (withLang "rust") ''
          lspconfig.rust_analyzer.setup{on_attach=on_attach}
        '';
      }
      {
        plugin = lsp_signature-nvim;
        type = "lua";
        config = ''
          require'lsp_signature'.setup{
            hint_prefix = "",
            hint_scheme = "LSPVirtual",
            floating_window = false,
          }
        '';
      }

      # fancy plugins: autocompletion and snippets
      cmp-nvim-lsp
      luasnip
      cmp_luasnip
      friendly-snippets
      {
        plugin = nvim-cmp;
        type = "lua";
        config = ''
          require('luasnip.loaders.from_vscode').lazy_load()

          vim.opt.completeopt = {'menu', 'menuone', 'noselect'}
          local cmp = require('cmp')
          local luasnip = require('luasnip')
          local check_backspace = function()
            local col = vim.fn.col(".") - 1
            return col == 0 or vim.fn.getline("."):sub(col, col):match("%s")
          end

          cmp.setup{
            completion = { autocomplete = false },
            snippet = {
              expand = function(args)
                luasnip.lsp_expand(args.body)
              end
            },
            sources = cmp.config.sources({
              { name = 'path' },
              { name = 'nvim_lsp' },
            }, {
              { name = 'luasnip' },
              { name = 'buffer' },
            }),
            matching = {
              disallow_fuzzy_matching=true,
              disallow_partial_matching=true,
              disallow_prefix_matching=true,
            },
            mapping = {
              ['<C-Space>'] = cmp.mapping.confirm({select = false}),
              ['<C-Tab>'] = cmp.mapping.complete_common_string(),
              ['<Tab>'] = cmp.mapping(function(fallback)
                if cmp.visible() then
                  if not cmp.complete_common_string() then
                    cmp.select_next_item(select_opts)
                  end
                elseif check_backspace() then
                  fallback()
                elseif luasnip.expandable() then
                  luasnip.expand()
                elseif luasnip.expand_or_locally_jumpable() then
                  luasnip.expand_or_jump()
                else
                  cmp.complete()
                end
              end, {'i', 's'}),
              ['<S-Tab>'] = cmp.mapping(function(fallback)
                if cmp.visible() then
                  cmp.select_prev_item(select_opts)
                elseif luasnip.locally_jumpable(-1) then
                  luasnip.jump(-1)
                else
                  fallback()
                end
              end, {'i', 's'}),
            }
          }
        '';

      }

      # gv and its dependencies
      gv-vim vim-fugitive vim-rhubarb fugitive-gitlab-vim

      # less fancy plugins from classical vim world   # TODO: configure in lua
      vim-eunuch  # helpers for UNIX: :SudoWrite, :Rename, ...
      vim-lastplace  # remember position
      vim-nix  # syntax files and indentation
      vim-repeat  # better repetition
      vim-sleuth  # guess indentation
      tcomment_vim  # <gc> comment action
      vim-undofile-warn   # undofile enabled + warning on overundoing
      {
        plugin = vim-better-whitespace;  # trailing whitespace highlighting
        config = ''
          let g:show_spaces_that_precede_tabs = 1
        '';
      }
      {
        plugin = vim-sneak;  # faster motion bound to <s>
        config = ''
          let g:sneak#target_labels = "tnaowyfu'x.c,rise"  " combos start with last
        '';
      }
      {
        plugin = vim-gitgutter;  # color changed lines
        config = ''
          " but don't show signs column and don't do that until I press <gl>
          autocmd BufWritePost * GitGutter
          let g:gitgutter_highlight_lines = 0
          :set signcolumn=no
          autocmd VimEnter,Colorscheme * :hi GitGutterAddLine guibg=#002200
          autocmd VimEnter,Colorscheme * :hi GitGutterChangeLine guibg=#222200
          autocmd VimEnter,Colorscheme * :hi GitGutterDeleteLine guibg=#220000
          autocmd VimEnter,Colorscheme * :hi GitGutterChangeDeleteLine guibg=#220022
          nnoremap <silent> gl :GitGutterLineHighlightsToggle<CR>:IndentGuidesToggle<CR>
        '';
      }
      {
        plugin = vim-indent-guides;  # indent guides
        config = ''
          let g:indent_guides_enable_on_vim_startup = 1
          let g:indent_guides_auto_colors = 0
          autocmd VimEnter,Colorscheme * :hi IndentGuidesOdd  guibg=#000000
          autocmd VimEnter,Colorscheme * :hi IndentGuidesEven guibg=#0e0e0e
        '';
      }
      {
        # TODO: use own theme,
        # fix nested highlighting problems with hard overrides
        plugin = vim-boring;  # non-clownish color theme
        config = ''
          set termguicolors
          colorscheme boring

          set colorcolumn=80
          hi ColorColumn guifg=#ddbbbb guibg=#0a0a0a

          set wildoptions=pum
          set pumblend=20
          set winblend=20
          hi Pmenu guifg=#aaaaaa
        '';
      }
      {
        plugin = vimagit;  # my preferred git interface for committing
        config = ''
          let g:magit_auto_close = 1
        '';
      }
    ];

    extraConfig = ''
      set shell=/bin/sh
      set laststatus=1  " display statusline if there are at least two windows
      set suffixes+=.pdf  " don't offer to open pdfs
      set scrolloff=3
      set diffopt+=algorithm:patience
      set updatetime=500
      set title noruler noshowmode
      function! NiceMode()
        let mode_map = {
          \   'n': ''', 'i': '[INS]', 'R': '[RPL]',
          \   'v': '[VIS]', 'V': '[VIL]', "\<C-v>": '[VIB]',
          \   'c': '[CMD]', 's': '[SEL]', 'S': '[S-L]', "\<C-s>": '[S-B]',
          \   't': '[TRM]'
          \ }
        return get(mode_map, mode(), '[???]')
      endfunction
      let &titlestring = "vi > %y %t%H%R > %P/%LL %-13.(%l:%c%V %{NiceMode()}%)"
      set titlelen=200
    '';

    viAlias = true;
  };

  home.wraplings = {
    view = "nvim -R";
    vimagit = "nvim +MagitOnly";
  };
  home.sessionVariables.EDITOR = "nvim";
}
