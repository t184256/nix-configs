{ ... }:

{
  security.polkit.extraConfig = ''
    /* Allow me to do everything without the annoying prompts. */
    polkit.addRule(function(action, subject) {
      if (subject.active && subject.isInGroup("wheel"))
        return polkit.Result.YES;
    });
  '';
}
