{ pkgs, ... }:

let
  VM_USERNAME = "sloppy";
  VM_HOSTNAME = "slopfest";

  cementbox-src = pkgs.fetchgit {
    url = "https://github.com/t184256/cementbox";
    rev = "ac3649304ade2ac68039c816e75499e40377848e";
    hash = "sha256-+8Hy5KpDa7Eb2+s9WRzePtv2MgQxIWUAFm6L/nuV0wg=";
  };

  sftp-server-closure = pkgs.closureInfo { rootPaths = [ pkgs.openssh ]; };

  cementbox = pkgs.runCommand "cementbox" {} ''
    cp ${cementbox-src}/cementbox $out
    chmod +x $out
    closure_binds=$(
      sed 's|.*|--ro-bind & &|' ${sftp-server-closure}/store-paths | tr '\n' ' '
    )
    substituteInPlace $out \
      --replace-fail '/usr/libexec/openssh/sftp-server' \
        '${pkgs.openssh}/libexec/sftp-server' \
      --replace-fail \
        '--ro-bind /usr/libexec/openssh /usr/libexec/openssh' \
        "$closure_binds" \
      --replace-fail '--ro-bind /usr/lib /usr/lib' "" \
      --replace-fail '--ro-bind /lib64 /lib64' ""
  '';

  # see example-cementboxed-claude in cementbox
  cementboxed-pi = pkgs.writeShellScriptBin "cementboxed-pi" ''
    set -Eeuo pipefail; shopt -s inherit_errexit

    # Git worktrees: .git is a file pointing outside the current dir.
    # Mount the main .git dir at its original path so the pointer resolves.
    EXTRA_WORKTREE=()
    if git rev-parse --git-dir &>/dev/null; then
      GIT_DIR=$(realpath "$(git rev-parse --git-dir)")
      GIT_COMMON_DIR=$(realpath "$(git rev-parse --git-common-dir)")
      if [[ "$GIT_DIR" != "$GIT_COMMON_DIR" ]]; then
        GIT_TOP=''${GIT_COMMON_DIR#/}
        GIT_TOP=/''${GIT_TOP%%/*}
        EXTRA_WORKTREE=(
          --overlay-src "$GIT_TOP"
          --tmp-overlay "$GIT_TOP"
          --rw-share "$GIT_COMMON_DIR" "$GIT_COMMON_DIR"
        )
      fi
    fi

    CEMENTBOX_FINAL_BWRAP_PREFIX='trap "" INT; exec' \
    CEMENTBOX_FINAL_SSH_EXTRA_OPTS=-t \
      exec ${cementbox} \
        --rw-share "$(pwd)" "/home/${VM_USERNAME}/workspace" \
        "''${EXTRA_WORKTREE[@]}" \
        --chdir "/home/${VM_USERNAME}/workspace" \
        ${VM_USERNAME}@${VM_HOSTNAME} \
        pi "$@"
  '';
in
{
  home.packages = [ cementboxed-pi ];
}
