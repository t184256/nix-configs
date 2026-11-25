# ARCTIC Fan Controller (USB HID 3904:f001, behind the motherboard).
# starts up at 40%, fully manual control, step is 1%

{
  boot.kernelModules = [ "arctic_fan_controller" ];  # just in case
  # disable runtime suspend just in case
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="3904", \
      ATTR{idProduct}=="f001", ATTR{power/control}="on"
  '';
}
