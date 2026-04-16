final: prev:

let
  # usage: `nix-hf-hash unsloth/Qwen3.5-0.8B-GGUF Qwen3.5-0.8B-UD-Q4_K_XL.gguf`
  nix-hf-hash = prev.writers.writePython3Bin "nix-hf-hash" { } ''
    import base64, binascii, http.client, sys
    repo, filename = sys.argv[1], sys.argv[2]
    conn = http.client.HTTPSConnection("huggingface.co")
    conn.request("HEAD", f"/{repo}/resolve/main/{filename}")
    etag = conn.getresponse().getheader("x-linked-etag").strip('"')
    print(f"sha256-{base64.b64encode(binascii.unhexlify(etag)).decode()}")
  '';

  # path defaults to name; set explicitly when the file lives in a subdir
  fetchHF = { repo, name, hash, path ? name }: prev.fetchurl {
    inherit name hash;
    url = "https://huggingface.co/${repo}/resolve/main/${path}";
  };

  # Full HuggingFace model directory (safetensors + config + tokenizer).
  # Each file entry: { path = "repo-relative/path"; hash = "sha256-..."; }
  # Use nix-hf-hash for large LFS files; compute sha256 of downloaded
  # content for small text files (they have SHA1 etags, not SHA256).
  fetchHFModel = { pname, repo, files }:
    let
      fetchedFiles = map ({ path, hash }:
        fetchHF {
          inherit repo hash;
          name = builtins.baseNameOf path;
          inherit path;
        }) files;
      links = prev.lib.concatMapStringsSep "\n"
        (f: "ln -s ${f} $out/${f.name}") fetchedFiles;
    in prev.runCommand pname { } ''
      mkdir -p $out
      ${links}
    '';

  # {nn} in templates is replaced by the 1-based shard index, 2-digit padded
  fetchHFSharded =
    { pname, repo, nameTemplate, pathTemplate ? nameTemplate, shards }:
    let
      pad2 = i: prev.lib.fixedWidthString 2 "0" (builtins.toString i);
      sub = template: i:
        prev.lib.replaceStrings [ "{nn}" ] [ (pad2 i) ] template;
      fetchedShards = prev.lib.imap1 (i: hash: fetchHF {
        inherit repo hash;
        name = sub nameTemplate i;
        path = sub pathTemplate i;
      }) shards;
      symlinkShards = prev.lib.concatMapStringsSep "\n"
        (s: "ln -s ${s} $out/${s.name}") fetchedShards;
    in prev.runCommand pname { } ''
      mkdir -p $out
      ${symlinkShards}
    '';
in

