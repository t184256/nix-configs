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
  tests =  # nix build -f . tests
    let
      keySet = l: builtins.listToAttrs (map (e: {name = e; value = null;}) l);
      sameElements = l1: l2: (keySet l1) == (keySet l2);
    in
    assert sameElements [ "a" "b" ] [ "a" "b" ];
    assert sameElements [ "a" "b" ]  [ "b" "a" ];
    assert ! sameElements [ "a" "b" ] [ "a" "b" "c" ];
    assert ! sameElements [ "a" "b" ] [ "a" ];

    assert endsWith "\\.nix" "test.nix";
    assert ! endsWith "something_else" "test.nix";
    assert desuffix "\\.nix" "test.nix" == "test";
    assert tryDesuffix "\\.nix" "test.nix" == "test";
    assert tryDesuffix "\\.nix" "something_else" == "something_else";
    
    assert builtins.elem "subdir" (listDir ./test);
    assert builtins.elem "toplevel.nix" (listDir ./test);
    assert builtins.elem "other.file" (listDir ./test);

    assert ! shouldAutoimport ./test "other.file";
    assert shouldAutoimport   ./test "toplevel.nix";
    assert shouldAutoimport   ./test "subdir";
    assert ! shouldAutoimport ./test/subdir "default.nix";
    assert shouldAutoimport   ./test/subdir "file.nix";
    assert shouldAutoimport   ./test/subdir "flatten";
    assert shouldAutoimport   ./test/subdir "def";
    assert ! shouldAutoimport ./test/subdir/def "default.nix";
    assert shouldAutoimport   ./test/subdir/def "other.nix";
    assert ! shouldAutoimport ./test/subdir "nodef";
    assert shouldAutoimport   ./test/subdir/nodef "something.nix";

    assert sameElements (asNames ./test) [ "toplevel.nix" "subdir" ];
    assert sameElements (asNames ./test/subdir) [ "file.nix" "def" "flatten" ];
    assert asNames ./test/subdir/flatten == [ "flatty.nix" ];
    assert asNames ./test/subdir/nodef == [ "something.nix" ];
    assert asNames ./test/subdir/def == [ "other.nix" ];
    assert asPaths ./test/subdir/def == [ ./test/subdir/def/other.nix ];

    assert asAttrs ./test == {
      toplevel = import ./test/toplevel.nix;
      subdir = import ./test/subdir;
    };
    assert asAttrs ./test/subdir == import ./test/subdir;
    assert asAttrs ./test/subdir == (asAttrs ./test).subdir;
    assert asAttrs ./test/subdir == {
      file = import test/subdir/file.nix;
      flatten = import test/subdir/flatten;
      def = import test/subdir/def;
    };
    assert asList ./test/subdir/def == [ (import ./test/subdir/def/other.nix) ];
    { success = true; };

  inherit asNames asPaths asAttrs asList merge;
}
