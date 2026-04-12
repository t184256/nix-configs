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
        propagatedBuildInputs =
          (prev.lib.filter (d: !(prev.lib.elem d.pname unneeded))
            old.propagatedBuildInputs)
          ++ [ prev.python3Packages.email-validator ];
        pythonImportsCheck = [ "litellm" ];
      });
  };
  litellm-slim = final.python3Packages.litellm;
}
