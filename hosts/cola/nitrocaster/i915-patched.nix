{ stdenv, lib, kernel, gnumake }:

let
  i915-vanilla-src = stdenv.mkDerivation {
    name = "i915-vanilla-src-${kernel.version}";
    version = kernel.version;
    phases = [ "installPhase" ];
    installPhase = ''
      mkdir -p $out
      tar -C $out --strip-components=1 -xf ${kernel.src} --wildcards \
          '*/include' \
          '*/drivers/platform/x86/intel_ips.h' \
          '*/drivers/gpu/drm/i915'
    '';
  };
in

stdenv.mkDerivation rec {
  name = "i915-nitrocaster-mod-${kernel.version}";
  version = kernel.version;

  hardeningDisable = [ "pic" "format" ];
  nativeBuildInputs = kernel.moduleBuildDependencies;

  unpackPhase = ''
    cp -rv ${i915-vanilla-src}/* ./
    chmod -R +w ./*
  '';

  patches = [ ./5.18.patch ];

  buildPhase = ''
    ${gnumake}/bin/make -j $(nproc) \
      -C${kernel.dev}/lib/modules/${kernel.modDirVersion}/build \
      'M=$(PWD)/drivers/gpu/drm/i915' \
      'subdir-ccflags-y+=-I$(src) -I$(src)/../..' \
      "subdir-ccflags-y+=-I$(pwd)/drivers/gpu/drm/i915/gvt" \
      modules
  '';

  installPhase = ''
    ${gnumake}/bin/make \
      -C${kernel.dev}/lib/modules/${kernel.modDirVersion}/build \
      'M=$(PWD)/drivers/gpu/drm/i915' \
      INSTALL_MOD_PATH=$out modules_install
  '';

  meta = with lib; {
    description = "i915 module patched for Lenovo X220 mod by Nitrocaster";
    platforms = platforms.linux;
  };
}
