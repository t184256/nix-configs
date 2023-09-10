# execute with nix run github:adisbladis/nix-unit test.nix
{
  autoimportTests = (import ./.autoimport)._tests;
}
