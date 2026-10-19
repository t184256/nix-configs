final: prev:

rec {
  llama-benchy = prev.python3.pkgs.buildPythonApplication {
    pname = "llama-benchy";
    version = "0.4.0";
    src = prev.fetchFromGitHub {
      owner = "eugr";
      repo = "llama-benchy";
      rev = "446dd42fde2ebbaa1d68a0dfe9dc1e5b833f95ad";
      hash = "sha256-M+ijzaJz5XVsFSFvLGHJUic/B4PDcG0mKaTCQ/1ZHJY=";
      leaveDotGit = true;
    };
    postUnpack = "git -C $sourceRoot tag v0.4.0";  # hatch-vcs needs a tag
    pyproject = true;
    nativeBuildInputs = [
      prev.python3.pkgs.hatchling prev.python3.pkgs.hatch-vcs prev.git
    ];
    dependencies = with prev.python3.pkgs; [
      openai tokenizers transformers tabulate numpy requests aiohttp pydantic
    ];
    dontCheckRuntimeDeps = 1;  # skip because of asyncio
    doCheck = false;
  };

  llama-benchy-nice = prev.writers.writePython3Bin "llama-benchy-nice"
    { doCheck = false; }  # skip flake8: store-path interpolation breaks E501
    ''
    import json, statistics, subprocess, sys, tempfile

    args = sys.argv[1:]
    TOKENIZERS = {  # shared Qwen3.8 tokenizer; other values pass through
        'qwen3.8': '${final.qwen38-tokenizer}',
        'qwen3.8-flash-next': '${final.qwen38-tokenizer}',
        'qwen3.8-27b': '${final.qwen38-tokenizer}',
        'lfm2.5': '${final.lfm25-tokenizer}',
    }
    for i, a in enumerate(args):
        if a == '--tokenizer' and args[i + 1] in TOKENIZERS:
            args[i + 1] = TOKENIZERS[args[i + 1]]
    think = None
    for flag in ('--think', '--nothink'):
        if flag in args:
            assert think is None, 'use at most one of --think / --nothink'
            think = flag == '--think'
            args.remove(flag)
    if think is not None:
        val = 'true' if think else 'false'
        args += ['--extra-body',
                 f'chat_template_kwargs={{"enable_thinking": {val}}}']
    if '--tg' not in args:
        args += ['--tg', '1024']  # llama-benchy's own default (32) is too short
    if '--no-exact-tg' in args:  # without it, the speed seems inflated
        args.remove('--no-exact-tg')
    elif '--exact-tg' not in args:  # default to --exact-tg
        args += ['--exact-tg']

    runs = 3
    it = iter(args)
    for a in it:
        if a == '--runs':
            runs = int(next(it))
    args += ['--emit-progress', '-']

    # stderr goes to a tempfile so a chatty failure can't deadlock the
    # stdout pipe; dumped only on failure
    errf = tempfile.TemporaryFile()
    proc = subprocess.Popen(['${llama-benchy}/bin/llama-benchy'] + args,
                            stdout=subprocess.PIPE, stderr=errf, text=True)

    def dump_err():
        errf.seek(0)
        err = errf.read().decode(errors='replace')
        if err:
            sys.stderr.write(err)
            sys.stderr.flush()

    # avg here means "averaged across the entire prompt". then it's median'd
    print('target      pp      ttft   avg pp   decode tps    gen', flush=True)
    start, ttft, groups = {}, {}, {}
    for line in proc.stdout:
        ev = json.loads(line)
        t = ev['type']
        if t == 'request_start':
            start[ev['request_id']] = (ev['prompt_size'], ev['response_size'])
        elif t == 'request_first_token' and ev['request_id'] in start:
            ttft[ev['request_id']] = ev['ttft_s']
        elif t == 'request_end':
            rid = ev['request_id']
            if ev.get('error') or rid not in start or rid not in ttft:
                proc.kill()
                proc.wait()
                print(f"run failed: {ev.get('error', 'missing event')}",
                      file=sys.stderr, flush=True)
                dump_err()
                sys.exit(1)
            key = start.pop(rid)
            groups.setdefault(key, []).append(
                (ttft[rid], ev['prompt_tokens'], ev['total_tokens'],
                 ev['decode_seconds']))
            if len(groups[key]) >= runs:
                rs = groups[key]
                med_ttft = statistics.median(r[0] for r in rs)
                med_pp = statistics.median(r[1] / r[0] for r in rs)
                med_dec = statistics.median(r[2] / r[3] for r in rs if r[3])
                med_gen = statistics.median(r[2] for r in rs)
                med_ptok = statistics.median(r[1] for r in rs)
                print(f'{key[0]:>6}  {med_ptok:>6.0f}  {med_ttft:>7.3f}s  '
                      f'{med_pp:>7.0f}  {med_dec:>11.1f}  {med_gen:>5.0f}',
                      flush=True)
        elif t == 'bench_complete':
            break
    rc = proc.wait()
    if rc != 0:
        dump_err()
    sys.exit(rc)
  '';
}
