# pi-llama-cpp-stats: zero-dep extension, single .ts file
# patched: reset state on turn_end
#          so delta TPS doesn't use stale values from the previous turn
final: prev: {
  pi-llama-cpp-stats = prev.runCommand "pi-llama-cpp-stats-patched"
    { src = prev.fetchurl {
        url = "https://cdn.jsdelivr.net/npm/pi-llama-cpp-stats@0.1.6/index.ts";
        hash = "sha256-XJds2Qky22Md3ZNMFlvy7sOfPYnJ3Kx5ogfKgO8dBGE=";
      }; }
    ''
      cp $src $out
      # insert state-reset lines after the ctx.ui.setWorkingMessage() inside turn_end
      sed -i '/pi\.on("turn_end"/,/^  });/ {
        /ctx\.ui\.setWorkingMessage();/{
          n
          s/$/\
    currentProgress = null;\
    prevProcessed = 0;\
    prevTimeMs = 0;\
    hasReceivedPrefill = false;\
    rateHistory.length = 0;/
        }
      }' $out
    '';
}
