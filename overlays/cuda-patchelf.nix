# patchelf 0.18 to at least 0.19.2 beraks on NVIDIA's prebuilt binaries
# NixOS/patchelf#668 is related but is not a complete fix.
# see also nixpkgs#434101 and nixpkgs#576412
# remove once upstream sorts it out

_: prev:
let
  inherit (prev.lib) isDerivation mapAttrs elem;

  patchelf_legacy = prev.patchelf.overrideAttrs (_: rec {
    version = "0.15.2";
    src = prev.fetchurl {
      url =
        "https://github.com/NixOS/patchelf/releases/download/${version}/" +
        "patchelf-${version}.tar.bz2";
      hash = "sha256-F3RfVkFZyOIo/EEtplogSLhGxLa0Igt3y/IkFuAvLXw=";
    };
  });
in
{
  _cuda = prev._cuda.extend (_: super: {
    extensions = (super.extensions or [ ]) ++ [
      (_finalCudaPackages: prevCudaPackages:
        mapAttrs (name: value:
          # put it first on PATH, overrideAttrs does not affect stdenv wrappers
          if isDerivation value
          && !elem name [ "backendStdenv" "stdenv" "patchelf" ]
          then
            value.overrideAttrs (oa: {
              nativeBuildInputs = (oa.nativeBuildInputs or [ ]) ++
                [ patchelf_legacy ];
            })
          else value
        ) (prevCudaPackages // { patchelf = patchelf_legacy; })
      )
    ];
  });

  kernelPackagesExtensions = (prev.kernelPackagesExtensions or [ ]) ++ [
    # for stuff like nvidia_x11 to follow
    (_finalKernelPackages: prevKernelPackages: {
      nvidiaPackages = prevKernelPackages.nvidiaPackages.extend (
        _fn: prevNvidia:
        prev.lib.mapAttrs (_name: value:
          if prev.lib.isDerivation value
          then
            value.overrideAttrs (oa: {
              nativeBuildInputs = (oa.nativeBuildInputs or [ ]) ++ [
                patchelf_legacy
              ];
            })
          else value
        ) prevNvidia
      );
    })
  ];
}
