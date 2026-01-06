_:

{
  services.mediamtx = {
    enable = true;
    settings = {
      authInternalUsers = [
        {
          user = "coconut";
          pass = "$argon2id$v=19$m=4096,t=3,p=1$c2FsdEl0V2l0aFNhbHQ$+qof31Zy/x4EO1Foe0vrz1burDkik1T2TEqO3lpEjKk";
          permissions = [ { action = "publish"; path = "coconut"; } ];
        }
        {
          user = "citron";
          pass = "$argon2id$v=19$m=4096,t=3,p=1$c2FsdEl0V2l0aFNhbHQ$rRwYinRRG3w72iD8Q3JPlnCZUVvIkRYLOcZXigI+fS0";
          permissions = [ { action = "read"; path = "coconut"; } ];
        }
      ];
    };
  };
  networking.firewall.allowedTCPPorts = [ 8554 ];
}
