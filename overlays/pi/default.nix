_: prev: {
  pi-coding-agent = prev.pi-coding-agent.overrideAttrs (oa: {
    patches = (oa.patches or []) ++ [
      ./compact-01-edit-spacers.patch
      ./compact-02-interactive-spacers.patch
      ./thinking-budget-tokens.patch
    ];
  });
}
