final: prev:

let
  # usage: `nix-hf-hash unsloth/Qwen3.5-0.8B-GGUF Qwen3.5-0.8B-UD-Q4_K_XL.gguf`
  nix-hf-hash = prev.writers.writePython3Bin "nix-hf-hash" { } ''
    import base64
    import binascii
    import hashlib
    import http.client
    import sys
    import urllib.request
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
  qwen36-35b-a3b-q4km = fetchHF {
    repo = "unsloth/Qwen3.6-35B-A3B-GGUF";
    name = "Qwen3.6-35B-A3B-UD-Q4_K_M.gguf";
    hash = "sha256-rA4sEYngVfqjbv82FYDnnFvW+Odr/7TOVH8WfVPjGmE=";
  };
  qwen36-27b-q4km = fetchHF {
    repo = "unsloth/Qwen3.6-27B-GGUF";
    name = "Qwen3.6-27B-Q4_K_M.gguf";
    hash = "sha256-XtYNCvRlCoVLF1W9OS+a70hyZD3CWiVLxoBD+mODkqA=";
  };
  qwen36-27b-awq = fetchHFModel {
    pname = "qwen36-27b-awq";
    repo = "QuantTrio/Qwen3.6-27B-AWQ";
    files = [
      { path = ".mdl";
        hash = "sha256-xV4T4lzk5b92joOeyFbEf2a2Kw2xRbnCWX65rGqZcVs="; }
      { path = ".msc";
        hash = "sha256-/ZykifkwhDVfrlSalBY1afcwuIMzysbLfUMwVIxedKQ="; }
      { path = ".mv";
        hash = "sha256-JCqLWBgH+n3LTkWaK3v5s0WHjrSwERoK2xDITPHFbXk="; }
      { path = "chat_template.jinja";
        hash = "sha256-6E8yoj/donaJ+GiqShpWIfQRM+UaSNfz78vqKDlXQlk="; }
      { path = "config.json";
        hash = "sha256-Kw8CIcgeFkNyQJ+FQQdH7F8GCJCoHUnZ9s+v8+dOQqc="; }
      { path = "configuration.json";
        hash = "sha256-LURk4urQa8m8cYx4EwmtHnut7WJtZujc3ItGm6GF+vA="; }
      { path = "generation_config.json";
        hash = "sha256-5wwTbBt43cH7CQW6yOczpNxEjU+FKl3XUUP//HC+VQ4="; }
      { path = "merges.txt";
        hash = "sha256-qdNW173x70lJ4+dI6VuOEK2dTi6Djt3Digp7a5TR240="; }
      { path = "model.safetensors.index.json";
        hash = "sha256-tByANyFAEN9z27NPUpks5v3XM9Qj/9CGOGu2hfmUOO8="; }
      { path = "preprocessor_config.json";
        hash = "sha256-JyJUUKycZSmHLuGST8sJYv9WNINPgXBA9EQRgRb05RY="; }
      { path = "tokenizer.json";
        hash = "sha256-X55NSQGpK5l+RjwfRgVQiLbMpcphplItG59kxLuBy0I="; }
      { path = "tokenizer_config.json";
        hash = "sha256-UYbw3vzX8jI4LH8K680iUtBzu5IaskDkB7euh0XSsps="; }
      { path = "video_preprocessor_config.json";
        hash = "sha256-d2ivJ8H6+pzJARwdwgBn4D+JFeA7Y1BFUOEdUGaYbRM="; }
      { path = "vocab.json";
        hash = "sha256-zpm0yymD0RiAbOCot3ejWwk+IAClA+veJYUyhMnfoAM="; }
      { path = "model-00001-of-00008.safetensors";
        hash = "sha256-7e5aOBP8txuSXeLPjhx64DxB4i52IwSKrtiMFzammJ0="; }
      { path = "model-00002-of-00008.safetensors";
        hash = "sha256-7gtr7w8UIQbOTIAHXNzbvoOcTZVuq4IJ22+wRUcY/h8="; }
      { path = "model-00003-of-00008.safetensors";
        hash = "sha256-uoChB6uwrSjSSgLybMiGKz/RLn2bW6TIaOkZtoD8YeI="; }
      { path = "model-00004-of-00008.safetensors";
        hash = "sha256-AgkGODyL8rIdGCWSSA4H7FWFAALDGBKdNsoaJ0pIcJo="; }
      { path = "model-00005-of-00008.safetensors";
        hash = "sha256-3kgd5LRqPGa12y6TlvhI25+xzxpdtJOktFrCP7P++mA="; }
      { path = "model-00006-of-00008.safetensors";
        hash = "sha256-qGQfwDTadCnGUxWuupIzt0vsuFVhh4Jpcb92p+MacCY="; }
      { path = "model-00007-of-00008.safetensors";
        hash = "sha256-2KEktx6z7WHCfL80dAu9oXDEA2aOW1zsCWX7XwKslM0="; }
      { path = "model-00008-of-00008.safetensors";
        hash = "sha256-m8BGQHIcA7CvE66sSNh/Go+90/PRHMS7xf6VR9GQj74="; }
    ];
  };

  # No dflash.py (unlike 9B draft); uses built-in vllm qwen3_dflash
  # support natively.
  # Mirrored from gated z-lab/Qwen3.6-27B-DFlash.
  qwen36-27b-dflash-draft = let
    base = "https://monk.unboiled.info/model/qwen3.6-27b-dflash";
  in prev.runCommand "qwen36-27b-dflash-draft" { } ''
    mkdir -p $out
    ln -s ${prev.fetchurl {
      url = "${base}/config.json";
      hash = "sha256-UKDCl+3P9Zs5BA401qSkIKRYhLlvbzmpyM1xdcOAFpg=";
    }} $out/config.json
    ln -s ${prev.fetchurl {
      url = "${base}/model.safetensors";
      hash = "sha256-4MBQs0eY0ycooWTSw/FoF0b/hcEZRXAbAgW2VOLx/b4=";
    }} $out/model.safetensors
  '';

  qwen35-27b-q4km = fetchHF {
    repo = "unsloth/Qwen3.5-27B-GGUF";
    name = "Qwen3.5-27B-Q4_K_M.gguf";
    hash = "sha256-hLX38RIVbWODagGmncPxGmumOxCiO4ynp++vUtWi2AY=";
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

  # cyankiwi: W4A16-BF16, compressed-tensors format, group_size=32;
  # 6 shards (~14 GiB)
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
  qwen36-27b-q4kxl = fetchHF {
    repo = "unsloth/Qwen3.6-27B-GGUF";
    name = "Qwen3.6-27B-UD-Q4_K_XL.gguf";
    hash = "sha256-/2lB3tUls06xWUlnYsKd0Oxucdwxt01X512HGgPuwlk=";
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
