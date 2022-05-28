{ stdenv, lib, kernel }:

stdenv.mkDerivation rec {
  name = "i915-nitrocaster-mod-${version}";
  version = kernel.version;

  hardeningDisable = [ "pic" "format" ];
  nativeBuildInputs = kernel.moduleBuildDependencies;

  src = ./.;
  patches = [ patch1 patch2 ];

  postUnpack = ''
    tar -C i915-nitrocaster-mod \
      --strip-components=3 -xf ${kernel.src} --wildcards \
      '*/drivers/i915' '*/drivers/hid/hid-multitouch.c'
  '';
  patchFlags = "-p3";

  makeFlags = [
    "KERNEL_DIR=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
    "INSTALL_MOD_PATH=$(out)"
  ];

  meta = with lib; {
    description = "i915 module patched for Lenovo X220 mod by Nitrocaster";
    platforms = platforms.linux;
  };
}
