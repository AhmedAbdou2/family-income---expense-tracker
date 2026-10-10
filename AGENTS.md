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
flutter test            # must pass (60 tests)
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
                   Invite, HouseholdLogin; HouseholdRepository), data (RPC +
                   embed query), presentation (membershipProvider,
                   invitesProvider, householdLoginsProvider, splash, setup,
                   create (with own person name), join (2-step), claim,
                   home shell (4 tabs + quick-add FAB), dashboard (month
                   summary + recent 5), household members (owner-only))
              members/  domain (Member, MembersRepository), data,
                   presentation (membersProvider, linkedMemberProvider, People
                   tab: add / rename / deactivate / delete; children see only
                   their own row, rename own person, no manage controls)
              categories/ domain (Category, CategoryGroup), data, presentation
                   (categoriesProvider, category_visuals icon/color maps,
                   grouped list + editor dialog)
              transactions/ domain (Transaction, TransactionType), data,
                   presentation (month/member-filtered list, create/edit form,
                   QuickAddAmountController + quick-add sheet, month providers)
              vehicles/  domain (Vehicle, FuelType, FuelLog, MaintenanceItem,
                   FuelStats full-to-full, MaintenanceReminder), data,
                   presentation (vehiclesProvider, fuelLogsProvider(vehicleId),
                   maintenanceProvider(vehicleId): list/form/detail screens,
                   fuel-log form, maintenance form; L/100km + cost/km)
              recurring/ domain (RecurrenceFrequency, RecurringRule), data,
                   presentation (recurringRulesProvider + list/form screens;
                   due transactions posted by generate_recurring_transactions
                   when an adult opens the dashboard — idempotent)
              settings/  settings screen (language/theme/digits, invites with
                   optional person link, manage categories, vehicles + fixed
                   commitments entries, sign out)
