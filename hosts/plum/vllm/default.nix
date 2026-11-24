{ config, lib, pkgs, ... }:

# Inkling 2 Mini on 2x RTX 3090 NVLink via vLLM.
# The container never touches the network.
# TODO: switch to pkgs.vllm once Ampere kernels are mailined and reach nixpkgs.

# The overarching goal is having an interactive machine (>120 tg)
# so that it can supplement the more batch-oriented grapefruit.

# bench-vllm --nothink:
# target      pp      ttft   avg pp   decode tps    gen
#    256     256    0.076s     3347        203.5   2033
#   8192    8192    1.430s     5730        184.5   2036
#  16384   16384    2.954s     5547        176.3   2037
#  32768   32768    6.297s     5204        178.4   2036
#  65536   65536   14.229s     4606        174.9   2037
# 131072  131072   35.011s     3744        145.2   2039
# 196608  196608   62.345s     3154        144.3   2039
# 262144  262144   96.310s     2722        146.4   2034
# 325632  325632  135.460s     2404        118.4   2034

# bench-vllm --nothink:
# target      pp      ttft   avg pp   decode tps    gen
#    256     256    0.077s     3337        185.9   2036
#   8192    8192    1.433s     5717        188.3   2038
#  16384   16384    2.953s     5548        181.9   2039
#  32768   32768    6.300s     5201        178.7   2040
#  65536   65536   14.231s     4605        165.0   2040
# 131072  131072   35.013s     3744        149.7   2035
# 196608  196608   62.350s     3153        132.7   2037
# 262144  262144   96.323s     2722        131.6   2038
# 325632  325632  135.473s     2404        104.1   2036

# bench-vllm --think --concurrency 2:
# target      pp      ttft   avg pp   decode tps    gen
#    256     256    0.152s     1681        175.6   2036
#    256     256    0.145s     1765        167.7   2035
#    256     256    0.152s     1681        175.6   2034
#    256     256    0.146s     1761        167.7   2034
#    256     256    0.152s     1681        159.7   2034
#    256     256    0.146s     1761        159.6   2034
#   8192    8192    1.595s     5137        151.1   2037
#   8192    8192    2.248s     3980        153.7   2037
#   8192    8192    1.595s     5137        153.9   2037
#   8192    8192    2.246s     3982        152.5   2038
#   8192    8192    2.898s     2827        153.9   2037
#   8192    8192    2.246s     3982        155.1   2037
#  16384   16384    3.117s     5257        140.8   2039
#  16384   16384    4.533s     4005        143.5   2039
#  16384   16384    5.949s     2754        146.2   2039
#  16384   16384    4.533s     4006        143.5   2040
#  16384   16384    3.117s     5257        146.1   2039
#  16384   16384    4.528s     4008        146.1   2040
#  32768   32768    6.474s     5061        102.0   2037
#  32768   32768    9.584s     3821        104.8   2036
#  32768   32768    6.477s     5059        107.6   2036
#  32768   32768    9.585s     3820        109.5   2036
#  32768   32768    6.477s     5059        107.6   2037
#  32768   32768    9.584s     3820        109.5   2036
#  65536   65536   14.416s     4546         76.0   2037
#  65536   65536   21.529s     3417        102.2   2038
#  65536   65536   28.641s     2288        128.4   2039
#  65536   65536   21.529s     3417        102.2   2038
#  65536   65536   14.416s     4546         78.0   2039
#  65536   65536   21.529s     3417        103.2   2039
# 131072  131072   35.225s     3721         39.7   2041
# 131072  131072   52.866s     2790         77.8   2042
# 131072  131072   35.225s     3721         41.0   2041
# 131072  131072   52.866s     2790         78.5   2040
# 131072  131072   70.508s     1859        104.7   2038
# 131072  131072   52.866s     2790         72.9   2040
# 196608  196608   62.586s     3141         26.1   2034
# 196608  196608   94.115s     2353         65.4   2034
# 196608  196608   62.586s     3141         26.1   2034
# 196608  196608   94.115s     2353         58.9   2034
# 196608  196608   62.586s     3141         26.1   2034
# 196608  196608   94.104s     2353         58.9   2034
# 262144  262144   96.551s     2715         18.2   2038
# 262144  262144  145.423s     2032         56.5   2038
# 262144  262144   96.551s     2715         18.2   2038
# 262144  262144  145.423s     2032         54.6   2038
# 262144  262144   96.551s     2715         18.2   2038
# 262144  262144  145.423s     2032         54.6   2038
# 325632  325632  135.596s     2401        111.5   2033
# 325632  325632  212.241s     1764        113.1   2030
# 325632  325632  135.596s     2401        114.8   2033
# 325632  325632  211.930s     1766        113.1   2030
# 325632  325632  135.596s     2401        114.8   2031
# 325632  325632  211.916s     1766        114.6   2032

