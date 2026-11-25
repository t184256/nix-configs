_:

{
  imports = [ ../../../nixos/services/fanlistener ];

  # The side microphone lives in this chassis, hence loopback only: nothing
  # else consumes it, and calibration runs here as well.
  services.fanlistener = {
    enable = true;
    bindAddress = "127.0.0.1";
  };
}
