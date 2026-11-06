# pi-llama-cpp-stats: zero-dep extension, single .ts file
#
# 0.1.8+ resets its state when a new request starts while idle
# (resetProgress() in the fetch wrapper), so the old turn_end state-reset
# patch is no longer needed.
final: prev: {
  pi-llama-cpp-stats = prev.runCommand "pi-llama-cpp-stats"
    { src = prev.fetchurl {
        url = "https://cdn.jsdelivr.net/npm/pi-llama-cpp-stats@0.1.11/index.ts";
        hash = "sha256-LWh3VBHO/aH89Kk+BLixCRMFQLqtHPfQktEv9cGEoHE==";
      }; }
    ''
      cp $src $out
    '';
}
