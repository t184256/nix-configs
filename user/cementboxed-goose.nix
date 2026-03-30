{ pkgs, ... }:

let
  VM_USERNAME = "sloppy";
  VM_HOSTNAME = "slopfest";

  cementbox-src = pkgs.fetchgit {
    url = "https://github.com/t184256/cementbox";
    rev = "6c0e81ec10242449d9b5fc875b238897c029ae00";
    hash = "sha256-P01xz2uFcl12yxXGw+ug1jhYwN+cIf5cekrRVHDt0FU=";
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
  cementboxed-goose = pkgs.writeShellScriptBin "cementboxed-goose" ''
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

    FINAL_SSH_EXTRA_OPTS=-t \
      exec ${cementbox} \
        --rw-share "$(pwd)" "/home/${VM_USERNAME}/workspace" \
        "''${EXTRA_WORKTREE[@]}" \
        --chdir "/home/${VM_USERNAME}/workspace" \
        ${VM_USERNAME}@${VM_HOSTNAME} \
        goose "$@"
  '';
in
{
  home.packages = [ cementboxed-goose ];
}
