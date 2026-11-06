# Local extension: runs /tree "summarize branch" on litellm/batch instead
# of the interactive to not pollute its checkpoints
_: _: {
  summarize-branch-on-batch = ./summarize-branch-on-batch.ts;
}
