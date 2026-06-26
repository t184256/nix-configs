{ pkgs, lib, config, inputs, ... }:

let
  llm-commit-msg-upstream =
    inputs.llm-commit-msg.packages.${pkgs.stdenv.hostPlatform.system}.default;
  llm-commit-msg = pkgs.writeShellScriptBin "llm-commit-msg" ''
    exec ${llm-commit-msg-upstream}/bin/llm-commit-msg generate \
      --api-endpoint "https://llm.slop.unboiled.info" \
      --api-token-file /mnt/secrets/llm \
      --model default-nothink \
      "$@"
  '';
in
{
  imports = [ ./config/roles.nix ];

  home.packages = lib.mkIf config.roles.slop [ llm-commit-msg ];
}
