_: prev: let
  base = prev.pi-coding-agent.overrideAttrs (oa: {
    patches = (oa.patches or []) ++ [
      ./compact-01-edit-spacers.patch
      ./compact-02-interactive-spacers.patch
      ./compact-03-interactive-depad.patch
      ./thinking-budget-tokens.patch
    ];
  });

  extensions = [ ./no-tail-pipe.ts ];

  mkWrapped = exts: prev.writeShellScriptBin "pi" (
    let
      extArgs = builtins.concatStringsSep " "
        (builtins.map (e: "--extension ${e}") exts);
    in ''exec ${prev.lib.getExe base} ${extArgs} "$@"''
  );
in rec {
  pi-coding-agent-without-extensions = base;
  pi-coding-agent = mkWrapped extensions;
}
