_: super:

{
  sunshine = super.sunshine.overrideAttrs ( oa: {
    version = "test";
    src = super.fetchFromGitHub {
      owner = "cgutman";
      repo = "LB_Sunshine";
      rev = "b6b2a29a02e8fea81db7e239255a95952f85ccb7";
      sha256 = "sha256-5RKeqlQ3i7eVqfgDcfhxDDuKrEg2vriGpUPz5GOfGGU=";
      fetchSubmodules = true;
    };
    patches = [ ./dont-build-webui.patch ];
    postPatch = ''
      # fix hardcoded libevdev path
      substituteInPlace cmake/compile_definitions/linux.cmake \
        --replace '/usr/include/libevdev-1.0' '${super.libevdev}/include/libevdev-1.0'
    '';
    #patches = (oa.patches or []) ++ [ ./2053.patch ];
    #patches = (oa.patches or []) ++ [ ./2053.patch ];
  });
}
