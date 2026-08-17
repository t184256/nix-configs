# Local extension (source in ./no-tail-pipe.ts): warns the model when it
# pipes bash output through tail/head, since pi already auto-truncates
# tool output.
final: prev: {
  no-tail-pipe = ./no-tail-pipe.ts;
}
