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
