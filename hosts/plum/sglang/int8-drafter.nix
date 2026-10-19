# Re-quantize a BF16 DFlash2 drafter to per-channel symmetric int8 (w8a8_int8)
# sglang#39087: [Bug] Quantized DFlash2 draft silently yields ~0% acceptance
# Only self_attn.{qkv,o}_proj and mlp.{gate_up,down}_proj are converted.
# qkv/gate_up go out PRE-FUSED: their scales never go through
# stacked_params_mapping, so exact-name lookup works or fails loudly.
# Drafter stops occupying 3.58 GiB that can go towards KV-cache.
# Absolutely do verify that acceptance is higher than 1 afterwards!

{ lib, runCommand, python3 }:

{ base, pname ? "qwen38-27b-dflash2-zlab-int8" }:

runCommand pname { } ''
  mkdir -p $out
  ${python3.withPackages (ps: [ ps.numpy ])}/bin/python \
    ${./int8-drafter.py} ${base}/model.safetensors ${base}/config.json $out
''
