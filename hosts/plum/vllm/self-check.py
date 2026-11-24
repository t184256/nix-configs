# catch stuff that goes quietly wrong despite the engine starting fine

import random
import textwrap
import time

import requests

URL = 'http://192.168.99.53:11111'
MODEL = 'inkling-2-mini'
MAX_TOKENS = 8192   # counts against max_model_len along with the history
MAX_MODEL_LEN = 307200   # vllm serves no /get_server_info to read this from


def flat(s):
    s = textwrap.dedent(s).strip()
    prose, sep, code = s.partition('\n\n')
    return ' '.join(prose.splitlines()) + sep + code


def blob(tokens, seed):
    words = '''
      araceae bayroot carambola cocoa coconut cookie duckweed etrog grapefruit
      intermezzo iyokan jujube loquat lychee plum quince sloe spondias
      watermelon
    '''.split()  # ~2 tokens per word
    return ' '.join(random.Random(seed).choice(words) for _ in range(tokens))


def chat(prompt, max_tokens=1200, extra=None):
    body = {'model': MODEL,
            'messages': [{'role': 'user', 'content': prompt}],
            'max_tokens': max_tokens, 'temperature': 0}
    body.update(extra or {})
    return requests.post(URL + '/v1/chat/completions', json=body,
                         timeout=120).json()


class Convo:
    def __init__(self, body):
        self.body = body
        self.msgs = []

    def ask(self, content):
        msgs = self.msgs + [{'role': 'user', 'content': content}]
        start = time.perf_counter()
        r = requests.post(URL + '/v1/chat/completions',
                          json={'model': MODEL, 'messages': msgs,
                                **self.body}, timeout=120)
        r.raise_for_status()  # hitting the context ceiling here is a failure
        out = r.json()
        dt = time.perf_counter() - start
        reply = out['choices'][0]['message']['content'] or ''
        self.msgs = msgs + [{'role': 'assistant', 'content': reply}]
        u = out['usage']
        cached = (u.get('prompt_tokens_details') or {}).get('cached_tokens', 0)
        return (u['prompt_tokens'], cached, u['prompt_tokens'] - cached,
                dt, u['total_tokens'])


def metric_lines():
    return requests.get(URL + '/metrics', timeout=60).text.splitlines()


def tiers(lines=None):
    # prefix-cache hits per tier; the offload byte series below only exists at
    # all when a kv connector is loaded, so it doubles as the presence probe
    return {line.split('source="')[1].split('"')[0]:
            float(line.rsplit(' ', 1)[1])
            for line in (lines if lines is not None else metric_lines())
            if line.startswith('vllm:prompt_tokens_cached_by_source_total{')}


def offload_bytes(lines=None):
    return {line.split('transfer_type="')[1].split('"')[0]:
            float(line.rsplit(' ', 1)[1])
            for line in (lines if lines is not None else metric_lines())
            if line.startswith('vllm:kv_offload_total_bytes_total{')}


def check_pool():
    # check that pool size didn't dip without us noticing + a bit more
    print('[pool]', flush=True)
    pool_floor = 440000
    lines = metric_lines()
    info = next(
        line for line in lines
        if line.startswith('vllm:cache_config_info{'))
    cfg = {k: v.strip('"') for k, v in
           (p.split('=', 1) for p in info.split('{')[1].split('}')[0]
            .split(','))}
    off = offload_bytes(lines)
    print(f'    pool={int(cfg["kv_cache_size_tokens"])} tokens, prefix '
          f'caching={cfg["enable_prefix_caching"]}, '
          f'cpu tier={"yes" if off else "no"}')
    print('    cached by tier:',
          ' '.join(f'{k}={v:.0f}' for k, v in sorted(tiers(lines).items())))
    assert int(cfg['kv_cache_size_tokens']) >= pool_floor, \
        f'{cfg["kv_cache_size_tokens"]} < {pool_floor}: something ate KV'
    assert cfg['enable_prefix_caching'] == 'True', 'prefix caching is off'
    assert off, 'the CPU kv tier is not configured'


def check_accept():
    print('[accept]', flush=True)
    accept_floor = 2.0  # healthy = ~2.4-2.6, dead drafter = 1.0
    prompts = [
        ('why-tp', flat('''
            Explain precisely why tensor parallelism over NVLink
            beats layer splitting for a dense 27B model.
            Give three bullet points, one summary sentence.
        ''')),
        ('refactor', flat('''
            Refactor this Python into a generator that streams results,
            keeping behaviour identical, and explain each change:

            def collect(items):
                out = []
                for i in items:
                    if i % 2 == 0:
                        out.append(i*i)
                return out
        ''')),
    ]
    lengths = []
    for name, text in prompts:
        out = chat(text, 1024)
        spec = (out.get('metrics') or {}).get('speculative_decoding')
        if spec is None:
            raise AssertionError('needs --per-request-spec-decode-metrics')
        aln = round(float(spec['mean_acceptance_length']), 3)
        art = round(float(spec['draft_acceptance_rate']), 3)
        lengths.append(aln)
        print(f'    {name} accept_len={aln} rate={art} '
              f'ct={out["usage"]["completion_tokens"]}')
    mean = sum(lengths) / len(lengths)
    print(f'    mean={mean:.3f} floor={accept_floor:.2f}')
    assert mean >= accept_floor, f'{mean:.3f} < {accept_floor:.2f}'


