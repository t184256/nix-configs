{ inputs, pkgs, lib, ... }:

# Luce DFlash inference server for plum (dual RTX 3090).
#
# Single-GPU mode: target + draft both on GPU 1. PCIe P2P between the two
# RTX 3090s is unavailable (no NVLink), so any dual-GPU mode pays host-
# staging on every speculative step, negating the DFlash gain.
# Port 8002 (distinct from vllm on 8001). Mutually exclusive with vllm.
#
#   systemctl start lucebox-dflash
#   systemctl stop  lucebox-dflash

let
  pkgsCuda = import inputs.nixpkgs {
    system = pkgs.system;
    config = { cudaSupport = true; allowUnfree = true; };
    overlays = [ (import ../../overlays/lucebox.nix) ];
  };

  server = pkgsCuda.lucebox-dflash-server;
  target = pkgs.qwen36-27b-q4kxl;        # UD-Q4_K_XL GGUF (~17.6 GiB)
  draft  = pkgs.qwen36-27b-dflash-draft; # safetensors dir (~3.5 GiB)

  budget = 22;    # DDTree speculation budget (z-lab recommendation)
  # GPU 1: target only (~17.1 GiB on GPU, tok_embd CPU-only) → ~6.5 GiB for
  # KV at Q4_0 (64 KB/token) ≈ 104K tokens headroom. 65536 uses ~4 GiB.
  maxCtx = 65536;
  port   = 8002;

  startScript = pkgs.writeShellScript "lucebox-dflash-start" ''
    exec ${server}/bin/lucebox-dflash-server \
      --target ${target} \
      --draft ${draft} \
      --target-gpu=1 \
      --draft-gpu=0 \
      --draft-feature-mirror \
      --tokenizer Qwen/Qwen3.6-27B \
      --budget ${toString budget} \
      --max-ctx ${toString maxCtx} \
      --host 127.0.0.1 \
      --port ${toString port}
  '';
      #--target-gpu=1 \
      #--draft-gpu=0 \
      #--target-gpus=0,1 \
      #--target-layer-split=1,1 \

in

{
  environment.persistence."/mnt/persist".directories =
    [ "/var/lib/lucebox" ];

  systemd.services.lucebox-dflash = {
    description = "Luce DFlash: Qwen3.6-27B UD-Q4_K_XL + DFlash";
    after = [ "multi-user.target" ];
    serviceConfig = {
      User  = "lucebox";
      Group = "lucebox";
      ExecStart = startScript;
      Environment = [
        # libcuda.so lives here on NixOS; libcudart.so is in test_dflash RPATH
        "LD_LIBRARY_PATH=/run/opengl-driver/lib"
      ];
      PrivateDevices = false;
      PrivateTmp     = true;
      ProtectHome    = true;
      StateDirectory = "lucebox";
      Restart        = "on-failure";
      RestartSec     = "10s";
    };
  };

  users.groups.lucebox = { };
  users.users.lucebox = {
    isSystemUser = true;
    group        = "lucebox";
    extraGroups  = [ "video" "render" ];
    home         = "/var/lib/lucebox";
  };

  networking.firewall.allowedTCPPorts = [ port ];
}
