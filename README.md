# Family Income & Expense Tracker

A bilingual (العربية / English) household finance app: income, expenses,
categories, vehicles, budgets, recurring rules and invites — built with
Flutter + Supabase and Row Level Security so every family only ever sees
its own data.

- **UI**: Arabic (RTL) and English (LTR), system/light/dark themes,
  Arabic-Indic digits option, adaptive navigation (bottom nav / rail).
- **State & routing**: Riverpod 3 + go_router (auth-aware redirect).
- **Backend**: Supabase (Postgres + Auth). All writes to core tables go
  through SECURITY DEFINER RPCs; every table has RLS enabled.
- **Money**: integer minor units in Dart, `numeric(12,2)` in Postgres.
  Never floating-point math.

## Prerequisites

- Flutter 3.47.x / Dart 3.13.x
- A Supabase project (free tier is fine)
- For Android builds: a full JDK (17+). The current machine has only a
  JRE, so `flutter build apk` fails with
  `Toolchain installation ... does not provide JAVA_COMPILER` until a JDK
  is installed (`sudo apt install openjdk-21-jdk-headless`).

## Setup

1. **Dependencies**

   ```sh
   flutter pub get
   flutter gen-l10n
   ```

2. **Environment**

   ```sh
   cp .env.example .env
   ```

   `.env` already ships filled in this repo's working copy with the
   Supabase URL and publishable (anon) key. `.env` is gitignored;
   `.env.example` is committed. **Never** put a service-role key here.

3. **Database — run the migrations yourself (manual step)**

   Open your Supabase project → **SQL Editor** → paste and run each file
   **in this exact order**:

   ```
   supabase/migrations/20261006000001_extensions.sql
   supabase/migrations/20261006000002_households.sql
   supabase/migrations/20261006000003_members.sql
   supabase/migrations/20261006000004_categories.sql
   supabase/migrations/20261006000005_vehicles.sql
   supabase/migrations/20261006000006_recurring_budgets.sql
   supabase/migrations/20261006000007_transactions.sql
   supabase/migrations/20261006000008_invites.sql
   supabase/migrations/20261006000009_rpcs.sql
   supabase/migrations/20261006000010_rls_grants.sql
   supabase/migrations/20261007000011_invite_member_link.sql
   ```

   Then run the isolation proof in the SQL Editor as well:

   ```
   supabase/tests/20261006900001_household_isolation.sql
   ```

   It creates two throwaway households, proves household B can select /
   insert / update / delete nothing of household A, prints
   `ALL RLS ISOLATION TESTS PASSED`, and **rolls everything back**.

   The header comment of `20261006000010_rls_grants.sql` explains every
   RLS policy in plain language. See `AGENTS.md` for the same summary.

4. **Run**

   ```sh
   flutter run -d chrome      # web
   flutter run -d linux       # desktop (toolchain present)
   ```

## Commands

| Command | Purpose |
| --- | --- |
| `flutter gen-l10n` | Regenerate `lib/core/l10n/generated/` from the `.arb` files |
| `flutter analyze` | Lint/typecheck (must stay at 0 issues) |
| `flutter test` | Unit tests: redirect, money, l10n parity, error mapping, quick-add keypad, shell FAB heroes |
| `flutter build web --release` | Release build (verified working) |
| `flutter build apk --debug` | Android build (requires a JDK, see above) |

After editing `app_en.arb` / `app_ar.arb`, run `flutter gen-l10n` and
`flutter test` — the parity test fails if a key exists in only one
language.

## Project layout

```
lib/
  core/
    config/     env + Supabase client providers
    errors/     AppException, AppErrorCode, ExceptionMapper
    l10n/       ARB-driven localization (+ generated/)
    router/     pure redirect logic + go_router provider
    settings/   theme/locale/digits preferences (shared_preferences)
    theme/      Material 3 light/dark themes, Cairo font
    utils/      money (integer minor units), validators, form messages
    widgets/    loading / error / empty-state helpers
  features/
    auth/       sign in, sign up, forgot password
    household/  splash, setup, create/join household, home shell,
                dashboard (month summary + recent)
    members/    people tab (add / rename / deactivate / delete)
    categories/ category list + editor (bilingual names, icon, color)
    transactions/ list + create/edit form, quick-add keypad
    settings/   language / theme / digits, invites, sign out
supabase/
  migrations/   11 ordered SQL migrations (run manually in SQL Editor)
  tests/        RLS isolation test (rolls back)
```

## Security model (short version)

- Every table has RLS **enabled**; `anon` has zero table/function access.
- Household membership is resolved only through `SECURITY DEFINER`
  helpers that read `household_users` with `auth.uid()` — this avoids
  recursive RLS evaluation.
- `households`, `household_users` and `invites` have **no INSERT policy
  at all**: rows are created only by `create_household()`,
  `create_invite()` and `accept_invite()`.
- A trigger freezes `household_users.user_id` / `household_id` — an
  owner can only change `role`.
- Owners/adults see and manage everything in their household; a child
  login sees only the `members` row linked to it and that person's
  transactions.
- Referential integrity is enforced in the `transactions` policies: the
  referenced member/category/vehicle/recurring rule must live in the
  **same** household.

## Phase plan

| Phase | Scope | Status |
| --- | --- | --- |
| 1 | Foundation: scaffold, theme, l10n, migrations + RLS, auth, create/join household, settings | ✅ built, analyzed, tested, web release build OK — **awaiting approval** |
| 2 | Member management, transaction CRUD, categories UI, quick-add, month dashboard | ✅ built, analyzed, tested, web release build OK — **awaiting approval** |
| 3 | Vehicles, budgets, recurring rules | pending |
| 3 | Vehicles, budgets, recurring rules | pending |
| 4 | Reports, charts, CSV export, polish | pending |
