#!/usr/bin/env bash
# Build a fresh Supabase-like database inside the local Postgres container and
# apply every migration in filename order, mirroring what the Supabase SQL
# Editor will do. Used to run the isolation test + privilege matrix locally.
#
# Usage:
#   tool/docker/validate.sh <dbname> [storage|bare]
#
#   storage (default) -> stub WITH the storage schema (bucket, policies and the
#                        hosted RLS + trigger behaviour). Use for the isolation
#                        test, which asserts against storage.buckets.
#   bare              -> stub WITHOUT the storage schema. Proves migration 17
#                        still applies on a plain Postgres.
#
# Env: RLS_PG_CONTAINER (default: rls-pg)
# See tool/docker/README.md.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

DB="${1:-fresh17}"
MODE="${2:-storage}"
CONTAINER="${RLS_PG_CONTAINER:-rls-pg}"

case "$MODE" in
  storage) STUB="supabase/tests/support/stub_supabase.sql" ;;
  bare)    STUB="supabase/tests/support/stub_no_storage.sql" ;;
  *) echo "unknown mode: $MODE (use storage|bare)" >&2; exit 2 ;;
esac

psql_run() { docker exec -i "$CONTAINER" psql -U postgres -v ON_ERROR_STOP=1 "$@"; }

echo ">> reset database $DB"
psql_run -c "drop database if exists $DB;" >/dev/null
psql_run -c "create database $DB;" >/dev/null

echo ">> stub ($MODE)"
psql_run -d "$DB" -f - < "$STUB" >/dev/null

for f in supabase/migrations/*.sql; do
  echo ">> $f"
  psql_run -d "$DB" -f - < "$f" >/dev/null
done

echo ">> backup table completeness check"
# The registry is generated from the Dart source of truth
# (lib/features/backup/domain/backup_tables.dart) so the exporter and this check
# can never disagree. `\i` resolves relative to psql's cwd (the container), so
# the two files are concatenated and piped instead.
cat supabase/tests/support/backup_tables.generated.sql \
    supabase/tests/support/check_backup_tables.sql | psql_run -d "$DB" -f -

echo "MIGRATIONS OK on $DB ($MODE stub)"
