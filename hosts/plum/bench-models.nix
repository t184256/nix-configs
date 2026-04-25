{ pkgs, ... }:

let
  bench-models = pkgs.writeShellScriptBin "bench-models" ''
    set -euo pipefail

    bench="${pkgs.ik-llama-cpp}/bin/llama-bench"
    moe_q4km="${pkgs.qwen36-35b-a3b-q4km}"
    dense_q4km="${pkgs.qwen36-27b-q4km}"

    export LD_LIBRARY_PATH=/run/opengl-driver/lib

    batches="512"
    depths="0,8192,32768,131072,196608,262144"

    usage() {
      echo "usage: bench-models [--batch B1[,B2,...]] [--depths D1[,D2,...]]" >&2
      echo "  --batch:  batch sizes to scan, default: 512" >&2
      echo "  --depths: KV cache depths (tokens) to scan, default: 0,131072,196608,262144" >&2
      echo "            e.g. --depths 0,8192,32768,131072,262144" >&2
      exit 1
    }

    while [ $# -gt 0 ]; do
      case "$1" in
        --batch=*)      batches="''${1#--batch=}"; shift ;;
        --batch)        batches="$2"; shift 2 ;;
        --depths=*)     depths="''${1#--depths=}"; shift ;;
        --depths)       depths="$2"; shift 2 ;;
        *)              usage ;;
      esac
    done

    section() { echo ""; echo "## $1 [ik]"; }

    # run_model LABEL MODEL MAX_DEPTH [EXTRA_ARGS...]
    # MAX_DEPTH caps which user-specified depths are used for this model.
    run_model() {
      local label="$1" model="$2" max_depth="$3"
      shift 3

      for batch in $(echo "$batches" | tr ',' '\n'); do
        section "$label [b=$batch]"

        # Filter requested depths to what this model supports
        local active_depths=""
        for d in $(echo "$depths" | tr ',' '\n'); do
          [ "$d" -le "$max_depth" ] && active_depths="$active_depths $d"
        done

        local d_list
        d_list=$(echo "$active_depths" | tr ' ' '\n' | grep . | \
          tr '\n' ',' | sed 's/,$//')
        # shellcheck disable=SC2086
        "$bench" -m "$model" -ngl 999 -b "$batch" -r 1 -rtr 1 "$@" \
          -p 2048 -n 128 -d "$d_list"
      done
    }

    # ---------- 35B-A3B Q4_K_M ----------
    run_model "35B-A3B Q4_K_M" "$moe_q4km" 262144

    # ---------- 27B Q4_K_M ----------
    run_model "27B Q4_K_M" "$dense_q4km" 262144
  '';
in

{
  environment.systemPackages = [ bench-models ];
}
