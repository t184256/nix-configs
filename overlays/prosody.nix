_: super:

# removes libunbound from luaEnv
{
  prosody = super.prosody.overrideAttrs (oa: {
    buildInputs = [
      super.libidn super.openssl super.icu
      (super.lua.withPackages(p: with p; [
          luasocket luasec luaexpat luafilesystem luabitop luadbi-sqlite3
          luaevent luadbi
        ]
      ))
    ];
  });
}
