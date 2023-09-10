# restricted to nix builtins only
# examples correspond to dir = "test" and the following file structure:
#   ./test/toplevel.nix                # .toplevel
#   ./test/other.file                  # excluded (doesn't end with .nix)
#   ./test/subdir/default.nix          # .subdir, does `autoimport.asAttrs ./.`
#   ./test/subdir/file.nix             # .subdir.file
#   ./test/subdir/flatten/default.nix  # .subdir.flatten, `autoimport.merge ./.`
#   ./test/subdir/flatten/flatty.nix   # .subdir.flatten (merged into it)
#   ./test/subdir/def/default.nix      # .subdir.def
#   ./test/subdir/def/other.nix        # excluded (nothing imports it)
#   ./test/subdir/nodef/something.nix  # excluded (nodef/ has no default.nix)


let
  # helpers

  endsWith = regex: s: builtins.match ("(.*)" + regex) s != null;
  desuffix = regex: s: builtins.head (builtins.match ("(.*)" + regex) s);
  tryDesuffix = regex: s: if (endsWith regex s) then (desuffix regex s) else s;
  listDir = dir: builtins.attrNames (builtins.readDir dir);
  keySet = l: builtins.listToAttrs (map (e: {name = e; value = null;}) l);

  # the meat

  shouldAutoimport = at: n: builtins.pathExists (at + "/${n}/default.nix") ||
                            (builtins.pathExists (at + "/${n}") &&
                             endsWith "\\.nix" n && n != "default.nix");
  extractName = tryDesuffix "\\.nix";
  asNames = dir: builtins.filter (shouldAutoimport dir) (listDir dir);
  asPaths = dir: map (n: dir + "/${n}") (asNames dir);
  asAttrs = dir: builtins.listToAttrs (
    map (n: {name = (extractName n); value = (import (dir + "/${n}"));})
        (asNames dir)
  );
  asList = dir: builtins.attrValues (asAttrs dir);
  merge = dir: { imports = asPaths dir; };

in
{
  _tests = {
    testEndsWithPositive = {
      expr = endsWith "\\.nix" "test.nix";
      expected = true;
    };

    testEndsWithNegative = {
      expr = endsWith "something_else" "test.nix";
      expected = false;
    };

    testDesuffix = {
      expr = desuffix "\\.nix" "test.nix";
      expected = "test";
    };

    testTryDesuffixDoesSomething = {
      expr = tryDesuffix "\\.nix" "test.nix";
      expected = "test";
    };

    testTryDesuffixDoesNothing = {
      expr = tryDesuffix "\\.nix" "something_else";
      expected = "something_else";
    };

    testListDir = {
      expr = builtins.map (n: builtins.elem n (listDir ./test)) [
        "subdir" "toplevel.nix" "other.file" "nonex"
      ];
      expected = [ true true true false ];
    };

    testShouldAutoimport = {
      expr = builtins.map (shouldAutoimport ./test) [
        "other.file" "toplevel.nix" "subdir"
      ];
      expected = [ false true true ];
    };

    testShouldAutoimportSubdir = {
      expr = builtins.map (shouldAutoimport ./test/subdir) [
        "default.nix" "file.nix" "flatten" "def" "nodef"
      ];
      expected = [ false true true true false ];
    };

    testShouldAutoimportDef = {
      expr = builtins.map (shouldAutoimport ./test/subdir/def) [
        "default.nix" "other.nix"
      ];
      expected = [ false true ];
    };

    testShouldAutoimportNoDef = {
      expr = shouldAutoimport ./test/subdir/nodef "something.nix";
      expected = true;
    };

    testAsNames2 = {
      expr = keySet (asNames ./test);
      expected = keySet [ "toplevel.nix" "subdir" ];
    };

    testAsNames3 = {
      expr = builtins.map asNames [
        ./test/subdir/flatten ./test/subdir/nodef ./test/subdir/def
      ];
      expected = [ [ "flatty.nix" ] [ "something.nix" ]  [ "other.nix" ] ];
    };

    testAsPaths = {
      expr = asPaths ./test/subdir/def;
      expected = [ ./test/subdir/def/other.nix ];
    };

    testAsAttrsEq1 = {
      expr = asAttrs ./test/subdir;
      expected = import ./test/subdir;
    };

    testAsAttrsEq2 = {
      expr = asAttrs ./test/subdir;
      expected = (asAttrs ./test).subdir;
    };

    testAsAttrsSubdir = {
      expr = asAttrs ./test/subdir;
      expected = {
        file = import ./test/subdir/file.nix;
        flatten = import ./test/subdir/flatten;
        def = import ./test/subdir/def;
      };
    };

    testAsList = {
      expr = asList ./test/subdir/def;
      expected = [ (import ./test/subdir/def/other.nix) ];
    };
  };

  inherit asNames asPaths asAttrs asList merge;
}
