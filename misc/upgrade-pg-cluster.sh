#!/usr/bin/env bash

set -eux

# run as e.g.: OLD=15 NEW=17 ./upgrade-pg-cluster.sh
: "${OLD:?set to the old postgresql major version}"
: "${NEW:?set to the new postgresql major version}"

# XXX it's perhaps advisable to stop all services that depend on postgresql
systemctl stop postgresql

export NEWDATA="/var/lib/postgresql/$NEW"

nix build "nixpkgs#postgresql_$OLD" -o "/tmp/postgresql_$OLD"
nix build "nixpkgs#postgresql_$NEW" -o "/tmp/postgresql_$NEW"

export NEWBIN="/tmp/postgresql_$NEW/bin"

export OLDDATA="/var/lib/postgresql/$OLD"
export OLDBIN="/tmp/postgresql_$OLD/bin"

sudo -u postgres "$NEWBIN/initdb" -D "$NEWDATA"

sudo -u postgres "$NEWBIN/pg_upgrade" \
  --old-datadir "$OLDDATA" --new-datadir "$NEWDATA" \
  --old-bindir "$OLDBIN" --new-bindir "$NEWBIN" \
  "$@"
