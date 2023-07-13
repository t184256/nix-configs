#$ENABLE_ASYNC_PROMPT = True  # coloring issues
if 'TMUX' in ${...}:
    class MyCurrentJobField($PROMPT_FIELDS["current_job"].__class__):
        def update(self, ctx):
            super().update(ctx)
            self.value = self.value or 'xonsh'
    $PROMPT_FIELDS["current_job"] = MyCurrentJobField()
    $TITLE = '{current_job}'
    $PROMPT = "{#555}$ "
    if $PROMPT_FIELDS['user'] not in ('monk', 'nix-on-droid', 'asosedki'):
        $PROMPT = '{user}@{hostname}' + $PROMPT
    $PROMPT = '{RESET}' + $PROMPT + '{RESET}'

    $RIGHT_PROMPT = ''
    if 'WITH_FEATURES' in ${...}:
        fs_all = $WITH_FEATURES.split()
        fs_new = $WITH_FEATURES_IMMEDIATE.split()
        uniq = lambda l: list(dict.fromkeys(l))  # py 3.6, 3.7+
        fs_actually_old = [f for f in fs_all if fs_all.count(f) != fs_new.count(f)]
        fs_actually_new = [f for f in fs_all if fs_all.count(f) == fs_new.count(f)]
        $WITH_FEATURES_OLD = ' '.join(uniq(fs_actually_old))
        $WITH_FEATURES_NEW = ' '.join(uniq(fs_actually_new))
        if $WITH_FEATURES_NEW:
            $RIGHT_PROMPT += '{#777}{$WITH_FEATURES_NEW}{RESET} '
        if $WITH_FEATURES_OLD:
            $RIGHT_PROMPT += '{#555}{$WITH_FEATURES_OLD}{RESET} '
        del fs_all, fs_new, fs_actually_new, fs_actually_old, uniq
    # ordering is a workaround to https://github.com/xonsh/xonsh/issues/4900
    $RIGHT_PROMPT += '{gitstatus:{} }{#555}{short_cwd}'
    $RIGHT_PROMPT += '{RESET}'
