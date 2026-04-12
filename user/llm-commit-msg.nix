{ pkgs, inputs, ... }:

let
  llm-commit-msg-upstream =
    inputs.llm-commit-msg.packages.${pkgs.stdenv.hostPlatform.system}.default;
  llm-commit-msg = pkgs.writeShellScriptBin "llm-commit-msg" ''
    exec ${llm-commit-msg-upstream}/bin/llm-commit-msg generate \
      --api-endpoint "https://llm.slop.unboiled.info" \
      --api-token-file /mnt/secrets/llm \
      --model qwen3.5-08b-nothink \
      "$@"
  '';
in
{
  home.packages = [ llm-commit-msg ];
}
