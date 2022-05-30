#!/usr/bin/env bash

OLD=$OLD
NEW=$NEW

set -eux
# XXX it's perhaps advisable to stop all services that depend on postgresql
systemctl stop postgresql

# XXX replace `<new version>` with the psqlSchema here
export NEWDATA="/var/lib/postgresql/$NEW"

nix build "nixpkgs#postgresql_$OLD" -o /tmp/postgresql_$OLD
nix build "nixpkgs#postgresql_$NEW" -o /tmp/postgresql_$NEW

# XXX specify the postgresql package you'd like to upgrade to
export NEWBIN="/tmp/postgresql_$NEW/bin"

export OLDDATA="/var/lib/postgresql/$OLD"
export OLDBIN="/tmp/postgresql_$OLD/bin"

sudo install -d -m 0700 -o postgres -g postgres "$NEWDATA"
cd "$NEWDATA"
sudo -u postgres $NEWBIN/initdb -D "$NEWDATA"

sudo -u postgres $NEWBIN/pg_upgrade \
--old-datadir "$OLDDATA" --new-datadir "$NEWDATA" \
--old-bindir $OLDBIN --new-bindir $NEWBIN \
"$@"
