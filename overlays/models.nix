final: prev:

let
  # usage: nix run .#nixpkgs.nix-hf-hash -- ggerganov/whisper.cpp ggml-tiny.bin
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
  qwen38-27b-q4kxl = fetchHF {
    repo = "unsloth/Qwen3.8-27B-GGUF";
    name = "Qwen3.8-27B-UD-Q4_K_XL.gguf";
    hash = "sha256-vuI4u+s9wKNL3k0N7bruH5jACei7QibwMHAFTBL7E3I=";
  };
  qwen38-27b-mmproj-f16 = fetchHF {
    repo = "unsloth/Qwen3.8-27B-GGUF";
    name = "mmproj-F16.gguf";
    hash = "sha256-y7hBqe4GNrLsFy9buN8uqN/rAekP58YSZYHWYqC05D4=";
  };

  qwen38-27b-q80 = fetchHF {
    repo = "unsloth/Qwen3.8-27B-GGUF";
    name = "Qwen3.8-27B-Q8_0.gguf";
    hash = "sha256-poD0SgaSDl1ol3SCN4IAaqOsyNuVdQMjNzskE5tn40g=";
  };

  # grapefruit
  qwen35-08b-mtp-q4kxl = fetchHF {
    repo = "unsloth/Qwen3.5-0.8B-MTP-GGUF";
    name = "Qwen3.5-0.8B-UD-Q4_K_XL.gguf";
    hash = "sha256-LanGuoL/59KgG9/r1DV2YlguSKfzbocIZhIHqe3QIvQ=";
  };
  qwen35-35b-a3b-mtp-mxfp4 = fetchHF {
    repo = "unsloth/Qwen3.5-35B-A3B-MTP-GGUF";
    name = "Qwen3.5-35B-A3B-MXFP4_MOE.gguf";
    hash = "sha256-CBEOTHfkBgQCcBtpt3CJlMfrTqFvWWZLf8tTKLn9EK0=";
  };
  qwen36-35b-a3b-mtp-mxfp4 = fetchHF {
    repo = "unsloth/Qwen3.6-35B-A3B-MTP-GGUF";
    name = "Qwen3.6-35B-A3B-MXFP4_MOE.gguf";
    hash = "sha256-4aSSXS6hMldtqpy5gLEQK5cNkZ2JaTa3tuaB71vD0/Y=";
  };
  # 122B variant is sharded; llama.cpp takes path to first shard
  qwen35-122b-a10b-mtp-mxfp4 = fetchHFSharded (rec {
    pname = "qwen35-122b-a10b-mtp-mxfp4";
    repo = "unsloth/Qwen3.5-122B-A10B-MTP-GGUF";
    nameTemplate = "Qwen3.5-122B-A10B-MXFP4_MOE-000{nn}-of-00003.gguf";
    pathTemplate = "MXFP4_MOE/${nameTemplate}";
    shards = [
      "sha256-77QSd0skT1ylaLhY9qgD+pktxZIEi4IeD0edeNwRQQY="
      "sha256-lvs422yZBM1y93dWZ8mZxjC05bgP5F3aNqPeciKhJdM="
      "sha256-x17qzxk4wGGtW84+Wi3bDvm6pKdhwsIz4SfL/pzLtr8="
    ];
  });

  zeta_2_1 = fetchHF {
    repo = "mradermacher/zeta-2.1-i1-GGUF";
    name = "zeta-2.1.i1-Q4_K_M.gguf";
    hash = "sha256-IW3bVyKkn5/0myGgUMTbPIAe9vNOS9FwLV20PjMlsHY=";
  };
  zeta_2 = fetchHF {
    repo = "bartowski/zed-industries_zeta-2-GGUF";
    name = "zed-industries_zeta-2-Q4_K_L.gguf";
    hash = "sha256-mUmR9cavkD1Qu7+KjeG4Cs62eIuHcrgWFzswof+OpyU=";
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

  whisper-tiny = fetchHF {
    repo = "ggerganov/whisper.cpp";
    name = "ggml-tiny.bin";
    hash = "sha256-vgfgSOHlma1GNByNKhNWRQl6U4IhZ4t6zdGxkZxuGyE=";
  };
  whisper-base = fetchHF {
    repo = "ggerganov/whisper.cpp";
    name = "ggml-base.bin";
    hash = "sha256-YO1bw90U7qhWST0zQ0m0BXgt3K8AKNS130CINF+6Lv4=";
  };
  whisper-large = fetchHF {
    repo = "ggerganov/whisper.cpp";
    name = "ggml-large-v3.bin";
    hash = "sha256-ZNGCtEC5jVIDxPm9VBVE2ExgUZbE97hF36EfsjWU0eI=";
  };
  whisper-large-turbo = fetchHF {
    repo = "ggerganov/whisper.cpp";
    name = "ggml-large-v3-turbo.bin";
    hash = "sha256-H8cPd0046xaZk6w5Huo1fvR8iHV+9y7llDh5t+jivGk=";
  };
  whisper-distil-large-v35 = fetchHF {  # uses 1986MiB VRAM with CUDA
    repo = "distil-whisper/distil-large-v3.5-ggml";
    name = "ggml-model.bin";
    hash = "sha256-7CSYkZtJjF9rAAQa20VlASSzzZ8m9UX/+o9dEcKNzyY=";
  };
  whisper-large-turbo-q8_0 = fetchHF {  # uses 1382MiB VRAM with CUDA
    repo = "ggerganov/whisper.cpp";
    name = "ggml-large-v3-turbo-q8_0.bin";
    hash = "sha256-MX62nBFnPJ3h4fDUWbJTmZgE7HGsTCPBfs9fviTiWaE=";
  };
  whisper-large-q5_0 = fetchHF {
    repo = "ggerganov/whisper.cpp";
    name = "ggml-large-v3-q5_0.bin";
    hash = "sha256-11eV7P8/g7X6qJ0ZAGBK2MeAq9Vzn65AbeGfI+zZitE=";
  };

}
