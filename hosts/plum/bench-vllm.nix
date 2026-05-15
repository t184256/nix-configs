{ pkgs, ... }:

# TODO: update with full numbers

# Dual no-NVLink RTX 3090 QuantTrio/Qwen3.6-27B-AWQ:
# --- thinking=True ---
# target      pp      ttft   pp tps   decode tps    gen
#    256     273    0.268s     1017        124.3    128
#   8192    8161    5.930s     1376        131.7    128
#  16384   16305   12.193s     1337        128.2    128
#  32768   32591   26.544s     1228        124.2    128
#  65536   65165   57.509s     1133        109.8    128
# 131072  130309  133.808s      974        107.8    128
# 196608  195455  229.606s      851         81.3    128
# 262144  260600  345.051s      755         77.4    128
# --- thinking=False ---
# target      pp      ttft   pp tps   decode tps    gen
#    256     275    0.333s      825         66.4    128
#   8192    8163    6.157s     1326         71.4    128
#  16384   16307   12.613s     1293         71.7    128
#  32768   32593   26.499s     1230         63.8    128
#  65536   65167   57.129s     1141         58.4    128
# 131072  130311  132.796s      981         53.9    128
# 196608  195457  229.770s      851         52.4    128
# 262144  260602  345.413s      754         40.5    128

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
                  prompt = prefix + BASE[:approx * 27 // 5 - len(prefix)]
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
                              if d.content or getattr(d, 'reasoning', None):
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
    '')
  ];
}
