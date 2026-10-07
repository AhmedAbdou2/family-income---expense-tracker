# AGENTS.md — working agreement for AI agents (and humans)

Bilingual (AR/EN) family income & expense tracker.
Flutter (Riverpod 3, go_router 18, Supabase) + Postgres with RLS.

## Hard rules

1. **Phase gates**: after each phase, make sure analyze/tests/build pass,
   summarize what changed, explain RLS impact in plain language, then
   **stop and wait for user approval** before starting the next phase.
2. **Money is integer minor units** in Dart (`int`), `numeric(12,2)` in
   Postgres. Convert only via `lib/core/utils/money.dart`. Never do
   floating-point arithmetic on money, never `double.parse` amounts.
3. **Localization**: all user-facing strings live in
   `lib/core/l10n/app_en.arb` + `app_ar.arb`. Add to **both** files, run
   `flutter gen-l10n`, and keep `flutter test` (parity test) green.
   Arabic must be real Arabic, not an English copy.
4. **RTL/LTR**: never hardcode left/right — use directional widgets/paddings.
5. **No service-role key anywhere** in app code, `.env`, or docs. Only the
   publishable/anon key. `.env` is gitignored; `.env.example` is committed.
6. **Never write SQL against the cloud DB from this machine.** Migrations
   are files only; the user pastes them into the Supabase SQL Editor
   (no Supabase CLI, no psql, no DB password requests).
7. **Table writes**: `households`, `household_users`, `invites` have no
   INSERT/DELETE policies — the app must use the RPCs
   `create_household`, `create_invite`, `accept_invite` only.
8. `"group"` is a reserved SQL word — always quote it: `c."group"`.
9. Keep `flutter analyze` at **0 issues**.

## Commands (run after every change)

```sh
flutter gen-l10n        # only if .arb files changed
flutter analyze         # must be clean
flutter test            # must pass (34 tests)
flutter build web --release   # compile check; ~3-4 min
```

Android APK builds currently fail on this machine: only a JRE is
installed, no JDK (`JAVA_COMPILER` missing). Install a JDK first if an
Android build is required.

## Architecture

```
lib/core      cross-cutting: env, supabase providers, errors (AppErrorCode +
              ExceptionMapper), l10n, router (pure appRedirect + routerProvider),
              settings (settingsProvider over SharedPreferences), theme, utils,
              reusable widgets (LoadingView/ErrorView/EmptyState/ErrorBanner)
lib/features  auth/  domain (AuthRepository, SignUpOutcome), data
                   (AuthRepositoryImpl), presentation (providers.dart exports
                   authRepositoryProvider, authStateProvider; screens)
              household/ domain (entities: Household, Membership, MemberRole,
                   Invite; HouseholdRepository), data (RPC + embed query),
                   presentation (membershipProvider, invitesProvider, splash,
                   setup, create, join, home shell (4 tabs + quick-add FAB),
                   dashboard (month summary + recent 5))
              members/  domain (Member, MembersRepository), data,
                   presentation (membersProvider, People tab: add / rename /
                   deactivate / delete; children read-only)
              categories/ domain (Category, CategoryGroup), data, presentation
                   (categoriesProvider, category_visuals icon/color maps,
                   grouped list + editor dialog)
              transactions/ domain (Transaction, TransactionType), data,
                   presentation (month/member-filtered list, create/edit form,
                   QuickAddAmountController + quick-add sheet, month providers)
              settings/  settings screen (language/theme/digits, invites with
                   optional person link, manage categories, sign out)
```

- Providers: Riverpod 3 `NotifierProvider`/`StreamProvider`/`FutureProvider`.
  Router listens via `ref.listen` in a `@Riverpod`-style provider
  (`routerProvider` + `_RouterRefresh`).
- Routing: go_router `redirect` = `appRedirect(location, auth, membership)`
  (pure, unit-tested). Paths: `/splash`, `/sign-in`, `/sign-up`,
  `/forgot-password`, `/setup`, `/setup/create`, `/setup/join`,
  `/` (dashboard), `/transactions`, `/transactions/new`,
  `/transactions/edit/:id`, `/members`, `/categories`, `/settings`.
  Detail routes are declared before the shell.
- Environment: `flutter_dotenv`, keys read in `lib/core/config/env.dart`.

## Database

Migrations in `supabase/migrations/` — run **in filename order** in the
Supabase SQL Editor (user does this manually):

1. extensions → 2. households (adds `created_by`) → 3. members
   (nullable `user_id`, unique per household per user) → 4. categories
   (31 seeded bilingual defaults) → 5. vehicles → 6. recurring_rules +
   budgets → 7. transactions → 8. invites → 9. RPCs → 10. RLS + grants
   → 11. invite member link (`invites.member_id`, 4-arg `create_invite`
   with `set search_path = public, extensions`, `accept_invite` auto-links
   `members.user_id`, REVOKE/GRANT hardening of every definer function).

Migration 11 is **frozen** (run green on the cloud DB together with the
isolation test). Any further DB change must be a NEW migration file.

Indexes: `household_id` on every table; `(household_id, date)` on
transactions.

RLS design (full plain-language comments in migration 10):

- Helpers are `SECURITY DEFINER` (`household_role`, `is_household_member`,
  `is_household_adult`, `owns_member_row`, `*_in_household`) so policies can
  read `household_users` without recursive RLS.
- Trigger freezes `household_users.user_id`/`household_id` (update = role
  change only).
- All 9 tables: RLS enabled; `anon` has zero access; RPCs granted to
  `authenticated` only; `seed_default_categories` executable by nobody
  outside definer functions.
- SELECT: members see their household's rows. Children additionally see
  only their own `members` row and that person's transactions; they can
  read categories (needed to record spending).
- INSERT/UPDATE/DELETE on `members`, `categories`, `vehicles`,
  `recurring_rules`, `budgets`: owner/adult only.
- `transactions` insert/update also require member/category/vehicle/recurring
  rows to belong to the same household.
- `households` update/delete: owner only; no insert policy.
- No INSERT/DELETE on `household_users`/`invites`: RPC-only.

Test: `supabase/tests/20261006900001_household_isolation.sql` (single
transaction, rolls back, prints `ALL RLS ISOLATION TESTS PASSED`).

### Known item

Joining via invite with a person link auto-links `members.user_id` at
accept time (member-bound invites, migration 11). Join-only invites
still create a login with no person of its own — that's intentional and
the settings dialog says so.

## Phase status

- **Phase 1 (done, awaiting approval)**: scaffold, deps, Cairo fonts,
  theme, ARB + generated l10n, 10 migrations + isolation test, auth
  screens, create/join household, home shell + dashboard placeholder,
  settings (language/theme/digits/invites/sign-out), README.md, tests
  (redirect, money, l10n parity, error mapping), web release build OK.
- **Phase 2 (done, awaiting approval)**: migration 11 + extended
  isolation test (run green on cloud), members CRUD, categories UI,
  transaction list + create/edit + delete, quick-add keypad (FAB on all
  tabs, last-used type/category/person), month dashboard summary,
  invite person picker (member-bound invites), child-role UI gating
  (no manage controls, invites/categories sections hidden), new error
  codes (member_linked / login_linked / invalid_member / category_in_use
  / member_in_use), routes + tests (34), web release build OK.
- Phase 3: vehicles, budgets, recurring rules.
- Phase 4: reports/charts/CSV export/polish.
