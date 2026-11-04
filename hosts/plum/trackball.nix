# Elecom DEFT Pro TrackBall: remap the thumb buttons to middle click.
{
  services.udev.extraHwdb = ''
    # bluetooth?
    evdev:name:ELECOM TrackBall Mouse DEFT Pro TrackBall Mouse:*
     ID_INPUT_KEY=1
     KEYBOARD_KEY_90006=btn_middle
     KEYBOARD_KEY_90008=btn_middle
     KEYBOARD_KEY_90007=btn_middle

    # radio
    evdev:name:ELECOM TrackBall Mouse DEFT Pro TrackBall:*
     ID_INPUT_KEY=1
     KEYBOARD_KEY_90006=btn_middle
     KEYBOARD_KEY_90008=btn_middle
     KEYBOARD_KEY_90007=btn_middle

    # USB?
    evdev:name:DEFT Pro TrackBall:*
     ID_INPUT_KEY=1
     KEYBOARD_KEY_90006=btn_middle
     KEYBOARD_KEY_90008=btn_middle
     KEYBOARD_KEY_90007=btn_middle
  '';
}
