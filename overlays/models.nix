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
  fetchHF = { repo, name, hash, path ? name, rev ? "main" }: prev.fetchurl {
    inherit name hash;
    url = "https://huggingface.co/${repo}/resolve/${rev}/${path}";
  };

  # Full HuggingFace model directory (safetensors + config + tokenizer).
  # Each file entry: { path = "repo-relative/path"; hash = "sha256-..."; }
  # Use nix-hf-hash for large LFS files; compute sha256 of downloaded
  # content for small text files (they have SHA1 etags, not SHA256).
  fetchHFModel = { pname, repo, files }:
    let
      fetchedFiles = map ({ path, hash, name ? builtins.baseNameOf path }:
        fetchHF { inherit repo hash name path; }) files;
      links = prev.lib.concatMapStringsSep "\n"
        (f: "ln -s ${f} $out/${f.name}") fetchedFiles;
    in prev.runCommand pname { } ''
      mkdir -p $out
      ${links}
    '';

  # Shard manifest for fetchHFModel, for mixing shards with other files.
  # {nn} in templates is replaced by the 1-based shard index, 2-digit padded
  hfShardFiles =
    { nameTemplate, pathTemplate ? nameTemplate, shards }:
    let
      pad2 = i: prev.lib.fixedWidthString 2 "0" (builtins.toString i);
      sub = template: i:
        prev.lib.replaceStrings [ "{nn}" ] [ (pad2 i) ] template;
    in prev.lib.imap1
      (i: hash: { path = sub pathTemplate i; inherit hash; })
      shards;

  fetchHFSharded =
    { pname, repo, nameTemplate, pathTemplate ? nameTemplate, shards }:
    fetchHFModel {
      inherit pname repo;
      files = hfShardFiles {
        inherit nameTemplate pathTemplate shards;
      };
    };
in

