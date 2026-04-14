_: prev: {
  pi-coding-agent = prev.pi-coding-agent.overrideAttrs (oa: {
    patches = (oa.patches or []) ++ [
      ./compact-output.patch
      ./thinking-budget-tokens.patch
    ];
  });
}
