self: super:

let
  gopy = super.buildGoModule rec {
    pname = "gopy";
    version = "0.4.4";

    src = super.fetchFromGitHub {
      owner = "go-python";
      repo = pname;
      rev = "v${version}";
      hash = "sha256-RYcgfhvVh1wC2OtUbf987CeIp5G7gUFjlMMhASUKVSY=";
    };
    prePatch = ''
      substituteInPlace cmd_build.go --replace \
        '"build", "-mod=mod"' \
        '"build", "-p", "1", "-mod=mod"'
    '';

    vendorHash = "sha256-NcDra2xfwtyhZ6Sd+gkexnSgSvXRfDBHmWzzvJo+gNM=";
    doCheck = false;
  };

  pickle-secure = super.python3Packages.buildPythonPackage rec {
    pname = "pickle_secure";
    version = "0.9.99";
    src = super.fetchPypi {
      inherit pname version;
      sha256 = "sha256-hYYttCUluJv6l+jg1G+ITBrRjxaZ82o9N/BO3NNv7OQ=";
    };
    prePatch = ''
      substituteInPlace setup.py --replace '36.0.0,<37.0.0' '36.0.0,<39.0.0'
    '';
    propagatedBuildInputs = with super.python3Packages; [
      cryptography
    ];
  };

  slixmpp = super.python3Packages.buildPythonApplication rec {
    pname = "slixmpp";
    version = "1.8.3";
    src = super.fetchPypi {
      inherit pname version;
      sha256 = "sha256-rJtZqq7tZ/VFk4fMpDZYyTQRa1Pokmn2aw6LA+FBGXw=";
    };
    propagatedBuildInputs = with super.python3Packages; [
      aiodns
      aiohttp
      cryptography
      defusedxml
      emoji
      pyasn1
      pyasn1-modules
    ];
  };

  slidge-go-generated = super.stdenv.mkDerivation rec {
    pname = "slidge-go-generated";
    version = "0.1.0rc1";
    src = super.fetchPypi {
      pname = "slidge";
      inherit version;
      sha256 = "sha256-JCgq3zQf3t1C4nu3zs29AHO5qBxK4jnFsteBIxHemxg=";
    };
    nativeBuildInputs = [ gopy ] ++ (with super; [
      go
      cacert
      pkgs.gotools
      (python3.withPackages (ps: with ps; [ pybindgen ]))
    ]);
    patchPhase = ''
      mv slidge/plugins/whatsapp ./
      ls | grep -v whatsapp | xargs rm -r
      mv whatsapp/* ./
      rm -d whatsapp
    '';
    buildPhase = ''
      mkdir -p _go/{modcache,cache,env}
      (
      export GOPATH=$(realpath _go)
      export GOMODCACHE=$(realpath _go/modcache)
      export GOCACHE=$(realpath _go/cache)
      export GOENV=$(realpath _go/env)
      export NIX_BUILD_CORES=1
      gopy pkg -output=generated -no-make=true .
      )
    '';
    installPhase = ''
      mkdir $out
      cp generated/*.go $out/
      find $out
      find $out -type f | xargs cat
    '';
    outputHash = "";
    outputHashAlgo = "sha256";
    outputHashMode = "recursive";
  };

  slidge-go = super.buildGoModule rec {
    pname = "slidge-go";
    version = "0.1.0rc1";
    src = super.fetchPypi {
      pname = "slidge";
      inherit version;
      sha256 = "sha256-JCgq3zQf3t1C4nu3zs29AHO5qBxK4jnFsteBIxHemxg=";
    };
    vendorHash = "sha256-CS1K+hXHjgsQz4lvcs/C6OQnQzg0tW8caBUqY3K2sMA=";
    #vendorHash = null;
    #vendorHash = "";
    postUnpack = ''
      mv slidge/plugins/whatsapp ./
      ls | grep -v whatsapp | xargs rm -r
      mv whatsapp/* ./
      rm -d whatsapp
    '';
    prePatch = ''
      find ${slidge-go-generated}
      cp ${slidge-go-generated}/* ./
      exit 1

      echo PrePatch begins
      mv slidge/plugins/whatsapp ./
      ls | grep -v whatsapp | xargs rm -r
      mv whatsapp/* ./
      rm -d whatsapp
      ls
      find|grep vendor
      exit 1
      if [[ ! -e vendor ]]; then
        mkdir -p _go/{modcache,cache,env}
        (
        export GOPATH=$(realpath _go)
        export GOMODCACHE=$(realpath _go/modcache)
        export GOCACHE=$(realpath _go/cache)
        export GOENV=$(realpath _go/env)
        gopy gen -output=generated -no-make=true \
                 -vm=${super.python3}/bin/python .
        cp generated/*.go ./
        )
      fi
      echo PrePatch ends
    '';
    propagatedBuildInputs = [
      pickle-secure
      slixmpp
      #whatsmeow
    ] ++ (with super.python3Packages; [
      aiohttp
      configargparse
      pybindgen
      qrcode
    ]);
    nativeBuildInputs = [
      gopy
      super.pkgs.gotools
    ];
    #preBuild = ''
    #  runHook preBuildHook
    #  gopy gen -output=generated -no-make=true .
    #  find
    #  exit 1
    #  runHook postBuildHook
    #'';
    #buildPhase = ''
    #  runHook preBuildHook
    #  gopy build -output=generated -no-make=true .
    #  find
    #  exit 1
    #  runHook postBuildHook
    #'';
    postInstall = ''
      find
      echo ---
      find $out
      exit 1
    '';
    doCheck = false;
  };

  slidge = super.python3Packages.buildPythonApplication rec {
    pname = "slidge";
    version = "0.1.0rc1";
    src = super.fetchPypi {
      inherit pname version;
      sha256 = "sha256-JCgq3zQf3t1C4nu3zs29AHO5qBxK4jnFsteBIxHemxg=";
    };
    postBuild = ''
      find ${slidge-go}
      exit 1
      cp {slidge-go}/* slidge/plugins/whatsapp/go.*
    '';
    propagatedBuildInputs = [
      pickle-secure
      slixmpp
      #whatsmeow
    ] ++ (with super.python3Packages; [
      aiohttp
      configargparse
      pybindgen
      qrcode
    ]);
    doCheck = false;
  };
in
{
  inherit slidge;
}
