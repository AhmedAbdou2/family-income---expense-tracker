# Docker harness (Supabase-like Postgres)

These files run the migration + isolation-test suite against a plain
`postgres:16-alpine` container instead of the cloud. They are **not** part of
the app — they exist so a hosted-only behaviour can be reproduced (and fixed)
locally.

```
supabase/tests/support/stub_supabase.sql   # stub WITH the storage schema
supabase/tests/support/stub_no_storage.sql # stub WITHOUT the storage schema
supabase/tests/support/privcheck17.sql     # privilege matrix / grants audit
supabase/tests/support/prove_delete_guard.sql # proof the delete guard is honest
supabase/tests/support/backup_tables.generated.sql # GENERATED registry (do not edit)
supabase/tests/support/check_backup_tables.sql     # backup completeness check
tool/docker/validate.sh                    # build a fresh DB + all migrations
```

## Start the container

```sh
docker run --name rls-pg -e POSTGRES_PASSWORD=postgres -d postgres:16-alpine
```

The scripts assume the container name `rls-pg` (override with
`RLS_PG_CONTAINER`).

## Build a fresh DB and apply every migration

```sh
tool/docker/validate.sh fresh18          # storage stub (default)
tool/docker/validate.sh bare18 bare      # no storage schema
```

`validate.sh` also runs the **backup completeness check** after the migrations:
it loads the generated registry of exported/excluded tables and fails unless
every `public` base table is either exported or explicitly excluded (with a
reason), every registered table exists, and every `numeric` column of an
exported table is read as `::text` (never as a float). The registry is generated
from the Dart source of truth, so regenerate it after editing
`lib/features/backup/domain/backup_tables.dart`:

```sh
dart run tool/gen_backup_tables_sql.dart
```

See `docs/backup.md` for the feature itself.

## Run the isolation test and the privilege matrix

```sh
docker exec -i rls-pg psql -U postgres -v ON_ERROR_STOP=1 -d fresh17 \
  -f - < supabase/tests/20261006900001_household_isolation.sql

docker exec -i rls-pg psql -U postgres -v ON_ERROR_STOP=1 -d fresh17 \
  -f - < supabase/tests/support/privcheck17.sql
```

Expect the isolation test to print `ALL RLS ISOLATION TESTS PASSED`, and the
privcheck's `--- violations (should be empty) ---` query to return **0 rows**.

The isolation test's receipts section asserts against `storage.buckets`, so it
only runs on the `storage` stub — never on `bare`.

## What the stubs simulate

`stub_supabase.sql` creates the pieces of Supabase the project actually uses:

- roles `anon`, `authenticated`, `service_role`;
- `auth.users` + `auth.uid()` (reads `request.jwt.claims`);
- `storage.buckets` / `storage.objects` with the columns we touch;
- `storage.foldername(name)` — the real path-token helper;
- **RLS enabled on `storage.buckets` with NO read policy for
  `authenticated`/`anon`**, exactly like hosted Supabase, so a metadata read
  made as `authenticated` returns zero rows (this caught a real bug — commit
  `ef637d4`);
- **`protect_objects_delete`** — a `BEFORE DELETE ... FOR EACH STATEMENT`
  trigger raising SQLSTATE `42501` ("Direct deletion from storage tables is not
  allowed") unless `storage.allow_delete_query = 'true'` (the GUC the Storage
  API sets when it deletes on a user's behalf), and **`update_objects_updated_at`**
  — `BEFORE UPDATE ... FOR EACH ROW` stamping `updated_at`. Same names, timing
  and granularity as the cloud, so a direct `storage.objects` delete that
  forgets the GUC fails here too instead of silently passing.

`stub_no_storage.sql` is the same minus the entire `storage` schema, to prove
migration 17's storage block is skipped cleanly on a plain Postgres.

## Prove the stub is honest

```sh
docker exec -i rls-pg psql -U postgres -d fresh17 \
  -f - < supabase/tests/support/prove_delete_guard.sql
```

It shows the delete is rejected with `42501` without the GUC (row survives) and
that the row really disappears once `storage.allow_delete_query = 'true'` — i.e.
the guard is not a no-op and cannot mask a skipped delete.

## What the stubs do NOT simulate (still cloud-only)

The Storage **API** and the service behind it:

- object upload/download over HTTP, and signed-URL creation + expiry;
- the bucket's 5 MiB / MIME allow-list enforced at the API layer (not RLS);
- the bucket's public/private flag as seen through the dashboard;
- any hosted `storage.objects` column/constraint/trigger beyond the two
  mirrored above (direct inserts are already proven on the cloud).

See the **Phase 4b cloud checklist** in `AGENTS.md` for the manual cloud steps.
