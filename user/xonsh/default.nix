{ pkgs, config, ... }:

let
  readConfigBit = p: "\n\n#${builtins.baseNameOf p}\n${builtins.readFile p}";

  my-xontribs = xs: with xs; [
    direnv
    readable-traceback
  ];
  my-extra-pypkgs = pps: with pps; [
    # nixpkgs  # disable until it gets unmarked as broken in 20.09
  ];
  my-xonsh = (pkgs.xonsh.withXontribs my-xontribs)
                        .withPythonPackages my-extra-pypkgs;
in

{
  imports = [ ../config/os.nix ];
  nixpkgs.overlays = [
    (import ../../overlays/xonsh)
    (
      self: super: { xonshLib =
        if (config.system.os != "Nix-on-Droid") then super.xonshLib else
        (super.xonshLib.overridePythonAttrs (o: {
          doCheck = false;
          doInstallCheck = false;
        }));
      }
    )
    ( self: super: { inherit my-xonsh; } )  # I refer to it in user/tmux
  ];

  home.packages = [ my-xonsh ];

  programs.direnv.enable = true;
  programs.direnv.enableNixDirenvIntegration = true;

  home.file.".xonshrc".text = ''
    xontrib load direnv
    xontrib load readable-traceback
  '' + (readConfigBit ./config/general.xsh)
     + (readConfigBit ./config/styling.xsh)
     + (readConfigBit ./config/prompts.xsh)
     + (readConfigBit ./config/completions.xsh)
     + (readConfigBit ./config/history.xsh)
     + (readConfigBit ./config/nx-commands.xsh)
     + (readConfigBit ./config/w.xsh)
  ;
}
