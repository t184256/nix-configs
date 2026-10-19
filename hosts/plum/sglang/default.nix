{ config, lib, pkgs, ... }:

# Qwen3.8-27B (INT4 AutoRound + W4A8) + DFlash2 int8 (!) on 2x RTX 3090 NVLink
# KV pool > 256k even with the largest whisper co-resident

# The overarching goal is having an interactive machine (>70 tg)
# so that it can supplement the more batch-oriented grapefruit.

# bench-sglang --think:
# target      pp      ttft   avg pp   decode tps    gen
#    256     257    0.120s     2143        131.1   1024
#   8192    8193    2.579s     3177        122.4   1024
#  16384   16385    5.309s     3086        113.1   1024
#  32768   32769   11.807s     2775        133.0   1024
#  65536   65537   28.902s     2268        116.1   1024
# 131072  131073   79.255s     1654         91.9   1024
# 196608  196609  151.492s     1298         88.3   1024
# 261088  261089  244.173s     1069         75.8   1024

# bench-sglang --nothink:
# target      pp      ttft   avg pp   decode tps    gen
#    256     229    0.107s     2136        151.4   1024
#   8192    8165    2.512s     3250        130.6   1024
#  16384   16357    5.246s     3118        109.3   1024
#  32768   32741   11.767s     2782        116.0   1024
#  65536   65509   28.840s     2271        103.9   1024
# 131072  131045   78.948s     1660         90.8   1024
# 196608  196581  150.565s     1306         86.8   1024
# 261088  261061  242.135s     1078         85.8   1024

# Aggregate speed at 2 streams is almost 2x the single-stream.
# TODO: benchmark with --concurrency 2

# On updates, run sglang-self-check and update benchmark numbers above.
# Results are rather noisy, +-10% is normal even with the default --runs 5.

