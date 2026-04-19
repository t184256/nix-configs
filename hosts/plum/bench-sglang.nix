{ pkgs, ... }:

let
  bench-sglang = pkgs.writeShellScriptBin "bench-sglang" ''
    set -euo pipefail

    PORT=8002
    URL="http://127.0.0.1:$PORT"

    # Match bench-vllm lengths for a direct comparison.
    PROMPT_LENS_PLAIN="256,8192,16384,32768,65536,131072,196608,256000"
    PROMPT_LENS_DFLASH="256,8192,16384,32768,65536"
    GEN_TOKENS=128
    RUNS=3

    usage() {
      echo "usage: bench-sglang [plain|dflash|both]" >&2
      exit 1
    }

    MODE="''${1:-both}"
    [[ "$MODE" =~ ^(plain|dflash|both)$ ]] || usage

    run_bench() {
      local svc="$1" label="$2"
      echo ""
      echo "## $label"
      systemctl start "$svc"
      trap "systemctl stop $svc" EXIT

      # SGLang JIT-compiles FlashInfer kernels on first start; allow extra time.
      echo -n "  waiting for server..."
      for i in $(seq 1 240); do
        ${pkgs.curl}/bin/curl -sf "$URL/health" > /dev/null 2>&1 && break
        sleep 1
        echo -n "."
      done
      echo " ready"

      local model
      model=$(${pkgs.curl}/bin/curl -sf "$URL/v1/models" \
        | ${pkgs.python3}/bin/python3 -c \
          "import sys,json; print(json.load(sys.stdin)['data'][0]['id'])")

      ${pkgs.python3}/bin/python3 - \
          "$URL" "$model" "$PROMPT_LENS" "$GEN_TOKENS" "$RUNS" \
          "$label" <<'PYEOF'
    import sys, json, time, urllib.request, urllib.error, statistics

    url, model, prompt_lens_str, gen_tokens, runs, label = (
        sys.argv[1], sys.argv[2], sys.argv[3],
        int(sys.argv[4]), int(sys.argv[5]), sys.argv[6]
    )
    prompt_lens = [int(x) for x in prompt_lens_str.split(",")]

    BASE = ("The quick brown fox jumps over the lazy dog. " * 30000)
    _run_counter = [0]

    def bench_once(approx_tokens):
        # Unique prefix busts the sglang prefix cache between runs.
        _run_counter[0] += 1
        prefix = f"[run-{_run_counter[0]}] "
        prompt_text = prefix + BASE[: max(0, approx_tokens * 4 - len(prefix))]
        payload = json.dumps({
            "model": model,
            "messages": [{"role": "user", "content": prompt_text}],
            "max_tokens": gen_tokens,
            "temperature": 0.0,
            "stream": True,
            "stream_options": {"include_usage": True},
        }).encode()
        req = urllib.request.Request(
            f"{url}/v1/chat/completions",
            data=payload,
            headers={"Content-Type": "application/json"},
        )
        t0 = time.perf_counter()
        ttft = None
        n_chunks = 0
        completion_tokens = None
        data = {}
        try:
            with urllib.request.urlopen(req) as resp:
                for raw in resp:
                    line = raw.decode().strip()
                    if not line.startswith("data: "):
                        continue
                    chunk = line[6:]
                    if chunk == "[DONE]":
                        break
                    data = json.loads(chunk)
                    if data.get("usage"):
                        completion_tokens = data["usage"].get(
                            "completion_tokens")
                    choices = data.get("choices", [])
                    if choices:
                        delta = choices[0]["delta"].get("content", "")
                        if delta:
                            if ttft is None:
                                ttft = time.perf_counter() - t0
                            n_chunks += 1
        except urllib.error.HTTPError as e:
            return None, str(e.code)
        total = time.perf_counter() - t0
        prompt_tokens = data.get("usage", {}).get(
            "prompt_tokens", approx_tokens)
        # Detect silent failure: server returned far fewer tokens than sent.
        if prompt_tokens < approx_tokens // 2:
            return None, f"pp={prompt_tokens}"
        decode_time = total - ttft if ttft else total
        # spec-decoding batches multiple tokens per SSE event; use completion_tokens
        n_tokens = completion_tokens if completion_tokens is not None else n_chunks
        decode_tps = n_tokens / decode_time if decode_time > 0 else 0
        return (prompt_tokens, ttft, decode_tps, n_tokens), None

    print(f"  {'target':>8}  {'pp':>6}  {'ttft':>8}  {'pp t/s':>8}"
          f"  {'decode t/s':>12}  {'gen':>5}")
    print(f"  {'-'*8}  {'-'*6}  {'-'*8}  {'-'*8}  {'-'*12}  {'-'*5}")
    for approx in prompt_lens:
        results, errors = [], []
        for _ in range(int(runs)):
            result, err = bench_once(approx)
            if result is None:
                errors.append(err)
            else:
                results.append(result)
        if not results:
            reason = errors[0] if errors else "?"
            print(f"  {approx:>8}  {'N/A':>6}  {'N/A':>8}  {'N/A':>8}"
                  f"  {'N/A':>12}  {reason}")
            continue
        # Use available results even if some runs failed.
        pps   = [r[0] for r in results]
        ttfts = [r[1] for r in results if r[1] is not None]
        tpss  = [r[2] for r in results]
        gens  = [r[3] for r in results]
        actual_pp  = statistics.median(pps)
        actual_gen = statistics.median(gens)
        if not ttfts:
            print(f"  {approx:>8}  {actual_pp:>6.0f}  {'N/A':>8}  {'N/A':>8}"
                  f"  {'N/A':>12}  {actual_gen:>5.0f}")
            continue
        med_ttft = statistics.median(ttfts)
        med_tps  = statistics.median(tpss)
        pp_tps = actual_pp / med_ttft if med_ttft > 0 else 0
        print(f"  {approx:>8}  {actual_pp:>6.0f}  {med_ttft:>7.3f}s"
              f"  {pp_tps:>7.0f}  {med_tps:>11.1f}  {actual_gen:>5.0f}")
    PYEOF

      trap - EXIT
      systemctl stop "$svc"
    }

    case "$MODE" in
      plain)
        PROMPT_LENS="$PROMPT_LENS_PLAIN"
        run_bench sglang "9B AWQ plain (sglang)"
        ;;
      dflash)
        PROMPT_LENS="$PROMPT_LENS_DFLASH"
        run_bench sglang-dflash "9B AWQ + DFlash (sglang)"
        ;;
      both)
        PROMPT_LENS="$PROMPT_LENS_PLAIN"
        run_bench sglang "9B AWQ plain (sglang)"
        PROMPT_LENS="$PROMPT_LENS_DFLASH"
        run_bench sglang-dflash "9B AWQ + DFlash (sglang)"
        ;;
    esac
  '';

in

{
  environment.systemPackages = [ bench-sglang ];
}
