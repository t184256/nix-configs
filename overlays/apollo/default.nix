self: super:

{
  apollo = super.sunshine
    .overrideAttrs ( oa: rec {
      pname = "apollo";
      version = "0.4.6";
      src = super.fetchFromGitHub {
        owner = "ClassicOldSong";
        repo = "Apollo";
        rev = "adc5c5a0bd80831ce495434bb16aee2cd4175fb8";
        hash = "sha256-2HKjpv/NK8eMq4fUC6sFSfSDSIvT8crP//MMDoF/Bxs=";
        fetchSubmodules = true;
      };
      # Follow postPatch from sunshine but skip the desktop-file
      # and service-file substitutions — Apollo uses different filenames.
      # Also fix FFmpeg API rename: FF_PROFILE_* -> AV_PROFILE_*
      postPatch = ''
        substituteInPlace cmake/targets/common.cmake --replace-fail 'find_program(NPM npm REQUIRED)' ""
        sed -i -E 's/set\(BOOST_VERSION "[^"]*"\)/set(BOOST_VERSION "${super.boost.version}")/' cmake/dependencies/Boost_Sunshine.cmake
        echo 'set(FETCH_CONTENT_BOOST_USED TRUE)' >> cmake/dependencies/Boost_Sunshine.cmake
        substituteInPlace cmake/packaging/linux.cmake --replace-fail 'find_package(Systemd)' "" --replace-fail 'find_package(Udev)' ""
        substituteInPlace packaging/linux/sunshine.service.in --replace-fail '/bin/sleep' '${super.coreutils}/bin/sleep'
        sed -i 's/FF_PROFILE_/AV_PROFILE_/g' src/video.cpp src/platform/linux/vaapi.cpp
      '';
      ui = super.sunshine.ui.overrideAttrs ( _: rec {
        pname = "apollo-ui";
        inherit src version;
        postPatch = "cp ${./package-lock.json} ./package-lock.json";
        npmDepsHash = "sha256-h42bmqnHjiAK1RS8FFAeRWfQKVuenQug1W0P7n+ZWTU=";
        npmDeps = super.fetchNpmDeps {
          inherit src;
          name = "${pname}-${version}-npm-deps";
          hash = npmDepsHash;
          postPatch = "cp ${./package-lock.json} ./package-lock.json";
        };
      });
      patches = (oa.patches or []) ++ [ ./unicode-input.patch ];
      # Apollo bundles its own build-deps with x264/x265; don't override
      # FFMPEG_PREPARED_BINARIES from sunshine's cmakeFlags.
      cmakeFlags = builtins.filter
        (f: builtins.match ".*FFMPEG_PREPARED_BINARIES.*" f == null)
        oa.cmakeFlags;
    });
}
