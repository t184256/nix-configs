{ pkgs, ... }:

let
  python = pkgs.python3.withPackages (ps: with ps; [ evdev ]);
  script = pkgs.writeText "select2q.py" ''
    # Map DualSense BTN_SELECT to a Q press/release,
    # original event passes through.
    # A quick hack for exposing language switch in Disco Elysium
    # while keeping native PS button prompts.

    import evdev
    from evdev import ecodes as ec

    gamepad, *_ = [d for d in (evdev.InputDevice(f)
                   for f in evdev.list_devices())
                   if d.name == 'Wireless Controller']
    print(f'bound to {gamepad}', flush=True)

    ui = evdev.UInput(name='select2q', events={ec.EV_KEY: [ec.KEY_Q]})

    for event in gamepad.read_loop():
        if event.type == ec.EV_KEY and event.code == ec.BTN_SELECT:
            ui.write(ec.EV_KEY, ec.KEY_Q, event.value)
            ui.syn()
  '';
in
{
  systemd.services.select2q = {
    description = "Map BTN_SELECT to Q (Disco Elysium language switch)";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      Restart = "on-failure";
      RestartSec = "5s";
      ExecStart = "${python}/bin/python3 ${script}";
    };
  };
}
