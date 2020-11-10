#$ENABLE_ASYNC_PROMPT = True  # coloring issues
if 'TMUX' in ${...}:
    $PROMPT_FIELDS['title'] = lambda: $PROMPT_FIELDS['current_job']() or 'xonsh'
    $TITLE = '{title}'
    $PROMPT = "{#555}{prompt_end} "
    if $PROMPT_FIELDS['user'] != 'monk':  # TODO: parametrize
        $PROMPT = '{user}@{hostname}' + $PROMPT
    $PROMPT = '{RESET}' + $PROMPT + '{RESET}'

    $RIGHT_PROMPT = '{#555}{short_cwd}'
    if 'WITH_FEATURES' in ${...}:
        fs_all = $WITH_FEATURES.split()
        fs_new = $WITH_FEATURES_IMMEDIATE.split()
        uniq = lambda l: list(dict.fromkeys(l))  # py 3.6, 3.7+
        fs_actually_old = [f for f in fs_all if fs_all.count(f) != fs_new.count(f)]
        fs_actually_new = [f for f in fs_all if fs_all.count(f) == fs_new.count(f)]
        $WITH_FEATURES_OLD = ' '.join(uniq(fs_actually_old))
        $WITH_FEATURES_NEW = ' '.join(uniq(fs_actually_new))
        if $WITH_FEATURES_NEW:
            $RIGHT_PROMPT += ' {#777}{$WITH_FEATURES_NEW}{RESET}'
        if $WITH_FEATURES_OLD:
            $RIGHT_PROMPT += ' {#555}{$WITH_FEATURES_OLD}{RESET}'
        del fs_all, fs_new, fs_actually_new, fs_actually_old, uniq
    $RIGHT_PROMPT += '{gitstatus: {}}{RESET}'