def check_nothink():
    # a thinking budget must actually cap thinking; budget 0 only makes the
    # model ramble without ever answering, 8 is the least that still answers
    print('[nothink]', flush=True)
    out = chat('What is 17 * 23? Answer with just the number.', 512,
               {'thinking_token_budget': 8})
    msg = out['choices'][0]['message']
    think = out['usage']['completion_tokens_details'].get('reasoning_tokens')
    answer = (msg['content'] or '').strip()
    print(f'    answer={answer[:40]!r}')
    assert think is not None and think <= 8, f'thinking={think}'
    assert answer, f'answer={answer!r}'


def check_effort():
    # reasoning_effort caps are applied by the server (effort-budget.diff);
    # request by name only, observe the cap, check that it landed.
    # the prompt is intentionally heavy to push the limits.
    print('[effort]', flush=True)
    think_prompt = flat('''
        Answer every one of the following. For each item: restate what is
        asked, solve it step by step, then check the result with a second
        independent method, and only then move to the next item. Number your
        final answers.

        1. A snail covers the first half of a route at 64 km/h
           and must average 128 km/h overall.
           What speed is needed for the second half?
        2. Compound interest: 1000 at 7% for 9 years, quarterly.
        3. Probability that 3d20 sum is prime, given it's >30?
        4. Compute 7^2024 mod 1000 by repeated squaring, show each step.
    ''') + '\n'
    # server budgets: minimal 2048, low 4096, medium 8192, high 16384
    # (cap + headroom)
    lim = {'minimal': (1024, 3072),
           'low': (3072, 6144),
           'medium': (6144, 12288),
           'high': (12288, 24576)}
    for effort, (lo, hi) in lim.items():
        r = requests.post(URL + '/v1/chat/completions', json={
            'model': MODEL, 'messages': [{'role': 'user',
                                          'content': think_prompt}],
            'max_tokens': 32768, 'temperature': 0,
            'chat_template_kwargs': {'reasoning_effort': effort,
                                     'enable_thinking': True}
        }, timeout=600)
        r.raise_for_status()
        n = r.json()['usage']['completion_tokens_details']['reasoning_tokens']
        print(f'    {effort}: reasoning_tokens={n}', flush=True)
        assert lo < n < hi, f'{effort} n={n} !~ {lo}..{hi}'


def check_prefix():
    # conversation reuse shows up in usage (--enable-prompt-tokens-details)
    print('[prefix]', flush=True)
    prefix_min_hit_ratio = 0.95  # a warm prompt should come back reused
    text = blob(2000, 20261019) + '\n\nReply with the single word: ok'
    chat(text, 8)  # warm the prefix cache
    out = chat(text, 8)
    u = out['usage']
    ptok = int(u['prompt_tokens'])
    cached = int((u.get('prompt_tokens_details') or {})
                 .get('cached_tokens', 0))
    ratio = cached / ptok if ptok else 0.0
    print(f'    prompt_tokens={ptok} cached_tokens={cached} '
          f'({100 * ratio:.0f}% reused)')
    assert ratio >= prefix_min_hit_ratio, f'{cached}/{ptok} cached'


