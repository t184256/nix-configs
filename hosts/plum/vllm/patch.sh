#!/bin/bash
# Apply the Ampere (sm_86) changes of peaster/inkling-2-mini-vllm-2x3090 to
# the vllm/vllm-openai:inkling-2-mini image at container start, the way the
# sglang setup applies hicache-cap.patch:
#
#   * swap the Blackwell-only _C / _moe_C extensions for general-arch
#     builds (the per-commit wheel of the base image's vLLM commit)
#   * the five anchored source edits (patches/apply_sm86_patch.py)
#   * the sm_86 tuning patch (patches/sm86-tune.diff, fuzz 0)
#   * effort-budget.diff: per-level thinking budgets for the named
#     reasoning_effort levels (fuzz 0)
#   * py_compile of the touched files
#
# Idempotent via a marker file, so a systemd restart of the same container
# does not re-apply. All inputs are mounted from the store; no network.
#
# usage: patch.sh <site-packages dir> <sm86 dir>

set -Eeuo pipefail; shopt -s inherit_errexit

site=$1
sm86=$2

[ -f "$site/.sm86-patched" ] && exit 0
[ -d "$site/vllm/models/inkling2" ] || {
    echo "no inkling2 model in $site" >&2
    exit 1
}

expected=0.1.dev25855+g7cb5dae22.cu130
installed=$(python3 -c \
  'import importlib.metadata; print(importlib.metadata.version("vllm"))')
if [ "$installed" != "$expected" ]; then
    echo "vllm $installed != $expected (kernels matched against that build)" >&2
    exit 1
fi

for lib in _C_stable_libtorch.abi3.so _moe_C_stable_libtorch.abi3.so; do
    [ -f "$site/vllm/$lib" ] || {
        echo "missing $site/vllm/$lib" >&2
        exit 1
    }
    if ! cmp -s "$sm86/libs/$lib" "$site/vllm/$lib"; then
        [ -f "$site/vllm/$lib.orig" ] ||
            cp -p "$site/vllm/$lib" "$site/vllm/$lib.orig"
        cp "$sm86/libs/$lib" "$site/vllm/$lib"
        echo "replaced vllm/$lib"
    fi
done

install -m 0644 "$sm86/patches/draft_vocab_rank.json" \
    "$site/vllm/models/inkling2/draft_vocab_rank.json"

python3 "$sm86/patches/apply_sm86_patch.py" "$site"
patch -p1 --fuzz=0 -d "$site" < "$sm86/patches/sm86-tune.diff"
patch -p1 --fuzz=0 -d "$site" < "$sm86/patches/effort-budget.diff"

# the sources the anchored edits and the tuning patch touch
for f in \
    vllm/models/inkling2/quant_config.py \
    vllm/models/inkling2/nvidia/ops/conv_mix.py \
    vllm/models/inkling2/nvidia/ops/linear.py \
    vllm/models/inkling2/nvidia/vision.py \
    vllm/models/inkling2/nvidia/attention.py \
    vllm/models/inkling2/nvidia/dspark.py \
    vllm/models/inkling2/speculator.py \
    vllm/models/inkling2/nvidia/ops/sconv.py \
    vllm/models/inkling/nvidia/sconv_swa_attn.py \
    vllm/models/inkling2/nvidia/loop.py \
    vllm/models/inkling2/nvidia/ops/gemv.py \
    vllm/models/inkling2/nvidia/ops/moe_sm90.py \
    vllm/models/inkling2/nvidia/ops/moe_align_small.py \
    vllm/models/inkling2/nvidia/ops/attention_sm90.py \
    vllm/v1/core/sched/scheduler.py \
    vllm/v1/spec_decode/dynamic/adaptive_k.py \
    triton/language/extra/cuda/gdc.py \
    triton/backends/nvidia/compiler.py \
    vllm/entrypoints/openai/chat_completion/protocol.py
do
    python3 -m py_compile "$site/$f"
done

touch "$site/.sm86-patched"
echo "sm86: patched"
