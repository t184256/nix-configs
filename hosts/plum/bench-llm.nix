{ pkgs, ... }:

# Dual NVLinked RTX 3090 Qwen3.8-27B-Q8_0 + MTP Q8, llama.cpp 10313
# (top MSI GPU: 22G 100% 93°  77% 236W; bottom ASUS GPU: 23G 100% 81°  57% 238W)

# bench-llm --think
# target      pp      ttft   pp tps   decode tps    gen
#    256     256    0.556s      462         75.4    491
#   8192    8192    5.768s     1420         72.2    413
#  16384   16384   11.338s     1445         71.0    584
#  32768   32768   23.406s     1400         69.1    426
#  65536   65536   51.859s     1264         60.4    640
# 131072  131072  127.001s     1032         49.6    353
# 196608  196608  227.821s      863         38.5    319
# 261088  261088  350.095s      746         36.7    307

# bench-llm --nothink:
# target      pp      ttft   pp tps   decode tps    gen
#    256     257    0.567s      454         70.1    173
#   8192    8193    5.778s     1418         63.0    120
#  16384   16385   11.310s     1449         63.8     90
#  32768   32769   23.391s     1401         64.9    474
#  65536   65537   51.857s     1264         57.0    384
# 131072  131074  126.775s     1034         45.9    229
# 196608  196609  227.021s      866         42.6    169
# 261088  261089  350.926s      744         35.8     91

{
  environment.systemPackages = [
    # bench-llm [--think|--nothink] [llama-benchy args...]
    (pkgs.writeShellScriptBin "bench-llm" ''
      exec ${pkgs.llama-benchy-nice}/bin/llama-benchy-nice \
        --base-url http://192.168.99.53:11111/v1 \
        --model qwen3.8-27b \
        --tokenizer qwen3.8 \
        --pp 256 8192 16384 32768 65536 131072 196608 261088 \
        --tg 1024 --runs 5 --no-cache \
        "$@"
    '')
  ];
}
