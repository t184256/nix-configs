{ fetchFromGitHub }:

let
  src = fetchFromGitHub {
    owner = "noonghunna";
    repo = "club-3090";
    rev = "e01f7a71411e3e9743e47c630d2f7bb350b41215";
    hash = "sha256-y8zqxlpo+CFEBjrpDX+zOKETavP/yFFoWpSB6RJ3ZXk=";
  };
  sglPatches = "${src}/models/qwen3.8-27b/sglang/patches";
in
{
  inherit src;
  # Marlin W4A8 for AutoRound INT4 targets. no flag, applying is enabling.
  w4a8 = "${sglPatches}/sglang-autoround-w4a8-v0.5.19";
  # cap thinking per reasoning_effort
  effortBudget = "${sglPatches}/sglang-effort-thinking-budget";
  # effort-aware --chat-template
  chatTemplate =
    "${src}/models/qwen3.8-27b/vllm/patches/qwen38-reasoning-effort-template";
  # provides required effort_budget.py generator script
  scriptsLib = "${src}/scripts/lib";
}
