_: prev: let
  base = prev.pi-coding-agent.overrideAttrs (oa: {
    patches = (oa.patches or []) ++ [
      ./compact-01-edit-spacers.patch
      ./compact-02-interactive-spacers.patch
      ./compact-03-interactive-depad.patch
      ./compact-04-interactive-noborder.patch
      ./compact-05-user-message-depad.patch
      ./compact-06-tool-execution-depad.patch
      ./compact-07-custom-message-depad.patch
      ./compact-08-bash-execution-spacer.patch
      ./compact-09-bash-execution-depad.patch
      ./compact-10-bash-execution-simplify.patch
      ./compact-11-assistant-message-spacer.patch
      ./compact-12-assistant-message-depad.patch
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
