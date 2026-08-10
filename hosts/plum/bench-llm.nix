{ pkgs, ... }:

# Dual NVLinked RTX 3090 Lorbus/Qwen3.6-27B-int4-AutoRound dflash=7, 250W cap:
# (top MSI GPU: 23G 100% 82°  79% 249W; bottom ASUS GPU: 23G 100% 60°  63% 248W)
# --- thinking=True ---
# target      pp      ttft   pp tps   decode tps    gen
#    256     272    0.180s     1515        174.3    128
#   8192    8201    4.029s     2035        165.0    128
#  16384   16384    8.450s     1939        156.7    128
#  32768   32750   18.742s     1747        159.0    128
#  65536   65481   43.219s     1515        146.7    128
# 131072  130944  108.179s     1210        150.0    128
# 196608  196406  194.972s     1007        113.9    128
# 262144  261676  303.151s      863        108.6    128
# --- thinking=False ---
# target      pp      ttft   pp tps   decode tps    gen
#    256     274    0.189s     1446        105.1    128
#   8192    8203    4.193s     1956         94.4    128
#  16384   16386    8.712s     1881         99.6    128
#  32768   32752   18.839s     1739         92.9    128
#  65536   65483   43.203s     1516         88.2    128
# 131072  130946  108.334s     1209         75.0    128
# 196608  196408  194.862s     1008         71.4    128
# 262144  261678  303.095s      863         62.6    128

{
  environment.systemPackages = [
    (pkgs.writers.writePython3Bin "bench-llm" {
      libraries = [ pkgs.python3Packages.openai ];
    } ''
      import statistics
      import time
      from openai import OpenAI

      URL = 'http://192.168.99.53:11111/v1'
      MAX_MODEL_LEN = 262144
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
