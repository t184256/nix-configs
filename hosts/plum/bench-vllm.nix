{ pkgs, ... }:

# TODO: update with full numbers

# Dual no-NVLink RTX 3090 QuantTrio/Qwen3.6-27B-AWQ:
# --- thinking=True ---
# target      pp      ttft   pp tps   decode tps    gen
#    256     212    0.223s      949        111.8    128
#   8192    6308    4.597s     1372        114.6    128
#  16384   12603    6.931s     1818        109.3    128
#  32768   25192   20.028s     1258        125.5    128
#  65536   50368   42.965s     1172        114.0    128
# 131072  100725   96.381s     1045        102.3    128
# 196608  151080  161.491s      936        106.3    128
# 262144  201436  239.453s      841         98.9    128
# --- thinking=False ---
# target      pp      ttft   pp tps   decode tps    gen
#    256     214    0.229s      935         73.0    128
#   8192    6310    4.755s     1327         61.7    128
#  16384   12605    7.124s     1769         62.4    128
#  32768   25194   20.061s     1256         57.2    128
#  65536   50370   43.072s     1169         58.0    128
# 131072  100727   96.070s     1048         55.4    128
# 196608  151082  162.399s      930         51.7    128
# 262144  201438  239.121s      842         48.2    128

{
  environment.systemPackages = [
    (pkgs.writers.writePython3Bin "bench-vllm" {
      libraries = [ pkgs.python3Packages.openai ];
    } ''
      import statistics
      import time
      from openai import OpenAI

      URL = 'http://192.168.99.53:11111/v1'
      PROMPT_LENS = [256, 8192, 16384, 32768, 65536, 131072, 196608, 262144]
      GEN_TOKENS = 128
      RUNS = 5

      MODEL = 'qwen3.6-27b'
      BASE = """\
      If determinism is true and every event is the inevitable result \
      of prior causes, in what sense can any agent be said to have \
      acted freely or borne genuine moral responsibility? \
      """ * 6000

      client = OpenAI(base_url=URL, api_key='dummy')

      for thinking in [True, False]:
          extra = {'chat_template_kwargs': {'enable_thinking': thinking}}
          print(f'--- {thinking=} ---')
          print('target      pp      ttft   pp tps   decode tps    gen')
          for approx in PROMPT_LENS:
              ttfts, tpss = [], []
              for run in range(RUNS):
                  prefix = f'[run #{run}] '
                  prompt = prefix + BASE[:approx * 4 - len(prefix)]
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
                          elif ttft is None and chunk.choices:
                              ttft = time.perf_counter() - t0
                  total = time.perf_counter() - t0
                  if ttft is None:
                      ttft = total
                  ttfts.append(ttft)
                  tpss.append(usage.completion_tokens / (total - ttft)
                              if total > ttft else float('nan'))
              actual_pp = usage.prompt_tokens
              actual_gen = usage.completion_tokens
              med_ttft = statistics.median(ttfts)
              med_tps = statistics.median(tpss)
              pp_tps = actual_pp / med_ttft
              print(f'{approx:>6}  {actual_pp:>6}  {med_ttft:>7.3f}s  '
                    f'{pp_tps:>7.0f}  {med_tps:>11.1f}  {actual_gen:>5}')
    '')
  ];
}
