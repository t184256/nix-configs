{ inputs, pkgs, ... }:

let
  pkgsCuda = import inputs.nixpkgs {
    system = pkgs.system;
    config = { cudaSupport = true; allowUnfree = true; };
    overlays = [ (import ../../overlays/lucebox.nix) ];
  };

  dflash = pkgsCuda.lucebox-dflash;

  # bench_llm.py needs datasets + transformers (no CUDA required).
  benchPython = pkgs.python3.withPackages (ps: with ps; [
    datasets transformers
  ]);

  target36xl = pkgs.qwen36-27b-q4kxl;
  target35   = pkgs.qwen35-27b-q4km;
  draft36    = pkgs.qwen36-27b-dflash-draft;
  draft35    = pkgs.qwen35-27b-dflash-draft;

  # Official benchmark from lucebox-hub: HumanEval / GSM8K / Math500.
  # Measures tok/s and acceptance length for both AR and DFlash side-by-side.
  # Downloads datasets from HuggingFace on first run (needs internet + HF_HOME).
  # Default config matches the RTX 3090 results in RESULTS.md:
  #   Qwen3.6-27B UD-Q4_K_XL target + z-lab Qwen3.6-27B-DFlash draft
  # Override via DFLASH_TARGET / DFLASH_DRAFT / DFLASH_TOKENIZER env vars.
  bench-lucebox-llm = pkgs.writeShellScriptBin "bench-lucebox-llm" ''
    set -euo pipefail
    export DFLASH_BIN="${dflash}/bin/test_dflash"
    export DFLASH_BIN_AR="${dflash}/bin/test_generate"
    export DFLASH_TARGET="''${DFLASH_TARGET:-${target36xl}}"
    export DFLASH_DRAFT="''${DFLASH_DRAFT:-${draft36}/model.safetensors}"
    export DFLASH_TOKENIZER="''${DFLASH_TOKENIZER:-Qwen/Qwen3.6-27B}"
    export LD_LIBRARY_PATH="/run/opengl-driver/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    exec ${benchPython}/bin/python3 \
      "${dflash}/share/lucebox-dflash/scripts/bench_llm.py" "$@"
  '';

  # Server latency/throughput bench (streams against the running service).
  bench-lucebox = pkgs.writeShellScriptBin "bench-lucebox" ''
    set -euo pipefail

    PORT=8002
    URL="http://127.0.0.1:$PORT"

    PROMPT_LENS="256,2048,8192,16384,32768"
    GEN_TOKENS=128
    RUNS=3

    SVC="lucebox-dflash"

    echo "## Luce DFlash: Qwen3.6-27B UD-Q4_K_XL + speculative decoding"
    echo "##   plum, dual RTX 3090 (single-GPU mode)"
    systemctl start "$SVC"
    trap "systemctl stop $SVC" EXIT

    echo -n "  waiting for server..."
    for i in $(seq 1 300); do
      ${pkgs.curl}/bin/curl -sf "$URL/health" > /dev/null 2>&1 && break
      sleep 1
      echo -n "."
    done
    echo " ready"

    model=$(${pkgs.curl}/bin/curl -sf "$URL/v1/models" \
      | ${pkgs.python3}/bin/python3 -c \
        "import sys,json; print(json.load(sys.stdin)['data'][0]['id'])")
    echo "  model: $model"

    ${pkgs.python3}/bin/python3 - \
        "$URL" "$model" "$PROMPT_LENS" "$GEN_TOKENS" "$RUNS" <<'PYEOF'
import sys, json, time, urllib.request, statistics, math

url, model, prompt_lens_str, gen_tokens, runs = (
    sys.argv[1], sys.argv[2], sys.argv[3],
    int(sys.argv[4]), int(sys.argv[5])
)
prompt_lens = [int(x) for x in prompt_lens_str.split(",")]

PREFIX = ("The quick brown fox jumps over the lazy dog. " * 30000)
SUFFIX = (
    "\n\nExplain in detail how speculative decoding accelerates "
    "large language model inference. Describe the role of the draft "
    "model, the verification step, and why the output distribution "
    "is preserved. Include discussion of token acceptance rates and "
    "practical speedup factors on real hardware."
)
_run_counter = [0]

def bench_once(approx_tokens):
    _run_counter[0] += 1
    run_tag = f"[run-{_run_counter[0]}] "
    prefix_chars = max(0, approx_tokens * 4 - len(run_tag) - len(SUFFIX))
    prompt_text = run_tag + PREFIX[:prefix_chars] + SUFFIX
    payload = json.dumps({
        "model": model,
        "messages": [{"role": "user", "content": prompt_text}],
        "max_tokens": gen_tokens,
        "temperature": 0.0,
        "stream": True,
    }).encode()
    req = urllib.request.Request(
        f"{url}/v1/chat/completions",
        data=payload,
        headers={"Content-Type": "application/json"},
    )
    t0 = time.perf_counter()
    ttft = None
    n_tokens = 0
    with urllib.request.urlopen(req) as resp:
        for raw in resp:
            line = raw.decode().strip()
            if not line.startswith("data: "):
                continue
            chunk = line[6:]
            if chunk == "[DONE]":
                break
            data = json.loads(chunk)
            choices = data.get("choices", [])
            if choices:
                delta = choices[0]["delta"].get("content", "")
                if delta:
                    if ttft is None:
                        ttft = time.perf_counter() - t0
                    n_tokens += 1
            usage = data.get("usage") or {}
            if usage.get("completion_tokens"):
                n_tokens = usage["completion_tokens"]
    total = time.perf_counter() - t0
    decode_time = (total - ttft) if ttft else total
    # DFlash batches tokens into SSE events; when all tokens fit in the
    # first event, decode_time ≈ 0 and tps blows up.
    if decode_time < 0.05 or n_tokens < 5:
        decode_tps = float("nan")
    else:
        decode_tps = n_tokens / decode_time
    return approx_tokens, ttft, decode_tps, n_tokens

print(
    f"  {'target':>8}  {'ttft':>8}  {'pp t/s':>8}"
    f"  {'decode t/s':>12}  {'gen':>5}"
)
print(f"  {'-'*8}  {'-'*8}  {'-'*8}  {'-'*12}  {'-'*5}")
for approx in prompt_lens:
    ttfts, tpss = [], []
    actual_gen = gen_tokens
    for _ in range(runs):
        pp, ttft, tps, gen = bench_once(approx)
        actual_gen = gen
        if ttft is not None:
            ttfts.append(ttft)
        if not math.isnan(tps):
            tpss.append(tps)
    med_ttft = statistics.median(ttfts) if ttfts else float("nan")
    med_tps  = statistics.median(tpss) if tpss else float("nan")
    pp_tps   = approx / med_ttft if med_ttft > 0 else 0
    tps_str  = f"{med_tps:>11.1f}" if not math.isnan(med_tps) else "        n/a"
    print(
        f"  {approx:>8}  {med_ttft:>7.3f}s  {pp_tps:>7.0f}"
        f"  {tps_str}  {actual_gen:>5}"
    )
PYEOF

    trap - EXIT
    systemctl stop "$SVC"
  '';

in

{
  environment.systemPackages = [ bench-lucebox bench-lucebox-llm ];
}
