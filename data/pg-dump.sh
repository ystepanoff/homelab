#!/usr/bin/env bash
# Nightly logical dump of all postgres databases so Duplicati backs up a
# restorable snapshot rather than only the live (non-crash-consistent)
# data directory. Run from cron before Duplicati's 03:00 backup.
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
DUMP_DIR="$SCRIPT_DIR/dumps"
KEEP=7

POSTGRES_USER="$(grep '^POSTGRES_USER=' "$SCRIPT_DIR/../.env" | cut -d= -f2-)"

mkdir -p "$DUMP_DIR"
docker exec postgres pg_dumpall -U "$POSTGRES_USER" | gzip > "$DUMP_DIR/postgres-$(date +%F).sql.gz.tmp"
mv "$DUMP_DIR/postgres-$(date +%F).sql.gz.tmp" "$DUMP_DIR/postgres-$(date +%F).sql.gz"

ls -1t "$DUMP_DIR"/postgres-*.sql.gz | tail -n +$((KEEP + 1)) | xargs -r rm --
