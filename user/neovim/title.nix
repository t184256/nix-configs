{ config, pkgs, lib, inputs, ... }:

{
  imports = [
    ../config/language-support.nix
    ../config/neovim.nix
  ];
  programs.nixvim = {
    plugins.navic = lib.mkIf config.neovim.fat {
      enable = true;
      settings = {
        safe_output = true;
        lsp.auto_attach = true;
        icons = builtins.listToAttrs (map (v: { name = v; value = ""; }) [
          "Array" "Boolean" "Class" "Constant" "Constructor" "Enum" "EnumMember"
          "Event" "Field" "File" "Function" "Interface" "Key" "Method" "Module"
          "Namespace" "Null" "Number" "Object" "Operator" "Package" "Property"
          "String" "Struct" "TypeParameter" "Variable"
        ]);
      };
    };
    opts = {
      title = true;
      titlelen = 200;
      titlestring =
        "vi > %t%H%R %P/%LL %l:%c%V" + (
          if config.neovim.fat
          then "%{v:lua.NiceContext()}"
          else ""
        );
    };
    extraConfigLua = lib.mkIf config.neovim.fat ''
      do
        function _G.NiceContext()
          loc = require'nvim-navic'.get_location()
          if loc ~= "" then
            return " > " .. loc
          end
          return ""
        end
      end
    '';
  };
}
