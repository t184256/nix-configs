_:

# render desktop on iGPU. lose: 120Hz. gain: VRAM, stability.
{
  services.udev.extraRules = ''
    # prefer iGPU
    SUBSYSTEM=="drm", ENV{DEVTYPE}=="drm_minor", ENV{DEVNAME}=="/dev/dri/card*", \
      SUBSYSTEMS=="pci", KERNELS=="0000:7a:00.0", ATTRS{vendor}=="0x1002", \
      ATTRS{device}=="0x164e", TAG+="mutter-device-preferred-primary"

    # belt-and-suspenders: discrete GPUs are compute-only
    SUBSYSTEM=="drm", ENV{DEVTYPE}=="drm_minor", DRIVERS=="nvidia", \
      TAG+="mutter-device-ignore"
    SUBSYSTEM=="drm", ENV{DEVTYPE}=="drm_minor", SUBSYSTEMS=="pci", \
      ATTRS{vendor}=="0x1002", ATTRS{device}=="0x7480", \
      TAG+="mutter-device-ignore"
  '';
}
