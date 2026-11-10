final: prev:

let
  unneeded = [
    "polars"  # analytics dataframe
    "prisma"  # DB ORM (enterprise feature)
    "resend"  # email service
    "soundfile" "sounddevice"  # audio transcription
    "azure-keyvault-secrets"
    "google-cloud-iam"
    "google-cloud-kms"
  ];
  openai-slim = prev.python3Packages.openai.overrideAttrs (old: {
    propagatedBuildInputs = prev.lib.filter
      (d: !(prev.lib.elem d.pname [ "sounddevice" "numpy" ]))
      old.propagatedBuildInputs;
  });
in {
  inherit openai-slim;
  python3Packages = prev.python3Packages // {
    litellm =
      (prev.python3Packages.litellm.override {
        openai = openai-slim;
      }).overrideAttrs (old: {
        patches = (old.patches or []) ++ [
          ./custom-openai-extra-body.patch
          ./lazy-soundfile-import.patch
          ./prompt-progress-passthrough.patch
        ];
        propagatedBuildInputs =
          (prev.lib.filter (d: !(prev.lib.elem d.pname unneeded))
            old.propagatedBuildInputs)
          ++ [
            prev.python3Packages.email-validator
            prev.python3Packages.anyio
            prev.python3Packages.apscheduler
            prev.python3Packages.backoff
            prev.python3Packages.expression
            prev.python3Packages.fastapi
            prev.python3Packages.fastapi-sso
            prev.python3Packages.mcp
            prev.python3Packages.orjson
            prev.python3Packages.redis
            prev.python3Packages.starlette
            prev.python3Packages.websockets
          ];
        pythonImportsCheck = [ "litellm" "litellm.proxy.proxy_server" ];
      });
  };
  litellm-slim = final.python3Packages.litellm;
}