def check_grow_then_fork():
    # grow in varied chunks until 48k is passed, then fork from older snapshots
    print('[grow-then-fork]', flush=True)
    tip_slack = 256  # vllm caches whole blocks, so anchors land block-aligned
    max_fork_time = 1  # rewinds are instant when reuse works

    def budget(added):
        return -(-added // 1000)  # ~1000 tps prefill

    words = blob(128000, f'fork-{time.time_ns()}').split(' ')
    convo = Convo({'max_tokens': 64, 'temperature': 0})
    snapshots = []
    prev = 0
    pos, width = 0, 1000
    while pos < len(words):
        p, cached, uncached, dt, _ = convo.ask(
            ' '.join(words[pos:pos + width]))
        pos += width
        added = p - prev
        limit = budget(added)
        snapshots.append((p, len(convo.msgs)))
        print(f'    prompt={p:<9}cached={cached:>5} '
              f'uncached={max(0, uncached - added):>2}+{added:>5} '
              f't={dt:.1f}s<{limit:.1f}s', flush=True)
        assert uncached - added <= tip_slack, \
            f'tip unprotected: uncached={uncached} added={added}'
        assert dt <= limit, f'growth {dt:.1f}s > {limit:.1f}s'
        prev = p
        if p >= 80000:
            break
        width += 3777

    tip = prev  # rewinds: fork at every snapshot, earliest-first
    for p0, n in sorted(snapshots):
        fork = Convo(convo.body)
        fork.msgs = convo.msgs[:n]
        p, cached, uncached, dt, _ = fork.ask(
            'Which fruit sounds most like a place?'
        )
        fresh = p - p0  # reply tail + question, exact again
        # block-aligned anchors may cover a few tokens past their mark
        missed = max(0, uncached - fresh)
        print(f'    rewind={p0:>5}+{fresh} cached={cached:>5} '
              f'uncached={missed:>2}+{fresh:<5} '
              f't={dt:.1f}s<{max_fork_time:.1f}s', flush=True)
        assert uncached - fresh <= tip_slack, f'hole at {tip - p0}'
        assert dt <= max_fork_time, f'fork took {dt:.1f}s'


def check_switch():
    # flipping between two conversations must not re-prefill (RAM cache works)
    print('[switch]', flush=True)
    step = 8 * 1024
    # a turn costs its question plus the completion on top of the depth it
    # starts from, so leave room under max_model_len for both threads.
    min_sum_depth = 550 * 1024  # must push beyond GPU pool and stay within cap
    stop = min_sum_depth // 2
    max_slowdown_to_base = 10
    max_slowdown_to_prev = 5
    min_reuse_coefficient = 0.90
    ctx = MAX_MODEL_LEN
    tiers0, off0 = tiers(), offload_bytes()
    convos = [Convo({'max_tokens': MAX_TOKENS}) for _ in range(2)]
    depths, grow = [0, 0], [0, 0]  # grow: cost of a turn, learned as we go
    bases = []
    for i in range(2):
        for j, convo in enumerate(convos):
            q = blob(step, f'{j}-open' if i == 0 else f'{j}-{i}')
            _, _, _, dt, total = convo.ask(q)
            grow[j] = max(grow[j], total - depths[j])
            depths[j] = total
            print(f'    +{dt:4.1f}s {i}/4: warmed up to {sum(depths)}...',
                  flush=True)
            bases.append(dt)
    base_dt = sorted(bases)[len(bases) // 2]
    print(f'    baseline step duration = {base_dt:.1f}s', flush=True)
    prev_dt = base_dt
    for i in range(100500):
        # a thread is done when deep enough, or when its next question plus the
        # completion would no longer fit under max_model_len
        stuck = [d >= stop or d + g + MAX_TOKENS > ctx
                 for d, g in zip(depths, grow)]
        if all(stuck):
            break
        for j, convo in enumerate(convos):
            if stuck[j]:
                continue
            p, _, uncached, dt, total = convo.ask(blob(step, f'{j}-{i}'))
            added = p - depths[j]
            grow[j] = max(grow[j], added)
            history = depths[j]  # what could be reused
            reuse = (p - uncached) / history if history else 1.0
            depths[j] = total
            print(f'    +{dt:4.1f}s: sum={sum(depths)} depth{j}={total:6d} '
                  f'reuse={100 * reuse:5.2f}% uncached={uncached:5d}',
                  flush=True)
            assert uncached <= added + history * (1 - min_reuse_coefficient), (
                f'convo {j} re-read history at {p}: uncached {uncached} of '
                f'{added} added, reused {100 * reuse:.1f}%')
            assert dt < prev_dt * max_slowdown_to_prev, \
                f'convo {j}: {max_slowdown_to_prev}x slower than previous turn'
            assert dt < base_dt * max_slowdown_to_base, \
                f'convo {j}: {max_slowdown_to_base}x slower than baseline'
            prev_dt = dt
    assert sum(depths) >= min_sum_depth, (
        f'did not get to {min_sum_depth}: {depths}')
    off = offload_bytes()
    down = off['GPU_to_CPU'] - off0['GPU_to_CPU']
    up = off['CPU_to_GPU'] - off0['CPU_to_GPU']
    host = tiers()['host'] - tiers0['host']
    print(f'    cpu tier: evicted {down / 2**30:.1f} GiB, reloaded '
          f'{up / 2**30:.1f} GiB, hits {host:.0f} tokens', flush=True)
    assert host > 0, ('the CPU tier served nothing: this workload fits in '
                      'the GPU pool')


check_pool()
check_accept()
check_nothink()
check_grow_then_fork()
check_effort()
check_prefix()
check_switch()
print('PASS')
