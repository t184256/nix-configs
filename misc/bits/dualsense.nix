{
  services.udev.extraRules = ''
    # Sony DualSense Wireless-Controller; bluetooth; USB
    KERNEL=="hidraw*", KERNELS=="*054C:0CE6*", MODE="0660", TAG+="uaccess"
    KERNEL=="hidraw*", ATTRS{idVendor}=="054c", ATTRS{idProduct}=="0ce6", MODE="0660", TAG+="uaccess"
  '';
  users.extraGroups.input.members = [ "monk" ];
}
