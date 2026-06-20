_: prev: let
  base = prev.pi-coding-agent.overrideAttrs (oa: {
    patches = (oa.patches or []) ++ [
      ./compact-01-edit-spacers.patch
      ./compact-02-interactive-spacers.patch
      ./compact-03-interactive-depad.patch
      ./compact-04-interactive-noborder.patch
      ./compact-05-user-message-depad.patch
      ./compact-06-custom-message-depad.patch
      ./compact-07-tool-execution-spacers.patch
      ./compact-08-tool-execution-depad.patch
      ./compact-09-bash-execution-spacers.patch
      ./compact-10-bash-execution-depad.patch
      ./compact-11-bash-execution-simplify.patch
      ./compact-12-assistant-message-spacers.patch
      ./compact-13-assistant-message-depad.patch
      ./compact-14-tools-bash-newlines.patch
      ./compact-15-edit-depad.patch
      ./compact-16-footer-no-tokens.patch
      ./compact-17-footer-no-auto.patch
      ./compact-18-footer-model.patch
      ./compact-19-footer-one-line.patch
      ./compact-20-loader.patch

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
