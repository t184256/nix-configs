{ pkgs, ... }:

{
  # a basic set I'd like to have as root for recovery
  environment.systemPackages = with pkgs; [
    git
    rsync
    htop iotop
    strace ltrace
    wget curl
    vis  # as an emergency text editor
    mtr
    gnutar gzip bzip2 xz lz4 p7zip
    e2fsprogs  # chattr
    parted
    cryptsetup
    btdu
  ];
}
