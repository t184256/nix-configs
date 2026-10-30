_:

# render desktop on iGPU. lose: 120Hz. gain: VRAM, stability.
{
  services.udev.extraRules = ''
    SUBSYSTEM=="drm", ENV{DEVTYPE}=="drm_minor", ENV{DEVNAME}=="/dev/dri/card*", \
      SUBSYSTEMS=="pci", KERNELS=="0000:7a:00.0", ATTRS{vendor}=="0x1002", \
      ATTRS{device}=="0x164e", TAG+="mutter-device-preferred-primary"
  '';
}
