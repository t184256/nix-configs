{ pkgs, ... }:

let
  config = {
    storage = {
      raw = "/mnt/storage/sync/voice-raw";
      meta = "/mnt/storage/sync/voice-raw/.meta";
      processed = "/mnt/storage/sync/voice/unsorted";
      processed_list = "/mnt/storage/sync/voice/unsorted/.list";
    };
    devices = {
      tx650 = {
        glob = "VOICE/FOLDER0*/*.WAV";
        prefer_channel = "right";
        drive = {
          # should be enough to detect the right thing
          Id = "SONY-IC-RECORDER-01078CAFCF2B";
          # but just to be super-specific
          CanPowerOff = true;
          ConnectionBus = "usb";
          Ejectable = true;
          Model = "IC RECORDER";
          Removable = true;
          Revision = "3.00";
          Serial = "01078CAFCF2B";
          Vendor = "SONY";
        };
      };
      tx660 = {
        glob = "REC_FILE/FOLDER01/*.wav";
        prefer_channel = "left";
        # should be unique enough
        drive.Id = "SONY-IC-RECORDER-180E94E1007818";
      };
    };
  };
in
{
  services.autosync-voice = {
    enable = true;
    configFile = pkgs.writers.writeTOML "autosync-voice.cfg.yaml" config;
    user = "monk";
  };

  systemd.services.autosync-voice = {
    environment.DBUS_SESSION_BUS_ADDRESS = "unix:path=/run/user/1000/bus";
  };
  services.udisks2.enable = true;
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if ((action.id == "org.freedesktop.udisks2.filesystem-mount" ||
           action.id == "org.freedesktop.udisks2.modify-device") &&
          subject.isInGroup("wheel")) {
        return polkit.Result.YES;
      }
    });
  '';
  security.polkit.debug = true;
}
