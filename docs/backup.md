# Household backup (Phase 5a)

Two different things are often both called "backup". This document keeps them
strictly apart.

| | In-app backup (this feature) | Database dump (you run it) |
|---|---|---|
| Who | The household **owner**, from the app | You, on your own machine |
| What | A **readable copy** (ZIP) of the household's rows + receipt files | A restorable **SQL** dump of the database |
| Restore | **No** - it is not a restore | Yes (with `psql`/Supabase) |
| Encrypted | **No** | **No** (a plain `.sql` file) |
| Receipt files | Included (unless data-only) | **Not included** |

## 1. The in-app backup (Settings -> Backup, owner only)

The owner opens **Settings -> Backup -> Full backup** and gets a single ZIP:

```
data.json       every household row, one array per table
manifest.json   what is inside, what is left out and why
receipts/...    the receipt files (image/PDF), one entry per object
```

- **It is a readable copy, not a restore.** There is no "import" button and
  there is no plan to add one. You read `data.json` with any text editor or
  spreadsheet.
- **It is not encrypted.** Anyone who opens the ZIP can read every amount,
  name, note and receipt. Keep it somewhere safe. The Backup card says this
  before you tap it.
- **Money is integer minor units.** Every amount is written as an integer
  number of minor units (e.g. `12345.67 EGP` -> `1234567`). Quantities such as
  odometer or litres are written as exact decimal **strings**, so no float ever
  touches the data (see AGENTS.md rule 2).
- **Tables are read one after another, not from one snapshot.** If someone
  edits the household while the backup is running, a row changed between two
  table reads may appear only once. It is not a transactionally consistent
  snapshot.
- **A receipt that cannot be downloaded is not fatal.** It is listed in
  `manifest.json` with `"included": false` and a `reason`
  (`download_failed`, `omitted_data_only`, `omitted_size_limit`) and the backup
  continues.

### What is included

`households`, `members`, `household_users`, `categories`, `vehicles`,
`pets`, `recurring_rules`, `transactions`, `transaction_receipts`,
`fuel_logs`, `maintenance_items`, `pet_reminders`, `budgets` - plus every
receipt file those transactions point at.

### What is left out, and why

| Table | Reason |
|---|---|
| `invites` | Invite **codes** are bearer credentials (access tokens). Exporting one would hand out access to the household. They are not household data. |

No secrets, tokens or keys live in the database tables; the service-role key is
never present in the app or the database (AGENTS.md rule 5).

### Size limits (the ZIP is built in memory on web)

The estimate is the sum of `transaction_receipts.size_bytes` - the size the
object had when it was attached. It costs one metadata read and downloads
nothing.

| Receipt payload | What happens |
|---|---|
| <= 100 MiB | Full backup proceeds quietly (`backupWarnReceiptBytes`) |
| > 100 MiB | A warning dialog asks first |
| > 300 MiB | **Refused** (`backupMaxReceiptBytes`); the full button is disabled and a **data-only** export stays available |

The data-only export writes `data.json` + `manifest.json` and marks every
receipt `omitted_data_only`. A failure is caught and shown as a message, never
left to crash the tab. The hard cap is re-checked inside the service as well,
so even a bypassed UI cannot try to build an oversized archive.

## 2. Platform backups (Supabase)

**This project is on the Supabase Free plan.** Do **not** assume any platform
backup exists. Open your project's dashboard and check **Database -> Backups**
to see what (if anything) your plan provides. This document deliberately makes
no claim about it.

## 3. A dump you run yourself (full database)

This is the restorable copy. **Run it yourself; never share the database
password with anyone (including an AI assistant) and never commit it.**

1. In the Supabase dashboard: **Project Settings -> Database -> Connection
   string -> URI**. You need the host, port, user and your database password.
2. Put the password only in your shell session:
   ```sh
   export SUPABASE_DB_URL='postgresql://postgres:YOUR-PASSWORD@db.<ref>.supabase.co:5432/postgres'
   ```
3. Install `pg_dump` matching the server major version (15/16).
4. Dump the whole database (schema + data):
   ```sh
   pg_dump "$SUPABASE_DB_URL" --no-owner --no-privileges \
     --file="supabase-full-$(date +%Y%m%d).sql"
   ```
5. Store the file somewhere safe, and **encrypt it** before it leaves your
   machine - the `.sql` file is plain text and contains every amount, name and
   note, plus `auth.users` rows.

### What a SQL dump does NOT include

- **Receipt / attachment files.** The bytes live in Supabase **Storage**, not
  in a database table. A dump captures the `transaction_receipts` rows (paths,
  sizes) but **not the files**. Keep those via the in-app backup ZIP, or copy
  the `receipts` bucket with the Supabase dashboard's storage browser / API.
- Anything outside the database: Edge Function secrets, project settings,
  auth provider configuration, etc.

Restoring: apply the migrations in `supabase/migrations/` first (they recreate
the schema, RLS and RPCs), then load the dump's data, e.g.
`psql "$TARGET_DB_URL" -f supabase-full-YYYYMMDD.sql`. The project does not
write SQL against the cloud DB from a dev machine (AGENTS.md rule 6) - the
restore is a manual, deliberate action.

## 4. The completeness check (why a new table cannot be forgotten)

The exporter and the Docker completeness check share **one source of truth**:

- `lib/features/backup/domain/backup_tables.dart` - the exported table list,
  the explicit exclusion list (with reasons) and each table's `::text` casts.
- `tool/gen_backup_tables_sql.dart` renders it into
  `supabase/tests/support/backup_tables.generated.sql`.
- `tool/docker/validate.sh` feeds that registry plus
  `supabase/tests/support/check_backup_tables.sql` to a real Docker schema and
  fails unless **every** `public` base table is either exported or explicitly
  excluded (with a reason), every registered table really exists, and every
  `numeric` column of an exported table is read as `::text` (never as a float).

`test/backup_tables_test.dart` fails if the committed generated SQL is stale,
and pins `backupSchemaVersion` to the number of migration files.

After changing `backup_tables.dart`:

```sh
dart run tool/gen_backup_tables_sql.dart
tool/docker/validate.sh fresh18          # rebuild + run the check
```

The real Docker schema currently has 14 `public` tables: the 13 above are
exported, `invites` is excluded, and `households` (the only table without a
`household_id` column) is exported by filtering on its `id`.