{
  inherit nix-hf-hash;

  # plum
  qwen35-35b-a3b-iq4xs = fetchHF {
    repo = "unsloth/Qwen3.5-35B-A3B-GGUF";
    name = "Qwen3.5-35B-A3B-UD-IQ4_XS.gguf";
    hash = "sha256-dF3vCHyew00SqU65sx61LbqVizbe9RC36Pby5r8b4SM=";
  };
  qwen35-27b-iq4xs = fetchHF {
    repo = "unsloth/Qwen3.5-27B-GGUF";
    name = "Qwen3.5-27B-IQ4_XS.gguf";
    hash = "sha256-+4KchEkbMM2odbc2binOPkzt4ZtA2vW4JAA5Nr/E27s=";
  };

  # plum — vllm 9B comparison (with / without DFlash speculative decoding)
  # QuantTrio keeps all self_attn weights in bf16, so 9B runs 11.5 GiB.
  # Combined with the 1.95 GiB DFlash draft: 13.45 GiB, ~10 GiB for KV.
  qwen35-9b-awq = fetchHFModel {
    pname = "qwen35-9b-awq";
    repo = "QuantTrio/Qwen3.5-9B-AWQ";
    files = [
      { path = ".mdl";
        hash = "sha256-IlHaxpjTZu4w403euHYYKEwyEtQlMvekgvB3tYdbwMc="; }
      { path = ".msc";
        hash = "sha256-1a5eii8M6/PtwzO/FiqWdJDWtzyCdL4V1ckgxm0udjo="; }
      { path = ".mv";
        hash = "sha256-cwCFDTbvNik8rgxSny3Fxnr4qooYEdu2ziudHgF69TE="; }
      { path = "chat_template.jinja";
        hash = "sha256-pK7or88uBxGULPhIiZvmYBb40UqIn/nt4HvKCZwo9xU="; }
      { path = "config.json";
        hash = "sha256-6CJPkjqQmP2Sn/CdUN8kYmqZDJBcks2ijYPFwlHM6dU="; }
      { path = "configuration.json";
        hash = "sha256-LURk4urQa8m8cYx4EwmtHnut7WJtZujc3ItGm6GF+vA="; }
      { path = "generation_config.json";
        hash = "sha256-1frLpM57Uqd8CdKXNoLGUUkrlkGOk+16ovvIzZTFUBo="; }
      { path = "merges.txt";
        hash = "sha256-qdNW173x70lJ4+dI6VuOEK2dTi6Djt3Digp7a5TR240="; }
      { path = "model.safetensors.index.json";
        hash = "sha256-tvV+zxNxQHeMBLXeBdjd7jYtgpjm7rHzoFHpkKqJWu8="; }
      { path = "preprocessor_config.json";
        hash = "sha256-JyJUUKycZSmHLuGST8sJYv9WNINPgXBA9EQRgRb05RY="; }
      { path = "tokenizer.json";
        hash = "sha256-X55NSQGpK5l+RjwfRgVQiLbMpcphplItG59kxLuBy0I="; }
      { path = "tokenizer_config.json";
        hash = "sha256-MWIw1qgJcB9NteqPj8hivDpvMinJN8F05nT/PKCmSsg="; }
      { path = "video_preprocessor_config.json";
        hash = "sha256-d2ivJ8H6+pzJARwdwgBn4D+JFeA7Y1BFUOEdUGaYbRM="; }
      { path = "vocab.json";
        hash = "sha256-zpm0yymD0RiAbOCot3ejWwk+IAClA+veJYUyhMnfoAM="; }
      { path = "model-00001-of-00005.safetensors";
        hash = "sha256-+B4S58pVXd5W+cgWxiCHGGqzXNXi74cxXj/e/5dV7EQ="; }
      { path = "model-00002-of-00005.safetensors";
        hash = "sha256-M0HH3VPJBAQmHJHguq9gLzUjlHdieuuqERYO8+HJ+hM="; }
      { path = "model-00003-of-00005.safetensors";
        hash = "sha256-U0vg6ndewsG6lF4ajR5wypMxgGa+pwZpALevYqRAIJM="; }
      { path = "model-00004-of-00005.safetensors";
        hash = "sha256-Xhecdw6TYV7zZ4mMcbUcbADPkf6/TNYjXVv8Jbw6ZKg="; }
      { path = "model-00005-of-00005.safetensors";
        hash = "sha256-mW5g4xU58NcQjg0d07gs5HbM76mgdG9fyylwfPwUxN0="; }
    ];
  };

  qwen35-27b-dflash-draft = fetchHFModel {
    pname = "qwen35-27b-dflash-draft";
    repo = "z-lab/Qwen3.5-27B-DFlash";
    files = [
      { path = "config.json";
        hash = "sha256-LMBCA8kXkKHEEyTpeULb4knZkWU47l1+xIfys1Jmi3M="; }
      { path = "dflash.py";
        hash = "sha256-gNWCaPiDmiLK1CUWzJXRJ7efyhlNJe56jMTWELyPVg4="; }
      { path = "model.safetensors";
        hash = "sha256-HkTK4x69oZQNpWMYwSlQnfRooaZQio+BagPgxchmG3c="; }
    ];
  };

  qwen35-9b-dflash-draft = fetchHFModel {
    pname = "qwen35-9b-dflash-draft";
    repo = "z-lab/Qwen3.5-9B-DFlash";
    files = [
      { path = "config.json";
        hash = "sha256-C9ld/KskR/eAm4aBIsTjM8McT2Sc9e3WrIzFKsMdT+I="; }
      # dflash.py contains the model architecture; required for
      # trust_remote_code loading if vllm doesn't have built-in support
      { path = "dflash.py";
        hash = "sha256-gNWCaPiDmiLK1CUWzJXRJ7efyhlNJe56jMTWELyPVg4="; }
      { path = "model.safetensors";
        hash = "sha256-iXnsI0qp8TDqThoSgyb1P/t/yZQKdnFNEO9HGqg+xcM="; }
    ];
  };

  # cyankiwi: W4A16-BF16, compressed-tensors format, group_size=32; 6 shards (~14 GiB)
  qwen35-27b-awq-bf16 = fetchHFModel {
    pname = "qwen35-27b-awq-bf16";
    repo = "cyankiwi/Qwen3.5-27B-AWQ-BF16-INT4";
    files = [
      { path = "chat_template.jinja";
        hash = "sha256-pK7or88uBxGULPhIiZvmYBb40UqIn/nt4HvKCZwo9xU="; }
      { path = "config.json";
        hash = "sha256-wXR4LB3li4oKaGBfFuUQkdhmyfVbQXdT9iLKdh0/KHU="; }
      { path = "generation_config.json";
        hash = "sha256-MDq6iR1mq2OQins8yRY7y4Nf34ufYwHHMhbz8es5kt0="; }
      { path = "merges.txt";
        hash = "sha256-qdNW173x70lJ4+dI6VuOEK2dTi6Djt3Digp7a5TR240="; }
      { path = "model.safetensors.index.json";
        hash = "sha256-08LHCydYnAdvIYyyTKJcIqny+FrCryDpbEiCWPNY50c="; }
      { path = "preprocessor_config.json";
        hash = "sha256-JyJUUKycZSmHLuGST8sJYv9WNINPgXBA9EQRgRb05RY="; }
      { path = "tokenizer.json";
        hash = "sha256-X55NSQGpK5l+RjwfRgVQiLbMpcphplItG59kxLuBy0I="; }
      { path = "tokenizer_config.json";
        hash = "sha256-MWIw1qgJcB9NteqPj8hivDpvMinJN8F05nT/PKCmSsg="; }
      { path = "video_preprocessor_config.json";
        hash = "sha256-d2ivJ8H6+pzJARwdwgBn4D+JFeA7Y1BFUOEdUGaYbRM="; }
      { path = "vocab.json";
        hash = "sha256-zpm0yymD0RiAbOCot3ejWwk+IAClA+veJYUyhMnfoAM="; }
      { path = "model-00001-of-00006.safetensors";
        hash = "sha256-jagbfNL1pLemqUNRIpfRvjCVzcXjToh84QfFyKtacbo="; }
      { path = "model-00002-of-00006.safetensors";
        hash = "sha256-XLpmwKFzAJf/E1xmx51oOVbEGM3qQq2R80htAsxMkQc="; }
      { path = "model-00003-of-00006.safetensors";
        hash = "sha256-Oa7UOmbh2Tjj9EgYkfFGEnNy8zQaNP/BTEjfWC5NScA="; }
      { path = "model-00004-of-00006.safetensors";
        hash = "sha256-68fi3S9rtVZwT+E7zGpaCyTgqMvjojXMYLrZ/01Cq0c="; }
      { path = "model-00005-of-00006.safetensors";
        hash = "sha256-CCzU0JB5GiR5usz4/saaTgc3Mpj2Ag8mKJlyttkTyVU="; }
      { path = "model-00006-of-00006.safetensors";
        hash = "sha256-2dugWPcvWwHoeIb9kAMxzXP2N6ikLI3xi2+IQ2BAPaY="; }
    ];
  };

  # grapefruit
  qwen35-08b-q4kxl = fetchHF {
    repo = "unsloth/Qwen3.5-0.8B-GGUF";
    name = "Qwen3.5-0.8B-UD-Q4_K_XL.gguf";
    hash = "sha256-MXfr1nr+RDg3TaGeaQvBuYdW9+D+qSQOG+QEM2FWp7U=";
  };
  qwen35-27b-q4kxl = fetchHF {
    repo = "unsloth/Qwen3.5-27B-GGUF";
    name = "Qwen3.5-27B-UD-Q4_K_XL.gguf";
    hash = "sha256-E8tiKDRImK+lDZY8Aq4NmRriUJTuqIN9uNDkUukcWIg=";
  };
  qwen35-35b-a3b-mxfp4 = fetchHF {
    repo = "unsloth/Qwen3.5-35B-A3B-GGUF";
    name = "Qwen3.5-35B-A3B-MXFP4_MOE.gguf";
    hash = "sha256-DxNaWRWQMPRxBHerxvmSLS8TVSyFv/c23qrvcQI813A=";
  };
  # 122B is sharded; llama.cpp takes path to first shard
  qwen35-122b-a10b-mxfp4 = fetchHFSharded (rec {
    pname = "qwen35-122b-a10b-mxfp4";
    repo = "unsloth/Qwen3.5-122B-A10B-GGUF";
    nameTemplate = "Qwen3.5-122B-A10B-MXFP4_MOE-000{nn}-of-00003.gguf";
    pathTemplate = "MXFP4_MOE/${nameTemplate}";
    shards = [
      "sha256-Rnyb2S6lGFOc91v1pfv7016aC0DXZsyqZ78SDhIEHfM="
      "sha256-loJuZephnlAxF2PVYzLs8T8nS004P6OYGyyELVx6Qf0="
      "sha256-49DFOiNvZiiSiRj/PbgGq0ELKzN9XgQQdvV9kpbOR/U="
    ];
  });

  sweep-v2-7b = fetchHF {
    repo = "henrik3/sweep-next-edit-v2-7B-GGUF";
    name = "q4_k_m.gguf";
    hash = "sha256-sDLxuTCNWvMZrGpIf3nU2OnoPPULg2LJpT7vRI/tIGw=";
  };
  sweep-1_5b = fetchHF {
    repo = "sweepai/sweep-next-edit-1.5B";
    name = "sweep-next-edit-1.5b.q8_0.v2.gguf";
    hash = "sha256-EyHqXl11KeYPl3DGoLOpZfiVQtFs9K5RurJn9qiBUNo=";
  };
  sweep-0_5b = fetchHF {
    repo = "sweepai/sweep-next-edit-0.5B";
    name = "sweep-next-edit-0.5b.q8_0.gguf";
    hash = "sha256-LS9cqFZ2WghtTuPQ3E0wNY6dVi42SA4MdUJA6c9F7WQ=";
  };

}
