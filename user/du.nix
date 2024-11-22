{ pkgs, ... }:

{
  home.packages = with pkgs; [ gdu dust ];
  # dui is an alias for interactive du: ncdu, gdu...
  home.wraplings.dui = "gdu";
  # duo is an alias for a one-shot du: dust, ...
  home.wraplings.duo = "dust -Bc";
}
