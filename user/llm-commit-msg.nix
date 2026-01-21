{ pkgs, inputs, ... }:

let
  llm-commit-msg-upstream = inputs.llm-commit-msg.packages.${pkgs.system}.default;
  llm-commit-msg = pkgs.writeShellScriptBin "llm-commit-msg" ''
    exec ${llm-commit-msg-upstream}/bin/llm-commit-msg generate \
      --api-endpoint "https://llm.slop.unboiled.info" \
      --api-token-file /mnt/secrets/llm \
      --model gpt-oss:20b \
      "$@"
  '';
in
{
  home.packages = [ llm-commit-msg ];
}
