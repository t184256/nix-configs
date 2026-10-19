# catch stuff that goes quietly wrong despite the engine starting fine

import random
import textwrap
import time

import requests

URL = 'http://192.168.99.53:11111'
MODEL = 'qwen3.8-27b'
MAX_TOKENS = 8192   # counts against context_length along with the history


def flat(s):
    s = textwrap.dedent(s).strip()
    prose, sep, code = s.partition('\n\n')
    return ' '.join(prose.splitlines()) + sep + code


def blob(tokens, seed):
    words = '''
      araceae bayroot carambola cocoa coconut cookie duckweed etrog grapefruit
      intermezzo iyokan jujube loquat lychee olosapo plum quince sloe spondias
      watermelon
    '''.split()  # ~2 tokens per word
    return ' '.join(random.Random(seed).choice(words) for _ in range(tokens))


def generate(text, max_new=256):
    body = {'text': text + '\n\n',
            'sampling_params': {'max_new_tokens': max_new, 'temperature': 0},
            'return_meta_info': True}
    return requests.post(URL + '/generate', json=body, timeout=120).json()


def chat(prompt, max_tokens=1200, extra=None):
    body = {'model': MODEL,
            'messages': [{'role': 'user', 'content': prompt}],
            'max_tokens': max_tokens, 'temperature': 0}
    body.update(extra or {})
    return requests.post(URL + '/v1/chat/completions', json=body,
                         timeout=120).json()['choices'][0]['message']


def think_chars(msg):
    val = msg['reasoning_content']
    return len(val) if isinstance(val, str) else 0


def _conversation(prompt):
    msgs = [{'role': 'user', 'content': prompt}]
    while True:
        start = time.perf_counter()
        r = requests.post(URL + '/v1/chat/completions', json={
            'model': MODEL, 'messages': msgs,
            'max_tokens': MAX_TOKENS}, timeout=120)
        r.raise_for_status()  # hitting the context ceiling here is a failure
        out = r.json()
        dt = time.perf_counter() - start
        reply = out['choices'][0]['message']['content'] or ''
        msgs.append({'role': 'assistant', 'content': reply})
        u = out['usage']
        cached = (u.get('prompt_tokens_details') or {}).get('cached_tokens', 0)
        q = yield (reply, u['prompt_tokens'], u['prompt_tokens'] - cached,
                   dt, u['total_tokens'])
        msgs.append({'role': 'user', 'content': q})


def check_pool():
    # check that pool size didn't dip without us noticing + a bit more
    print('[pool]', flush=True)
    pool_floor = 290000
    info = requests.get(URL + '/get_server_info', timeout=60).json()
    pool = int(info['max_total_num_tokens'])
    algo = info['speculative_algorithm']
    print(f'    pool={pool} tokens, speculative_algorithm={algo}')
    assert pool >= pool_floor, (f'{pool} < {pool_floor}: something ate KV')
    assert algo == 'DFLASH', f'{algo} != DFLASH'


def check_accept():
    print('[accept]', flush=True)
    accept_floor = 2.5  # healthy = ~3.7-4.3, dead drafter = 1.0
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
        meta = generate(text)['meta_info']
        aln = round(float(meta['spec_accept_length']), 3)
        art = round(float(meta['spec_accept_rate']), 3)
        lengths.append(aln)
        print(f'    {name} accept_len={aln} rate={art} '
              f'ct={meta["completion_tokens"]}')
    mean = sum(lengths) / len(lengths)
    print(f'    mean={mean:.3f} floor={accept_floor:.2f}')
    assert mean >= accept_floor, f'{mean:.3f} < {accept_floor:.2f}'


def check_nothink():
    # enable_thinking=false must actually stop thinking
    print('[nothink]', flush=True)
    msg = chat('What is 17 * 23? Answer with just the number.', 128,
               {'chat_template_kwargs': {'enable_thinking': False}})
    answer = (msg['content'] or '').strip()
    print(f'    answer={answer[:40]!r}')
    if 'reasoning_content' in msg:
        assert not msg['reasoning_content'], f'{msg["reasoning_content"]!r}'
    assert answer, f'answer={answer!r}'


def check_effort():
    # reasoning_effort must produce thinking
    print('[effort]', flush=True)
    think_prompt = flat('''
        Answer every one of the following. For each item:
        restate what is asked, solve it step by step,
        then check the result with a second independent method,
        and only then move to the next item. Number your final answers.

        1. A snail covers the first half of a route at 64 km/h
           and must average 128 km/h overall.
           What speed is needed for the second half?
        2. Compound interest: 1000 at 7% for 9 years, quarterly.
           Give the amount.
        3. Two six-sided dice: probability that the sum is prime
           given it is greater than 4?
    ''') + '\n'
    # must stay >= 16384 or high clips down into medium's band
    lim = {'low': (2000, 4400), 'medium': (4500, 13000),
           'high': (13500, 33000)}
    for effort, (lo, hi) in lim.items():
        r = requests.post(URL + '/v1/chat/completions', json={
            'model': MODEL, 'messages': [{'role': 'user',
                                          'content': think_prompt}],
            'max_tokens': 16384, 'temperature': 0,
            'chat_template_kwargs': {'reasoning_effort': effort,
                                     'enable_thinking': True}}, timeout=600)
        r.raise_for_status()
        n = r.json()['usage']['reasoning_tokens']
        print(f'    {effort}: reasoning_tokens={n}', flush=True)
        assert lo < n < hi, f'{effort} n={n} !~ {lo}..{hi}'


def check_prefix():
    # conversation reuse is visible in the counters (--enable-cache-report)
    print('[prefix]', flush=True)
    prefix_min_hit_ratio = 0.95  # a warm prompt should come back reused
    text = blob(2000, 20261019) + '\n\nReply with the single word: ok'
    generate(text, max_new=8)  # warm the radix cache
    meta = generate(text, max_new=8)['meta_info']
    ptok = int(meta['prompt_tokens'])
    cached = int(meta['cached_tokens'])
    ratio = cached / ptok if ptok else 0.0
    print(f'    prompt_tokens={ptok} cached_tokens={cached} '
          f'({100 * ratio:.0f}% reused)')
    assert ratio >= prefix_min_hit_ratio, f'{cached}/{ptok} cached'


def check_switch():
    # flipping between two conversations must not re-prefill (RAM cache works)
    print('[switch]', flush=True)
    step = 8 * 1024
    # two threads top out near 230.6k each: a turn costs its question plus the
    # completion on top of the depth it starts from, so leave room under that
    min_sum_depth = 448 * 1024
    stop = min_sum_depth // 2
    ctx = int(requests.get(URL + '/get_server_info',
                           timeout=60).json()['context_length'])
    max_slowdown_to_base = 10
    max_slowdown_to_prev = 5
    min_reuse_coefficient = 0.90
    convos = [_conversation(blob(step, f'{j}-open')) for j in range(2)]
    depths, grow = [0, 0], [0, 0]  # grow: cost of a turn, learned as we go
    bases = []
    for i in range(2):
        for j, convo in enumerate(convos):
            _, _, _, dt, total = (next(convo) if i == 0 else
                                  convo.send(blob(step, f'{j}-{i}')))
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
        # completion would no longer fit under context_length
        stuck = [d >= stop or d + g + MAX_TOKENS > ctx
                 for d, g in zip(depths, grow)]
        if all(stuck):
            break
        for j, convo in enumerate(convos):
            if stuck[j]:
                continue
            _, p, uncached, dt, total = convo.send(blob(step, f'{j}-{i}'))
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


check_pool()
check_accept()
check_nothink()
check_effort()
check_prefix()
check_switch()
print('PASS')
