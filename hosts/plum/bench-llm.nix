{ pkgs, ... }:

# Dual NVLinked RTX 3090 Qwen3.8 MTP Q8_0, llama.cpp 10313
# (top MSI GPU: 22G 100% 93°  77% 236W; bottom ASUS GPU: 23G 100% 81°  57% 238W)
# --- thinking=True ---
# target      pp      ttft   pp tps   decode tps    gen
#    256     314    0.710s      442         76.6    128
#   8192    8243    5.873s     1403         74.6    128
#  16384   16426   11.417s     1439         72.4    128
#  32768   32792   23.680s     1385         66.7    128
#  65536   65523   52.375s     1251         63.8    128
# 131072  130986  128.916s     1016         49.6    128
# 196608  196448  229.412s      856         43.8    128
# 262144  261718  364.521s      718         36.6    128
# --- thinking=False ---
# target      pp      ttft   pp tps   decode tps    gen
#    256     274    0.461s      594         79.1    128
#   8192    8203    5.605s     1464         69.1    128
#  16384   16386   11.129s     1472         70.6    128
#  32768   32752   23.266s     1408         63.8    128
#  65536   65483   52.007s     1259         56.5    128
# 131072  130946  128.582s     1018         45.6    128
# 196608  196408  227.544s      863         37.1    128
# 262144  261678  361.478s      724         34.3    128

{
  environment.systemPackages = [
    (pkgs.writers.writePython3Bin "bench-llm"
      {
        libraries = [ pkgs.python3Packages.openai ];
      }
      ''
        import statistics
        import time
        from openai import OpenAI

        URL = 'http://192.168.99.53:11111/v1'
        MAX_MODEL_LEN = 262144
        PROMPT_LENS = [256, 8192, 16384, 32768, 65536, 131072, 196608, 262144]
        GEN_TOKENS = 128
        RUNS = 5

        MODEL = 'qwen3.8-27b'
        BASE = """\
        If determinism is true and every event is the inevitable result \
        of prior causes, in what sense can any agent be said to have \
        acted freely or borne genuine moral responsibility? \
        """ * 8000

        client = OpenAI(base_url=URL, api_key='dummy')

        for thinking in [True, False]:
            extra = {'chat_template_kwargs': {'enable_thinking': thinking}}
            print(f'--- {thinking=} ---')
            print('target      pp      ttft   pp tps   decode tps    gen')
            for approx in PROMPT_LENS:
                ttfts, tpss = [], []
                for run in range(RUNS):
                    prefix = f'[approx={approx} run #{run}] '
                    tgt = min(approx, MAX_MODEL_LEN - GEN_TOKENS - 64)
                    prompt = prefix + BASE[:tgt * 26 // 5 - len(prefix)]
                    t0 = time.perf_counter()
                    ttft = None
                    with client.chat.completions.create(
                        model=MODEL,
                        messages=[{'role': 'user', 'content': prompt}],
                        max_tokens=GEN_TOKENS, temperature=0.0,
                        stream=True, stream_options={'include_usage': True},
                        extra_body=extra,
                    ) as stream:
                        for chunk in stream:
                            if chunk.usage:
                                usage = chunk.usage
                            elif chunk.choices:
                                d = chunk.choices[0].delta
                                if d.content or \
                                        getattr(d, 'reasoning_content', None) or \
                                        getattr(d, 'reasoning', None):
                                    if ttft is None:
                                        ttft = time.perf_counter() - t0
                    total = time.perf_counter() - t0
                    if ttft is None:
                        ttft = total
                    ttfts.append(ttft)
                    decode_t = total - ttft
                    tpss.append(usage.completion_tokens / decode_t
                                if decode_t > 0 else float('nan'))
                actual_pp = usage.prompt_tokens
                actual_gen = usage.completion_tokens
                med_ttft = statistics.median(ttfts)
                med_tps = statistics.median(tpss)
                pp_tps = actual_pp / med_ttft
                print(f'{approx:>6}  {actual_pp:>6}  {med_ttft:>7.3f}s  '
                      f'{pp_tps:>7.0f}  {med_tps:>11.1f}  {actual_gen:>5}')
      ''
    )
  ];
}