{
  inherit nix-hf-hash;

  # plum
  qwen38-27b-q4kxl = fetchHF {
    repo = "unsloth/Qwen3.8-27B-GGUF";
    name = "Qwen3.8-27B-UD-Q4_K_XL.gguf";
    hash = "sha256-PyJweQA63SURQ35bHpSBLjYzhSJb9qm0ewBUpyvIsB4=";
  };
  qwen38-27b-mmproj-f16 = fetchHF {
    repo = "unsloth/Qwen3.8-27B-GGUF";
    name = "mmproj-F16.gguf";
    hash = "sha256-y7hBqe4GNrLsFy9buN8uqN/rAekP58YSZYHWYqC05D4=";
  };

  # Qwen Sharp chat template (v22.4.0) — terseness + thinking retention,
  # pass to llama-server via --chat-template-file
  qwen-sharp-chat-template = fetchHF {
    repo = "peculiar-ragdoll/Qwen-Sharp-Chat-Templates";
    name = "chat_template.jinja";
    hash = "sha256-zf85+ya2DckPqikucmZVxrIfYttJeEbgLkxLurlCqEo=";
  };

  qwen38-27b-q80 = fetchHF {
    repo = "unsloth/Qwen3.8-27B-GGUF";
    name = "Qwen3.8-27B-Q8_0.gguf";
    hash = "sha256-poD0SgaSDl1ol3SCN4IAaqOsyNuVdQMjNzskE5tn40g=";
  };

  qwen38-27b-autoround-int4 = fetchHFModel {
    pname = "qwen38-27b-autoround-int4";
    repo = "Frozenlock/Qwen3.8-27B-int4-AutoRound";
    files = [
      {
        path = "config.json";
        hash = "sha256-FRc9ekh8iBEqAoBHAassyPjdRjGj72fI2bssZtMN684=";
      }
      {
        path = "generation_config.json";
        hash = "sha256-uOt00V4KVmI9AMzRSVCku4f6u/hLXMAw3MkEuJn7HrU=";
      }
    ] ++ hfShardFiles {
      nameTemplate = "model-000{nn}-of-00007.safetensors";
      shards = [
        "sha256-g8CtsPEUEUKiXF95N6CScv7yuu59awev5goHb+/+O2Y="
        "sha256-bIbDkXzSKNVpnLFDXZIW4rrygVgrpCgqmGOBY2Bb5+w="
        "sha256-v7lhOz9ro9DFs++nT5LMFOxckmazQaeb9rRSR6WFd3A="
        "sha256-jp+9R2qjBVw8CohimPm+uTxSdcdIxTODV0b2ZI9trlU="
        "sha256-8M1jliHrJkENlrjAczRK4Aj2RlcqnEcTMm/0PUBs8nY="
        "sha256-VaFO550+WmWocx2JQm9N9Hfovcfap5dtQSVNivuUMvA="
        "sha256-aGbPitzMxMxqAOdLwCXxp3T7UhA7cPJnTQKIJylRpzM="
      ];
    } ++ [
      {
        path = "model_extra_tensors.safetensors";
        hash = "sha256-lBArZ8a4TmXbubrjfAC9iKwaQ/9XfOZf2IQtIxx+id4=";
      }
      {
        path = "model.safetensors.index.json";
        hash = "sha256-rfOH3uGD0QnpXNxNSYj82WbeMmhh/01mh2aSFw8eA60=";
      }
      {
        path = "preprocessor_config.json";
        hash = "sha256-OhWd/smXihhqcroIXgrWoFDzlo2LNkIY170T9ciTgfI=";
      }
      {
        path = "processor_config.json";
        hash = "sha256-2J70nOnNN/v1EBWOE8HvBj2ShkEcHskEmTLb4EhxQ7E=";
      }
      {
        path = "quantization_config.json";
        hash = "sha256-fKfHKQ1Q5hVRIAZ+L+ejHvKRMVixsHRB+VtFG87G25Q=";
      }
      {
        path = "tokenizer.json";
        hash = "sha256-BrlQk1LSr1A4GrIkfgg7gNMtXAq6kcJyyp/3Kbag5SM=";
      }
      {
        path = "tokenizer_config.json";
        hash = "sha256-eS+j8MuIsRHlTvMTTIc1MQCMTfRx0QjaF5A0JuMIqns=";
      }
      # chat_template.jinja is NOT fetched, the service passes its own
    ];
  };

  qwen38-27b-dflash2-zlab = fetchHFModel {
    pname = "qwen38-27b-dflash2-zlab";
    repo = "z-lab/Qwen3.8-27B-DFlash2";
    files = [
      {
        path = "config.json";
        hash = "sha256-hz41VlCbDaBuKWVLoA1JRIiNS16KM6/eJffrJ9Mh6YA=";
      }
      {
        path = "model.safetensors";
        hash = "sha256-Z/x21o3FqUFVEaTzlO90TWdRDNIOk7N8wsx9KOS6tlw=";
      }
    ];
  };  # requantized in hosts/plum/sglang/int8-drafter.nix

  # grapefruit
  qwen38-flash-next-ud-iq4xs = fetchHFSharded rec {
    pname = "qwen38-flash-next-ud-iq4xs";
    repo = "unsloth/Qwen3.8-Flash-Next-GGUF";
    nameTemplate = "Qwen3.8-Flash-Next-UD-IQ4_XS-000{nn}-of-00003.gguf";
    pathTemplate = "UD-IQ4_XS/${nameTemplate}";
    shards = [
      "sha256-XOiTcHIPi/kIkPQ5NhKCEEwaoUgtQBO7mlCSPnWOcaQ="
      "sha256-V3o4ojkrQMohk86lAuHZL2C4zTcGddMI4OwhiF2dqqc="
      "sha256-1GNObYTw67CUC+FckNN5C/ZGTj3qOhzdxWfcDoOtiDM="
    ];
  };
  qwen38-flash-next-ud-q4kxl = fetchHFSharded rec {  # for gufo
    pname = "qwen38-flash-next-ud-iq4xs";
    repo = "unsloth/Qwen3.8-Flash-Next-GGUF";
    nameTemplate = "Qwen3.8-Flash-Next-UD-Q4_K_XL-000{nn}-of-00004.gguf";
    pathTemplate = "UD-Q4_K_XL/${nameTemplate}";
    shards = [
      "sha256-REgYYhazr0zFWLvOLDIT8BYI+Piy5SZ6l2eXHdPsgII="
      "sha256-PzQvHBWARz8e6U3dWyggbowHpw+ho2b1nR1skikZpsk="
      "sha256-VnWPQCacrVzZsNPW+64PQPbVvm3knkqzktvoMVfZy9M="
      "sha256-dTvaSLmLpPFjYTSpCpZ94bLTkIojbAJuRkd3NC5TUQo="
    ];
  };
  qwen38-flash-next-mtp-q80 = fetchHF {  # for gufo, MTP sidecar
    repo = "unsloth/Qwen3.8-Flash-Next-GGUF";
    name = "mtp-Qwen3.8-Flash-Next-Q8_0.gguf";
    path = "MTP/mtp-Qwen3.8-Flash-Next-shared-Q8_0.gguf";
    hash = "sha256-X/VAl0BqkFzzpyTHCRJM6w4+ECNe6GIpiWnpHJb6luY=";
  };

  # gufo's vision loader requires BF16 tensors (mmproj-F16 is rejected);

  qwen38-flash-next-mmproj-bf16 = fetchHF {
    repo = "unsloth/Qwen3.8-Flash-Next-GGUF";
    name = "mmproj-BF16.gguf";
    hash = "sha256-LniPjFEdgJPHtDy4ey/X4UIoNAMYBX+PsgyG3y7+I1U=";
  };

  # shared by all Qwen3.8 models (identical tokenizer.json, verified)
  qwen38-tokenizer = fetchHF {
    repo = "Qwen/Qwen3.8-Flash-Next";
    name = "tokenizer.json";
    hash = "sha256-CZf0EMV6H05TsJ5L6PShctkO3ZVkNo+whHAwk3IpufM=";
  };

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

  # LFM 2.5 fast small MoE
  lfm25-8b-a1b-ud-q4kxl = fetchHF {
    repo = "unsloth/LFM2.5-8B-A1B-GGUF";
    name = "LFM2.5-8B-A1B-UD-Q4_K_XL.gguf";
    hash = "sha256-7nxekloEzWcoaJWeSNGZtm1ty5+Qr+ZPIZhWGJ6Dsn4=";
  };
  lfm25-tokenizer = fetchHF {
    repo = "LiquidAI/LFM2.5-8B-A1B";
    name = "tokenizer.json";
    hash = "sha256-aVvngCoOS4qBBI8P9eu3/IEaC6WmvmPbsk3rWoEJb0E=";
  };

  # d1-3b decision model
  d1-3b-q4km = fetchHF {
    repo = "LiquidAI/d1-3B-GGUF";
    name = "d1-3B-Q4_K_M.gguf";
    hash = "sha256-Fq/yfqLu/cMrmJf0OFSl0xcMHcjcy5x1aQWvMKTiJAI=";
  };
  d1-3b-mmproj-q80 = fetchHF {  # only for image questions on /v1/systemone
    repo = "LiquidAI/d1-3B-GGUF";
    name = "mmproj-d1-3B-Q8_0.gguf";
    hash = "sha256-JQWSDORkt8VKzYt7dKkxwMZx8G0MiDN2Cy+87rJT6So=";
  };

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