# On updates, run vllm-self-check and update benchmark numbers above.
# Results are rather noisy, +-10% is normal even with the default --runs 5.

let
  image = pkgs.dockerTools.pullImage {
    imageName = "vllm/vllm-openai";
    imageDigest =
      "sha256:c2dc759f5984f69c1e2418c6af7c26eb756f5ed2a8934c768ae1253645d1449e";
    arch = "amd64";
    finalImageName = "docker.io/vllm/vllm-openai";
    finalImageTag = "inkling-2-mini";
    outputHash = "sha256-pPhWBA8dMt6P7qcAnniP5sESBxrdqYR2EkvGw8terlI=";
    outputHashAlgo = "sha256";
  };

  peaster = pkgs.fetchFromGitHub {
    owner = "peaster";
    repo = "inkling-2-mini-vllm-2x3090";
    rev = "5c28b63df79ee5c069838312b72b328ea4189c62";
    hash = "sha256-nqsb98NlqFqkUMbGSV45vsPnGkv3ONKYAp7AoiEjqFc=";
  };

  # general-arch kernels: the per-commit wheel of the base image's vLLM
  # commit (bf4a317ee); only the two extension .so files are taken from it
  wheel = pkgs.fetchurl {
    url = "https://wheels.vllm.ai/bf4a317ee65dba1198e420be5253334f23f2fbdc/"
      + "vllm-0.34.0rc1.dev1104%2Bgbf4a317ee-cp38-abi3-"
      + "manylinux_2_28_x86_64.whl";
    hash = "sha256-riQyYCaZecX+VYLY9Jp0p3jRwT1pmBLTxdZmrufGY6Y=";
  };

  sm86 = pkgs.stdenvNoCC.mkDerivation {
    pname = "vllm-inkling-sm86";
    version = "g7cb5dae22";
    src = peaster;
    nativeBuildInputs = [ pkgs.python3 ];
    dontBuild = true;
    installPhase = ''
      mkdir -p $out/libs $out/patches
      install -m 0755 ${./patch.sh} $out/patch.sh
      cp ${peaster}/apply_sm86_patch.py $out/patches/
      cp ${peaster}/patches/sm86-tune.diff \
         ${peaster}/patches/draft_vocab_rank.json $out/patches/
      install -m 0644 ${./effort-budget.diff} $out/patches/effort-budget.diff
      ${pkgs.python3}/bin/python3 - ${wheel} $out/libs <<'EOF'
      import sys, zipfile
      with zipfile.ZipFile(sys.argv[1]) as z:
          for lib in ("vllm/_C_stable_libtorch.abi3.so",
                     "vllm/_moe_C_stable_libtorch.abi3.so"):
              name = lib.rsplit("/", 1)[1]
              with z.open(lib) as s, open(sys.argv[2] + "/" + name, "wb") as d:
                  d.write(s.read())
      EOF
    '';
  };

  model = pkgs.inkling2-mini;
  flatten = name: src: pkgs.runCommand "${name}-flat" { } ''
    mkdir -p $out
    for f in ${src}/*; do
      cp --reflink=auto "$f" $out/"$(basename "$f")"
    done
  '';
  modelFlat = flatten "inkling2-mini-flat" model;
  imageName = "docker.io/vllm/vllm-openai:inkling-2-mini";

  launch = pkgs.writeShellScript "vllm-launch" ''
    set -Eeuo pipefail; shopt -s inherit_errexit
    site="$(python3 - <<'EOF'
    import sysconfig
    print(sysconfig.get_paths()["purelib"])
    EOF
    )"
    bash /opt/club3090/vllm-sm86/patch.sh "$site" /opt/club3090/vllm-sm86
    # `none` is not an Inkling template level; map it onto `minimal`.
    # Host-RAM tier is 23.27 GB ~= 512k tokens of evictable KV.
    exec vllm serve /model \
      --served-model-name inkling-2-mini \
      --tensor-parallel-size 2 \
      --max-model-len 327680 \
      --max-num-batched-tokens 1024 \
      --no-async-scheduling \
      --max-num-seqs 2 \
      --kv-cache-memory-bytes 11178169058 \
      --kv-transfer-config \
        '{"kv_connector":"OffloadingConnector",
          "kv_role":"kv_both",
          "kv_connector_extra_config":{"cpu_bytes_to_use":23270000000}}' \
      --reasoning-parser inkling \
      --reasoning-effort-map '{"none": "minimal"}' \
      --enable-auto-tool-choice \
      --tool-call-parser inkling \
      --speculative-config \
        '{"method":"dspark",
          "num_speculative_tokens":7,
          "draft_sample_method":"probabilistic",
          "num_speculative_tokens_per_batch_size":[[1,1,7],[2,16,3]]}' \
      --enable-prompt-tokens-details \
      --enable-per-request-metrics \
      --per-request-spec-decode-metrics summary \
      --disable-access-log-for-endpoints \
        /health,/metrics,/v1/loads,/props,/v1/props \
      --host 0.0.0.0 --port 8000
  '';
in
{
  config = {
    networking.firewall.allowedTCPPorts = [ 11111 ];

    # the image is huge and should persist,
    # so should the triton/humming/flashinfer JIT caches
    environment.persistence."/mnt/persist".directories = [
      { directory = "/var/lib/vllm"; user = "vllm"; group = "vllm"; }
    ];

    virtualisation.podman.enable = true;
    hardware.nvidia-container-toolkit.enable = true;

    users.groups.vllm = { gid = 971; };
    users.users.vllm = {  # for capping resources and limiting networking
      isSystemUser = true;
      group = "vllm";
      uid = 971;
      # rootless podman needs its own subordinate range
      subUidRanges = [ { startUid = 296608; count = 65536; } ];
      subGidRanges = [ { startGid = 296608; count = 65536; } ];
      home = "/var/lib/vllm";
      createHome = true;
      linger = true;
    };
    systemd.slices."user-${toString config.users.users.vllm.uid}" = {
      sliceConfig = {
        IPAddressAllow = "127.0.0.0/8 ::1/128 192.168.99.0/24 10.202.0.0/16";
        IPAddressDeny = "any";
      };
    };

    virtualisation.oci-containers.containers.vllm = {
      image = imageName;
      ports = [ "192.168.99.53:11111:8000" ];
      volumes = [
        "${modelFlat}:/model:ro"
        "${sm86}:/opt/club3090/vllm-sm86:ro"
        "${launch}:/usr/local/bin/vllm-launch:ro"
        # boot is ~40 s warm, several minutes cold
        "/var/lib/vllm/triton:/root/.triton/cache"
        "/var/lib/vllm/humming:/root/.humming"
        "/var/lib/vllm/flashinfer:/root/.cache/flashinfer"
      ];
      entrypoint = "/bin/bash";
      cmd = [ "/usr/local/bin/vllm-launch" ];
      environment = {
        HF_HUB_OFFLINE = "1";  # weights come from the store, never from HF
        TRANSFORMERS_OFFLINE = "1";
        VLLM_NO_USAGE_STATS = "1";
        DO_NOT_TRACK = "1";
        NCCL_DEBUG = "WARN";
        CUDA_DISABLE_PERF_BOOST = "1";
        OMP_NUM_THREADS = "1";
        NCCL_CUMEM_ENABLE = "0";
        NCCL_P2P_LEVEL = "NVL"; # pin NCCL P2P to NVLink, not PCIe
        # Everything but convtail: the tail-only conv-state manager has
        # no resumable state once a conversation is demoted, so the CPU
        # kv tier stops serving it; stock sliding-window layout instead.
        INKLING_SM86_TUNE = "gemv,fold,seg3,ctrl,humming,humming_big,"
          + "align,far,router,tiles,adaptive,dvocab";
        # no expandable_segments:
        #  custom all-reduce shares buffers over CUDA IPC,
        #  which that allocator cannot export
        PYTORCH_CUDA_ALLOC_CONF = "max_split_size_mb:512";
      };
      extraOptions = [
        "--device=nvidia.com/gpu=all"  # CDI, see cdi-generator below
        "--shm-size=32g"  # must fit cpu_bytes_to_use + room for NCCL buffers
        "--ulimit" "memlock=-1:-1"
        "--health-cmd=curl -sf http://127.0.0.1:8000/health || exit 1"
        "--health-interval=10s"
        "--health-timeout=10s"
        "--health-retries=90"
        "--health-start-period=900s"  # cold JIT caches, generous
      ];
      podman.user = "vllm";
      podman.sdnotify = "healthy";  # ready means it answers
      autoStart = true;
    };

    systemd.services.vllm-image-load = {
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      before = [ "podman-vllm.service" ];
      requiredBy = [ "podman-vllm.service" ];
      unitConfig.RequiresMountsFor = "/mnt/persist";
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = "vllm";
        Environment = [
          "XDG_CONFIG_HOME=/var/lib/vllm/podman/config"
          "XDG_DATA_HOME=/var/lib/vllm/podman/data"
          "XDG_CACHE_HOME=/var/lib/vllm/podman/cache"
          "TMPDIR=/var/lib/vllm/tmp"  # must have tons of space free
          "PATH=${pkgs.podman}/bin:/run/wrappers/bin:/run/current-system/sw/bin"
        ];
      };
      # podman refuses to bind-mount a host path that does not exist,
      # so every mount target below has to be provisioned first
      preStart = ''
        install -d -o vllm -g vllm -m 700 /var/lib/vllm/tmp
        install -d -o vllm -g vllm -m 700 /var/lib/vllm/podman
        install -d -o vllm -g vllm -m 700 /var/lib/vllm/podman/config
        install -d -o vllm -g vllm -m 700 /var/lib/vllm/podman/data
        install -d -o vllm -g vllm -m 700 /var/lib/vllm/podman/cache
        install -d -o vllm -g vllm -m 755 /var/lib/vllm/triton
        install -d -o vllm -g vllm -m 755 /var/lib/vllm/humming
        install -d -o vllm -g vllm -m 755 /var/lib/vllm/flashinfer
      '';
      script = ''
        if ! podman image exists "${imageName}"; then
          echo "importing inkling-2-mini from the Nix store"
          podman load -i ${image}
        else
          echo "${imageName} already present"
        fi
      '';
    };

    systemd.services.podman-vllm = {
      after = [
        "network-online.target"
        "nvidia-container-toolkit-cdi-generator.service"
      ];
      requires = [ "nvidia-container-toolkit-cdi-generator.service" ];
      wants = [ "network-online.target" ];
      unitConfig.RequiresMountsFor = lib.mkAfter [ "/mnt/persist" ];
      serviceConfig.Environment = [
        "PODMAN_SYSTEMD_UNIT=%n"
        "XDG_CONFIG_HOME=/var/lib/vllm/podman/config"
        "XDG_DATA_HOME=/var/lib/vllm/podman/data"  # reuse the loaded image
        "XDG_CACHE_HOME=/var/lib/vllm/podman/cache"
        "PATH=${pkgs.podman}/bin:/run/wrappers/bin:/run/current-system/sw/bin"
      ];
      # oci-containers gives Type=notify and Restart=on-failure;
      # sdnotify=healthy means the timeout covers kernel compilation,
      # which takes minutes on a cold JIT cache
      serviceConfig.TimeoutStartSec = lib.mkForce "900s";  # over oci's 0
      serviceConfig.RestartSec = "30s";
    };

    environment.systemPackages = [
      (pkgs.writeShellScriptBin "bench-vllm" ''
        exec ${pkgs.llama-benchy-nice}/bin/llama-benchy-nice \
          --base-url http://192.168.99.53:11111/v1 \
          --model inkling-2-mini \
          --tokenizer inkling-2-mini \
          --pp 256 8192 16384 32768 65536 131072 196608 262144 325632 \
          --tg 2048 --runs 5 --no-cache \
          "$@"
      '')
      (pkgs.writers.writePython3Bin "vllm-self-check" {
        libraries = [ pkgs.python3Packages.requests ];
        flakeIgnore = [ "W292" ];  # no newline at end of file, it gets eaten
      } (lib.fileContents ./self-check.py))
    ];
  };
}
