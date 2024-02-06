{ pkgs, config, ... }:

let
  readConfigBit = p: "\n\n#${builtins.baseNameOf p}\n${builtins.readFile p}";

  # TODO: https://github.com/NixOS/nixpkgs/issues/276326
  my-xonsh = pkgs.xonsh.override { extraPackages = ps: [
    ps.xontrib-xonsh-direnv
    ps.xontrib-readable-traceback
  ]; };
in

{
  imports = [ ../config/os.nix ];
  nixpkgs.overlays = [
    (import ../../overlays/direnv.nix)
    (import ../../overlays/xontribs)
    ( self: super: { inherit my-xonsh; } )  # I refer to it in user/tmux
  ];

  home.packages = [ my-xonsh ];

  programs.direnv.enable = true;
  programs.direnv.nix-direnv.enable = true;

  home.file.".xonshrc".text = ''
    if not ''${...}.get('__NIXOS_SET_ENVIRONMENT_DONE'):
        $FOREIGN_ALIASES_SUPPRESS_SKIP_MESSAGE = True  # matters on Fedora
        # Stash xonsh's ls alias, so that we don't get a collision
        # with Bash's ls alias from environment.shellAliases:
        _ls_alias = aliases.pop('ls', None)
        # The NixOS environment and thereby also $PATH
        # haven't been fully set up at this point. But
        # `source-bash` below requires `bash` to be on $PATH
        import os as _os
        if _os.path.exists('/bin/bash'):  # prefer system bash
            source-foreign /bin/bash /etc/profile --sourcer source
        else:  # use bash from nix
            $PATH.add('${pkgs.bash}/bin')
            source-bash /etc/profile
        # Source the NixOS environment config.
        # Restore xonsh's ls alias, overriding that from Bash (if any).
        if _ls_alias is not None:
            aliases['ls'] = _ls_alias
        del _ls_alias
        if 'll' in aliases:
            del aliases['ll']
        del _os

    $XONSH='${my-xonsh}/bin/xonsh'
    xontrib load direnv
    $DIRENV_HIDE_DIFF=1
    xontrib load readable-traceback
  '' + (readConfigBit ./config/general.xsh)
     + (readConfigBit ./config/styling.xsh)
     + (readConfigBit ./config/prompts.xsh)
     + (readConfigBit ./config/completions.xsh)
     + (readConfigBit ./config/history.xsh)
     + (readConfigBit ./config/hydra-helper.xsh)
     + (readConfigBit (
        if (config.system.os == "OtherLinux") then
          ./config/nx-commands-other.xsh
        else
          ./config/nx-commands-nixos.xsh
       ))
     + (readConfigBit ./config/w.xsh)
  ;
}
