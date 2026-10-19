# Re-quantize a BF16 DFlash2 drafter to per-channel symmetric int8 (w8a8_int8)
# sglang#39087: [Bug] Quantized DFlash2 draft silently yields ~0% acceptance
# Only self_attn.{qkv,o}_proj and mlp.{gate_up,down}_proj are converted.
# qkv/gate_up go out PRE-FUSED: their scales never go through
# stacked_params_mapping, so exact-name lookup works or fails loudly.
# Drafter stops occupying 3.58 GiB that can go towards KV-cache.
# Absolutely do verify that acceptance is higher than 1 afterwards!

import json
import mmap
import os
import shutil
import struct
import sys

import numpy as np

SRC_MODEL, SRC_CONFIG, DST = sys.argv[1], sys.argv[2], sys.argv[3]


def bf16_to_f32(buf):
    u = np.frombuffer(buf, dtype=np.uint16)
    return (u.astype(np.uint32) << 16).view(np.float32)


# yields (name, meta, raw_bytes); mmap outlives the closed file
def read_safetensors(path):
    with open(path, 'rb') as fh:
        head_len = struct.unpack('<Q', fh.read(8))[0]
        header = json.loads(fh.read(head_len))
        base = 8 + head_len
        mm = mmap.mmap(fh.fileno(), 0, access=mmap.ACCESS_READ)
        for name, meta in header.items():
            if name == '__metadata__':
                continue
            lo, hi = meta['data_offsets']
            yield name, meta, mm[base + lo : base + hi]


def quantise_per_channel(rows_of_float32):
    '''symmetric int8, one scale per row -> (int8 w, fp32 [rows,1] scale).'''
    w = np.concatenate([r for r in rows_of_float32], axis=0)
    scale = np.maximum(np.abs(w).max(axis=1, keepdims=True) / 127.0, 1e-8)
    q = np.clip(np.round(w / scale), -127, 127).astype(np.int8)
    return q, scale.astype(np.float32)


def to_f32(name):
    meta, blob = all_tensors[name]
    assert meta['dtype'] == 'BF16', (name, meta['dtype'])
    return bf16_to_f32(blob).reshape(meta['shape'])


all_tensors = {name: (meta, blob)
               for name, meta, blob in read_safetensors(SRC_MODEL)}
original_names = set(all_tensors)
layer_ids = sorted({int(name.split('.')[1])
                    for name in original_names
                    if name.split('.')[0] == 'layers'})

SOURCE_PROJECTIONS = (
    'self_attn.q_proj.weight', 'self_attn.k_proj.weight',
    'self_attn.v_proj.weight', 'self_attn.o_proj.weight',
    'mlp.gate_proj.weight', 'mlp.up_proj.weight', 'mlp.down_proj.weight',
)

out_arrays = {}
converted = 0
consumed = set()
for idx in layer_ids:
    pre = f'layers.{idx}.'
    groups = {
        # QKVParallelLinear layout is [q, k, v] on dim 0
        'self_attn.qkv_proj': [
            to_f32(pre + n) for n in (
                'self_attn.q_proj.weight', 'self_attn.k_proj.weight',
                'self_attn.v_proj.weight')],
        'self_attn.o_proj': [to_f32(pre + 'self_attn.o_proj.weight')],
        # MergedColumnParallelLinear shards are [gate, up] in that order
        'mlp.gate_up_proj': [
            to_f32(pre + n) for n in (
                'mlp.gate_proj.weight', 'mlp.up_proj.weight')],
        'mlp.down_proj': [to_f32(pre + 'mlp.down_proj.weight')],
    }
    for mod, parts in groups.items():
        q, s = quantise_per_channel(parts)
        out_arrays[pre + mod + '.weight'] = q
        out_arrays[pre + mod + '.weight_scale'] = s.reshape(-1, 1)
        converted += 1
    for src in SOURCE_PROJECTIONS:
        del all_tensors[pre + src]
        consumed.add(pre + src)

dropped = original_names - consumed - set(all_tensors)
assert not dropped, \
    f'tensors would be silently dropped: {sorted(dropped)[:8]}'
assert not (set(out_arrays) & set(all_tensors)), \
    'source contains pre-fused projection names; refusing to shadow them'

DTYPES = {np.dtype(np.int8): 'I8', np.dtype(np.float32): 'F32'}

header, offset, blobs = {}, 0, []
for name in sorted(set(out_arrays) | set(all_tensors)):
    if name in out_arrays:
        arr = np.ascontiguousarray(out_arrays[name])
        nbytes = arr.nbytes
        header[name] = {'dtype': DTYPES[arr.dtype], 'shape': list(arr.shape),
                       'data_offsets': [offset, offset + nbytes]}
        blobs.append(arr.tobytes())
    else:  # pass through
        meta, blob = all_tensors[name]
        nbytes = len(blob)
        header[name] = {'dtype': meta['dtype'], 'shape': meta['shape'],
                       'data_offsets': [offset, offset + nbytes]}
        blobs.append(bytes(blob))
    offset += nbytes

blob = b''.join(blobs)
head_json = json.dumps(header, separators=(',', ':')).encode('utf-8') + b' '
pad = (-len(head_json)) % 8
head_json = head_json + b' ' * pad

os.makedirs(DST, exist_ok=True)
with open(os.path.join(DST, 'model.safetensors'), 'wb') as fh:
    fh.write(struct.pack('<Q', len(head_json)))
    fh.write(head_json)
    fh.write(blob)
shutil.copyfile(SRC_CONFIG, os.path.join(DST, 'config.json'))
