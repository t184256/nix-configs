final: prev:

let
  # usage: `nix-hf-hash unsloth/Qwen3.5-0.8B-GGUF Qwen3.5-0.8B-UD-Q4_K_XL.gguf`
  nix-hf-hash = prev.writers.writePython3Bin "nix-hf-hash" { } ''
    import base64, binascii, hashlib, http.client, sys, urllib.request
    repo, filename = sys.argv[1], sys.argv[2]
    url = f"https://huggingface.co/{repo}/resolve/main/{filename}"
    conn = http.client.HTTPSConnection("huggingface.co")
    conn.request("HEAD", f"/{repo}/resolve/main/{filename}")
    etag = (conn.getresponse().getheader("x-linked-etag") or "").strip('"')
    if len(etag) == 64:  # LFS: ETag is SHA-256
        h = base64.b64encode(binascii.unhexlify(etag)).decode()
    else:  # non-LFS: ETag is SHA-1; download and hash
        with urllib.request.urlopen(url) as resp:
            h = base64.b64encode(hashlib.sha256(resp.read()).digest()).decode()
    print(f"sha256-{h}")
  '';

  # path defaults to name; set explicitly when the file lives in a subdir
  fetchHF = { repo, name, hash, path ? name }: prev.fetchurl {
    inherit name hash;
    url = "https://huggingface.co/${repo}/resolve/main/${path}";
  };

  # fetch a multi-file HF model directory (config, tokenizer, safetensors, …)
  fetchHFModel = { pname, repo, files }:
    let
      fetchedFiles = map (f: fetchHF { inherit repo; inherit (f) name hash; }) files;
      symlinkFiles = prev.lib.concatMapStringsSep "\n"
        (f: "ln -s ${f} $out/${f.name}") fetchedFiles;
    in prev.runCommand pname { } ''
      mkdir -p $out
      ${symlinkFiles}
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
  qwen36-35b-a3b-iq4xs = fetchHF {
    repo = "unsloth/Qwen3.6-35B-A3B-GGUF";
    name = "Qwen3.6-35B-A3B-UD-IQ4_XS.gguf";
    hash = "sha256-ZJ11CFB7hGOHMsT1LCTIsVhDxtyi8/95OuB8FKZ+u7M=";
  };
  qwen35-27b-iq4xs = fetchHF {
    repo = "unsloth/Qwen3.5-27B-GGUF";
    name = "Qwen3.5-27B-IQ4_XS.gguf";
    hash = "sha256-+4KchEkbMM2odbc2binOPkzt4ZtA2vW4JAA5Nr/E27s=";
  };

  # grapefruit
  qwen35-08b-q4kxl = fetchHF {
    repo = "unsloth/Qwen3.5-0.8B-GGUF";
    name = "Qwen3.5-0.8B-UD-Q4_K_XL.gguf";
    hash = "sha256-MXfr1nr+RDg3TaGeaQvBuYdW9+D+qSQOG+QEM2FWp7U=";
  };
  qwen35-2b-q4kxl = fetchHF {
    repo = "unsloth/Qwen3.5-2B-GGUF";
    name = "Qwen3.5-2B-UD-Q4_K_XL.gguf";
    hash = "sha256-CvlhZephW+o5oEEY1j8LbTWQiuqFDuSlGqYVHYUbizU=";
  };
  qwen35-4b-q4kxl = fetchHF {
    repo = "unsloth/Qwen3.5-4B-GGUF";
    name = "Qwen3.5-4B-UD-Q4_K_XL.gguf";
    hash = "sha256-slLFYQpCyoLSD+KhKBPp0Gnu2JKSkH4mx4PusLyWG8c=";
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
  qwen36-35b-a3b-mxfp4 = fetchHF {
    repo = "unsloth/Qwen3.6-35B-A3B-GGUF";
    name = "Qwen3.6-35B-A3B-MXFP4_MOE.gguf";
    hash = "sha256-L90gmXxNiO4l9w9QDGH4uZk3jZKrBV+dRQ/HDWFxWNM=";
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

  # plum — sglang/vllm AWQ serving (QuantTrio/Qwen3.5-9B-AWQ, 5 safetensors shards)
  qwen35-9b-awq = fetchHFModel {
    pname = "qwen35-9b-awq";
    repo = "QuantTrio/Qwen3.5-9B-AWQ";
    files = [
      { name = "config.json";
        hash = "sha256-6CJPkjqQmP2Sn/CdUN8kYmqZDJBcks2ijYPFwlHM6dU="; }
      { name = "generation_config.json";
        hash = "sha256-1frLpM57Uqd8CdKXNoLGUUkrlkGOk+16ovvIzZTFUBo="; }
      { name = "model.safetensors.index.json";
        hash = "sha256-tvV+zxNxQHeMBLXeBdjd7jYtgpjm7rHzoFHpkKqJWu8="; }
      { name = "model-00001-of-00005.safetensors";
        hash = "sha256-+B4S58pVXd5W+cgWxiCHGGqzXNXi74cxXj/e/5dV7EQ="; }
      { name = "model-00002-of-00005.safetensors";
        hash = "sha256-M0HH3VPJBAQmHJHguq9gLzUjlHdieuuqERYO8+HJ+hM="; }
      { name = "model-00003-of-00005.safetensors";
        hash = "sha256-U0vg6ndewsG6lF4ajR5wypMxgGa+pwZpALevYqRAIJM="; }
      { name = "model-00004-of-00005.safetensors";
        hash = "sha256-Xhecdw6TYV7zZ4mMcbUcbADPkf6/TNYjXVv8Jbw6ZKg="; }
      { name = "model-00005-of-00005.safetensors";
        hash = "sha256-mW5g4xU58NcQjg0d07gs5HbM76mgdG9fyylwfPwUxN0="; }
      { name = "tokenizer.json";
        hash = "sha256-X55NSQGpK5l+RjwfRgVQiLbMpcphplItG59kxLuBy0I="; }
      { name = "tokenizer_config.json";
        hash = "sha256-MWIw1qgJcB9NteqPj8hivDpvMinJN8F05nT/PKCmSsg="; }
      { name = "merges.txt";
        hash = "sha256-qdNW173x70lJ4+dI6VuOEK2dTi6Djt3Digp7a5TR240="; }
      { name = "vocab.json";
        hash = "sha256-zpm0yymD0RiAbOCot3ejWwk+IAClA+veJYUyhMnfoAM="; }
      { name = "chat_template.jinja";
        hash = "sha256-pK7or88uBxGULPhIiZvmYBb40UqIn/nt4HvKCZwo9xU="; }
      { name = "preprocessor_config.json";
        hash = "sha256-JyJUUKycZSmHLuGST8sJYv9WNINPgXBA9EQRgRb05RY="; }
      { name = "video_preprocessor_config.json";
        hash = "sha256-d2ivJ8H6+pzJARwdwgBn4D+JFeA7Y1BFUOEdUGaYbRM="; }
    ];
  };

  # plum — sglang DFlash draft model for Qwen3.5-9B-AWQ
  qwen35-9b-dflash-draft = fetchHFModel {
    pname = "qwen35-9b-dflash-draft";
    repo = "z-lab/Qwen3.5-9B-DFlash";
    files = [
      { name = "config.json";
        hash = "sha256-C9ld/KskR/eAm4aBIsTjM8McT2Sc9e3WrIzFKsMdT+I="; }
      { name = "dflash.py";
        hash = "sha256-gNWCaPiDmiLK1CUWzJXRJ7efyhlNJe56jMTWELyPVg4="; }
      { name = "model.safetensors";
        hash = "sha256-iXnsI0qp8TDqThoSgyb1P/t/yZQKdnFNEO9HGqg+xcM="; }
    ];
  };

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