```

- Providers: Riverpod 3 `NotifierProvider`/`StreamProvider`/`FutureProvider`.
  Router listens via `ref.listen` in a `@Riverpod`-style provider
  (`routerProvider` + `_RouterRefresh`).
- Routing: go_router `redirect` = `appRedirect(location, auth, membership,
  member)` (pure, unit-tested). Paths: `/splash`, `/sign-in`, `/sign-up`,
  `/forgot-password`, `/setup`, `/setup/create`, `/setup/join`, `/claim`,
  `/household-members`, `/` (dashboard), `/transactions`,
  `/transactions/new`, `/transactions/edit/:id`, `/members`, `/categories`,
  `/vehicles`, `/vehicles/new`, `/vehicles/edit/:id`, `/vehicles/:id`,
  `/vehicles/:id/fuel/new`, `/vehicles/:id/maintenance/new`,
  `/vehicles/:id/maintenance/edit/:itemId`, `/recurring`,
  `/recurring/new`, `/recurring/edit/:id`, `/settings`. Detail routes are
  declared before the shell (and `/vehicles/new` before `/vehicles/:id`). A
  household login with no linked person is held on `/claim` until it picks a
  name (`linkedMemberProvider`; errors assume "linked" so a failure never
  blocks the app).
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
   `members.user_id`, REVOKE/GRANT hardening of every definer function)
   → 12. self-service membership (3-arg `create_household` creates the
   owner's linked person, 2-arg `accept_invite` where join-only invites
   take a 1-40 `display_name` and person-bound ones raise
   `already_linked`, `claim_member`, `rename_member`, role/remove/leave
   RPCs with `last_owner` / `cannot_change_own_role` /
   `cannot_remove_self` / `child_requires_member`, name trigger, direct
   `members` name UPDATE revoked from `authenticated`, INSERT/DELETE on
   `members` limited to unlinked rows) → 13. fuel + maintenance + recurring
   (adds `vehicles.fuel_type`/`is_active`, new `fuel_logs` (SELECT-only;
   writes via `add_fuel_log`/`delete_fuel_log`), new `maintenance_items`
   (adult CRUD + `complete_maintenance`), `recurring_rules.name/start_date/
   end_date`, `transactions.recurrence_date` + partial unique index
   `(recurring_rule_id, recurrence_date)`, and the idempotent
   `generate_recurring_transactions`; vehicles/recurring/fuel/maintenance
   SELECT narrowed to **adults only** — children get zero access; new
   definer fns REVOKE/GRANT hardened).

Migration 11 is **frozen** (run green on the cloud DB together with the
isolation test). Migration 12 is **frozen** too. Migration 13 is validated
in Docker (all 13 files + extended isolation test green, privilege matrix
clean) — the user runs it on the cloud next; after that it is frozen. Any
further DB change must be a NEW migration file.

Indexes: `household_id` on every table; `(household_id, date)` on
transactions.

RLS design (full plain-language comments in migration 10):

- Helpers are `SECURITY DEFINER` (`household_role`, `is_household_member`,
  `is_household_adult`, `owns_member_row`, `*_in_household`) so policies can
  read `household_users` without recursive RLS.
- Trigger freezes `household_users.user_id`/`household_id` (update = role
  change only).
- All 11 tables: RLS enabled; `anon` has zero access; RPCs granted to
  `authenticated` only; `seed_default_categories` executable by nobody
  outside definer functions.
- SELECT: members see their household's rows. Children additionally see
  only their own `members` row and that person's transactions; they can
  read categories (needed to record spending). Vehicles, fuel logs,
  maintenance reminders and recurring rules are **adult-only — a child
  gets zero SELECT access** to them.
- INSERT/UPDATE/DELETE on `members`, `categories`, `vehicles`,
  `maintenance_items`, `recurring_rules`, `budgets`: owner/adult only.
  `fuel_logs` has a SELECT policy only — writes go through
  `add_fuel_log`/`delete_fuel_log` (RPC-only).
- `transactions` insert/update also require member/category/vehicle/recurring
  rows to belong to the same household.
- `households` update/delete: owner only; no insert policy.
- No INSERT/DELETE on `household_users`/`invites`: RPC-only.

Test: `supabase/tests/20261006900001_household_isolation.sql` (single
transaction, rolls back, prints `ALL RLS ISOLATION TESTS PASSED`).

### Known item

Joining via invite with a person link auto-links `members.user_id` at
accept time (member-bound invites, migration 11); join-only invites now
let the joiner choose their own name (migration 12). A login that leaves
and later rejoins as a "New person" gets a **duplicate** person — the
owner can delete the leftover unlinked person from the People tab.

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
  / member_in_use), routes + tests (35), web release build OK.
- **Phase 2 fix**: duplicate FAB hero tags froze route transitions —
  the shell now owns the single quick-add FAB (`ValueKey('quick-add-fab')`),
  add-person moved to the People app bar, add-category got its own tag;
  regression test `test/home_shell_fab_hero_test.dart`.
- **Phase 2.5 (done, awaiting approval)**: migration 12 + extended
  isolation test (sections 0-7 incl. claim/rename/role/leave/remove and
  the members lockdown; Docker-green, user runs it on cloud next),
  joiner picks their own name (2-step join), create-household takes the
  owner's own person name, `/claim` screen for legacy logins
  (`linkedMemberProvider`), owner-only `/household-members` (role change,
  account removal, person rename), Settings leave row (disabled for the
  last owner) + Household-members tile + invite dialog "New person"
  default, child quick-add forced onto their own person, People-tab
  gating (rename own person, no delete of linked persons, names capped
  at 40), new error codes (last_owner / cannot_change_own_role /
  cannot_remove_self / child_requires_member / already_linked), tests
  (41), web release build OK.
- Phase 3 (done, awaiting approval): migration 13 + extended isolation
  test (section 8: vehicles, add/delete fuel, invalid fuel, maintenance +
  re-arm + expense, recurring catch-up/idempotency/child-0, child &
  outsider lockout; Docker-green, all 13 files + privilege matrix clean,
  user runs it on cloud next), vehicles CRUD + archive, fuel log with
  odometer-never-backwards + one linked expense per fill-up, L/100km
  (full-to-full) + cost/km, maintenance reminders (due date and/or
  odometer, in-app due-soon/overdue, completing may post an expense),
  recurring fixed commitments (weekly/monthly/yearly, start + optional
  end) posted idempotently by `generate_recurring_transactions` when an
  adult opens the dashboard, adult-only Settings entries, new error codes
  (invalid_vehicle / invalid_item / invalid_log / invalid_value /
  odometer_backwards / no_car_category / no_linked_person), tests (60),
  web release build OK.
- Phase 3 fix (button-in-Row crash): the global button theme uses
  `minimumSize: Size.fromHeight(...)` (width = infinity) so form buttons
  stretch full width; inside an unbounded `Row` that threw
  "BoxConstraints forces an infinite width" and broke the vehicle detail
  screen (so "Add fill-up" did nothing). Section-header action buttons now
  use `AppButtons.inline` (`lib/core/widgets/app_buttons.dart`,
  `minimumSize: Size(0, 44)`). Regression tests:
  `test/vehicle_detail_layout_test.dart` (narrow/wide + tap-to-open).
- Phase 3 UX: Vehicles is a top-level nav destination for owner/adult only
  (last shell branch so a child's destination indexes stay 1:1); children
  are redirected away from `/vehicles` and `/recurring`; the Vehicles tab
  uses an AppBar add action instead of its own FAB. Tests:
  `test/home_shell_vehicles_nav_test.dart`.
- Phase 4: reports/charts/CSV export/polish.