let
  # ingredients

  imageTag = "v0.5.21";
  imageDigest =
    "sha256:b1259f3ea3275f66237c498ea388919729018bc9f01c3d638391e06e2cf3f469";
  image = "docker.io/lmsysorg/sglang:${imageTag}";
  imageArchive = pkgs.dockerTools.pullImage {  # warning: costs 37 GB, twice
    imageName = "lmsysorg/sglang";
    inherit imageDigest;
    arch = "amd64";
    finalImageName = "docker.io/lmsysorg/sglang";
    finalImageTag = imageTag;
    outputHash = "sha256-RhVlp+h9x3MrO5I4LxUPUAQCwUsoQmipd4wwMBZX9ao=";
    outputHashAlgo = "sha256";
  };

  model = pkgs.qwen38-27b-autoround-int4;
  
  mkInt8Drafter = pkgs.callPackage ./int8-drafter.nix { };
  drafter = mkInt8Drafter { base = pkgs.qwen38-27b-dflash2-zlab; };


  # de-symlink fetchHFModel output
  flatten = name: src: pkgs.runCommand "${name}-flat" { } ''
    mkdir -p $out
    for f in ${src}/*; do
      cp --reflink=auto "$f" "$out/$(basename "$f")"
    done
  '';

  modelFlat = flatten "qwen38-27b-int4" model;
  drafterFlat = flatten "qwen38-27b-dflash2-drafter-int8" drafter;

  engine3090 = pkgs.callPackage ./club3090.nix { };

  launch = pkgs.writeShellScript "sglang-launch" ''
    set -euo pipefail

    # W4A8 is NOT a CLI flag, patching is done by enabling
    bash /etc/club3090/w4a8/install.sh
    bash /etc/club3090/w4a8/install.sh --verify

    export CLUB3090_EFFORT_BUDGET_PY=/etc/club3090/scripts-lib/effort_budget.py
    eval "$(python3 "$CLUB3090_EFFORT_BUDGET_PY" shell-env --engine sglang \
             --default-effort low --low 4096 --medium 16384 --xhigh 32768)"
    bash /etc/club3090/effort-thinking-budget/install.sh

    BASE=(
      --model-path /models/qwen3.8-27b-int4
      --served-model-name qwen3.8-27b
      --quantization auto-round
      --context-length 262144
      --host 0.0.0.0
      --port 30000
      --weight-loader-drop-cache-after-load  # don't pin model weights in RAM
    )

    PARALLEL=(
      --tp-size 2
      --disable-custom-all-reduce
      --attention-backend flashinfer
      --page-size 8
      --kv-cache-dtype fp8_e4m3
    )

    STATE=(
      # -enable-int8-mamba-checkpoint would be awesome, but not supported
      --mamba-ssm-dtype bfloat16
      # down from 32. more or less snapshot count
      --max-mamba-cache-size 24  
      # CAREFUL HERE, might cause hicache writes without restores
      #--mamba-radix-cache-strategy extra_buffer_lazy  # doesn't seem to hurt?
    )

    CAPACITY=(
      # 0.86 to co-exist with whisper-large
      --mem-fraction-static 0.86  # each +0.02 buys ~21264 tokens
      --max-running-requests 2  # a lot of stuff is to support this
      --chunked-prefill-size 2048  # would be nice to bump, but fails
    )

    # !!! speculative-draft-model-quantization is load-bearing !!!
    # otherwise sglang#39087 collapses accept length to 1.
    SPEC=(
      --speculative-algorithm DFLASH
      --speculative-draft-model-path /models/qwen3.8-27b-dflash2-drafter
      --speculative-draft-model-quantization w8a8_int8
    )

    # --preferred-sampling-params is inert on /v1/chat/completions (#39096)
    # presence_penalty cannot be pinned server-side, so a client-side param
    SAMPLER=(
      --chat-template /etc/club3090/template/chat_template.jinja
      --default-chat-template-kwargs
        '{"enable_thinking":true,"default_reasoning_effort":"low"}'
      --sampling-defaults model
      --preferred-sampling-params '{
        "temperature": 1.0,
        "top_p": 0.95,
        "top_k": 20,
        "min_p": 0.0,
        "presence_penalty": 0.0,
        "repetition_penalty": 1.0
      }'
      --enable-strict-thinking
      --enable-cache-report  # meta_info.cached_tokens
      --reasoning-parser qwen3
      --tool-call-parser qwen3_coder
    )

    OBSERVABILITY=(
      --enable-metrics
      --enable-cache-report
      --sleep-on-idle
      --uvicorn-access-log-exclude-prefixes /health /metrics
    )

    # Fit up to a second conversation in RAM
    HICACHE=(
      --enable-hierarchical-cache
      # --hicache-size is an int (GiB), while we need 6-7, so
      --hicache-host-memory-fraction 0.9
      --hicache-io-backend kernel
      --hicache-mem-layout page_first
      # one heavy-hearted knob.
      # write_back hurts single-stream, benefits two-stream,
      # but absence of it turns hicache useless (no restores)
      --hicache-write-policy write_back
    )
    patch -p1 -d /sgl-workspace/sglang \
      < /opt/club3090/sglang-patches/hicache-cap.patch
    export SGLANG_HICACHE_HOST_MEMORY_RESERVE_GIB=4
    export SGLANG_HICACHE_GUARANTEED_GIB=6
    export SGLANG_HICACHE_CAP_GIB=6

    # TODO: try mooncake to RAM as L3 cache

    exec python3 -m sglang.launch_server \
      "''${BASE[@]}" "''${PARALLEL[@]}" "''${STATE[@]}" "''${CAPACITY[@]}" \
      "''${SPEC[@]}" "''${SAMPLER[@]}" "''${OBSERVABILITY[@]}" "''${HICACHE[@]}"
  '';
in
{
  config = {
    networking.firewall.allowedTCPPorts = [ 11111 ];

    environment.persistence."/mnt/persist".directories = [
      { directory = "/var/lib/sglang"; user = "sglang"; group = "sglang"; }
    ];  # the image is huge and should persist

    virtualisation.podman.enable = true;
    hardware.nvidia-container-toolkit.enable = true;

    users.groups.sglang = { gid = 970; };
    users.users.sglang = {  # for capping resources and limiting networking
      isSystemUser = true;
      group = "sglang";
      uid = 970;
      # Rootless podman needs its own subordinate range, monk has 100000-165535
      subUidRanges = [ { startUid = 231072; count = 65536; } ];
      subGidRanges = [ { startGid = 231072; count = 65536; } ];
      home = "/var/lib/sglang";
      createHome = true;
      linger = true;
    };
    systemd.slices."user-${toString config.users.users.sglang.uid}" = {
      sliceConfig = {
        IPAddressAllow = "127.0.0.0/8 ::1/128 192.168.99.0/24 10.202.0.0/16";
        IPAddressDeny = "any";
      };
    };


    virtualisation.oci-containers.containers.sglang = {
      inherit image;
      ports = [ "192.168.99.53:11111:30000" ];  # only 11111 port is published
      volumes = [
        "${modelFlat}:/models/qwen3.8-27b-int4:ro"
        "${drafterFlat}:/models/qwen3.8-27b-dflash2-drafter:ro"
        "${engine3090.w4a8}:/etc/club3090/w4a8:ro"
        "${engine3090.effortBudget}:/etc/club3090/effort-thinking-budget:ro"
        "${engine3090.scriptsLib}:/etc/club3090/scripts-lib:ro"
        "${engine3090.chatTemplate}:/etc/club3090/template:ro"
        "${launch}:/usr/local/bin/sglang-launch:ro"
        "${./patches}:/opt/club3090/sglang-patches:ro"
        #"/mnt/persist/tmp/bench/kv-offload/hicache:/kv-hdd"
      ];
      entrypoint = "/bin/bash";
      cmd = [ "/usr/local/bin/sglang-launch" ];
      environment = {
        HF_HUB_OFFLINE = "1"; # weights come from the store, never from HF
        TRANSFORMERS_OFFLINE = "1";
        NCCL_DEBUG = "WARN";
        #SGLANG_HICACHE_FILE_BACKEND_STORAGE_DIR = "/kv-hdd";
      };
      extraOptions = [
        "--device=nvidia.com/gpu=all"  # CDI; supplied by sglang-cdi.service below
        "--shm-size=16g"  # TP=2 NCCL buffers
        "--ulimit" "memlock=-1:-1"
        "--health-cmd=curl -sf http://127.0.0.1:30000/health || exit 1"
        "--health-interval=10s"
        "--health-timeout=10s"
        "--health-retries=90"
        "--health-start-period=120s"  # and that's optimistic
      ];
      podman = {
        user = "sglang";
        sdnotify = "healthy";  # ready means it answers
      };
      autoStart = true;
    };

    #systemd.tmpfiles.rules = [
    #  "d /mnt/persist/tmp/bench/kv-offload/hicache 0755 sglang sglang -"
    #];

    systemd.services.sglang-image-load = {
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      before = [ "podman-sglang.service" ];
      requiredBy = [ "podman-sglang.service" ];
      unitConfig.RequiresMountsFor = "/mnt/persist";
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = "sglang";
        Environment = [
          "XDG_DATA_HOME=/var/lib/sglang/.local/share"
          "TMPDIR=/var/lib/sglang/tmp"  # must have tons of space free
          # for newuidmap/newgidmap setuids
          "PATH=${pkgs.podman}/bin:/run/wrappers/bin:/run/current-system/sw/bin"
        ];
      };
      preStart = "install -d -o sglang -g sglang -m 700 /var/lib/sglang/tmp";
      script = ''
        if ! podman image exists "${image}"; then
          echo "importing ${imageTag} from the Nix store"
          podman load -i ${imageArchive}
        else
          echo "${image} already present"
        fi
      '';
    };

    systemd.services.podman-sglang = {
      after = [ "network-online.target" "nvidia-container-toolkit-cdi-generator.service" ];
      requires = [ "nvidia-container-toolkit-cdi-generator.service" ];
      wants = [ "network-online.target" ];
      unitConfig.RequiresMountsFor = lib.mkAfter [ "/mnt/persist" ];
      serviceConfig.Environment = [
        "PODMAN_SYSTEMD_UNIT=%n"
        "XDG_DATA_HOME=/var/lib/sglang/.local/share"  # reuse image
        # same reason as in sglang-image-load
        "PATH=${pkgs.podman}/bin:/run/wrappers/bin:/run/current-system/sw/bin"
      ];
      # The oci-containers module already sets Type=notify, Restart=on-failure and
      # TimeoutStartSec=0 (no start deadline), which is what a ~10 minute weight load
      # plus graph capture needs - do not reintroduce a start timeout here, it would
      # kill the boot mid-capture and read like an engine bug.
      serviceConfig.RestartSec = "30s";
    };

    environment.systemPackages = [
      (pkgs.writeShellScriptBin "bench-sglang" ''
        exec ${pkgs.llama-benchy-nice}/bin/llama-benchy-nice \
          --base-url http://192.168.99.53:11111/v1 \
          --model qwen3.8-27b \
          --tokenizer qwen3.8 \
          --pp 256 8192 16384 32768 65536 131072 196608 260096 \
          --tg 1024 --runs 5 --no-cache \
          --extra-body "return_token_ids=false" \
          "$@"
      '') # that return_token_ids=false is a must
      (pkgs.writers.writePython3Bin "sglang-self-check" {
        libraries = [ pkgs.python3Packages.requests ];
        flakeIgnore = [ "W292" ];  # no newline at end of file, it gets eaten
      } (lib.fileContents ./self-check.py))
    ];
  };
}
