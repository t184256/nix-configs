# `podman machine init` pulls quay.io/podman/machine-os:<major.minor>
# pre-pull it. update as nixpkgs updates podman. x86_64-linux only

_: prev:

let
  version = "6.1.4";
in
{
  podmanMachineImage =
    assert version == prev.podman.version;  # update version and hash
    prev.fetchurl {
      url = "https://github.com/podman-container-tools/podman-machine-os/"
        + "releases/download/v${version}/podman-machine.x86_64.qemu.qcow2.zst";
      sha256 = "sha256-ygUuEtxZOh3noNapiipRV7m68yCnmSC08YGspFKekb0=";
    };
}
