final: prev:

{
  qwen35-35b-a3b-iq4xs = prev.fetchurl {
    name = "Qwen3.5-35B-A3B-UD-IQ4_XS.gguf";
    url = "https://huggingface.co/unsloth/Qwen3.5-35B-A3B-GGUF"
      + "/resolve/main/Qwen3.5-35B-A3B-UD-IQ4_XS.gguf";
    hash = "sha256-dF3vCHyew00SqU65sx61LbqVizbe9RC36Pby5r8b4SM=";
  };
  qwen35-27b-iq4xs = prev.fetchurl {
    name = "Qwen3.5-27B-IQ4_XS.gguf";
    url = "https://huggingface.co/unsloth/Qwen3.5-27B-GGUF"
      + "/resolve/main/Qwen3.5-27B-IQ4_XS.gguf";
    hash = "sha256-+4KchEkbMM2odbc2binOPkzt4ZtA2vW4JAA5Nr/E27s=";
  };
}
