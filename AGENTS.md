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
flutter test            # must pass (359 tests)
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
                   home shell (adaptive bottom bar + drawer/rail; quick-add
                   FAB; ShellScope/ShellMenuButton), dashboard (month
                   summary + fixed posted/due/remaining + recent 5),
                   family members (unified People + logins, role badge,
                   permission-gated actions) + role_badge.dart)
              members/  domain (Member, MembersRepository), data,
                   presentation (membersProvider, linkedMemberProvider,
                   profile screen; the Family tab itself lives in
                   household/ as family_members_screen.dart; children see
                   only their own row, rename own person, no manage controls)
              categories/ domain (Category, CategoryGroup), data, presentation
                   (categoriesProvider, category_visuals icon/color maps,
                   grouped list + editor dialog)
              transactions/ domain (Transaction, TransactionType, shared
                   transactionColumns/transactionFromRow mapper), data,
                   presentation (month/member/pet-filtered list, create/edit
                   form with pet picker + "Make monthly fixed",
                   QuickAddAmountController + quick-add sheet, month providers;
                   every delete — list, dashboard, person, pet, form — goes
                   through the shared transaction_delete.dart dialog and the
                   delete_transaction RPC)
              receipts/  domain (Receipt + pure receipt_validation.dart:
                   mime/size/count rules, maxReceiptsPerTransaction = 3,
                   allowedMimes), data (mint → client upload → attach, signed
                   URL per object, RPC-only writes), presentation
                   (transactionReceiptsProvider(transactionId),
                   receiptSignedUrlProvider(path), inline receipt_section.dart
                   in the transaction form - picker opens by itself after a
                   NEW transaction is saved via `?receipt=add`, viewer,
                   3-step upload; children read-only)
              export/    domain (ExportFilter, pure csv_export.dart: RFC-4180
                   quoting + injection guard for `= + - @ \t \r`, UTF-8 BOM,
                   plain decimals; month_summary.dart MonthSummary),
                   data (export_repository_impl.dart: `.range()` paging with
                   `collectTransactionPages`, because PostgREST caps ~1000
                   rows), presentation (export_screen.dart at `/export`,
                   pdf_summary.dart buildMonthSummaryPdf with the Cairo subset
                   embedded (wired in; see docs/phase4b/README.md))
              vehicles/  domain (Vehicle, FuelType, FuelLog, MaintenanceItem,
                   FuelStats full-to-full, MaintenanceReminder), data,
                   presentation (vehiclesProvider, fuelLogsProvider(vehicleId),
                   maintenanceProvider(vehicleId): list/form/detail screens,
                   fuel-log form, maintenance form; L/100km + cost/km)
              pets/     domain (Pet, PetType, PetReminder, PetReminderKind,
                   pure pet_reminder_status.dart: dueSoonDays = 14 + status +
                   nextDueDate with day clamping + sorted, PetsRepository,
                   PetRemindersRepository), data, presentation (petsProvider,
                   petRemindersProvider(petId), pet_visuals, list/form/detail
                   screens: monthly total + expense list + reminders section
                   (status chip, complete with optional cost → pet expense,
                   repeat re-arms server-side); adult-only)
              recurring/ domain (RecurrenceFrequency, RecurringRule +
                   fixedMonthSummary + recurring_schedule pure helpers:
                   firstOccurrence/resolveNextDue/occurrencesInMonth), data,
                   presentation (recurringRulesProvider + list/form screens
                   with optional vehicle/pet links; due transactions posted by
                   generate_recurring_transactions when an adult opens the
                   dashboard — idempotent)
              settings/  settings screen (language/theme/digits, invites with
                   optional person link, manage categories, vehicles + pets +
                   fixed commitments entries, a Data section - export tile to
                   `/export` + the orphan-receipt cleanup action, sign out)
              budgets/  domain (Budget, BudgetsRepository, pure
                   budget_progress.dart: budgetOverview() + BudgetProgress +
                   BudgetStatus from SPENT, 80% near / 100% over, projected =
                   spent + still-due fixed, paused limits excluded from
                   alerts), data (RPC-only writes + `amount::text` reads),
                   presentation (budgetsProvider, budgetOverviewProvider over
                   the SHARED dashboard month, budgets screen with overall +
                   per-category cards, amount editor sheet, status chip);
                   adult-only)
              reports/  domain (MonthlyTotal, ReportsRepository, pure
                   report_data.dart: expensesByCategory/expensesByPerson +
                   fillMonthTrend 6 zero-filled months ending at the selected
                   month + sharePercent), data (`monthly_totals` RPC), charts
                   (fl_chart donut + grouped 6-month bars, custom RTL-safe
                   person bars), presentation (monthlyTotalsProvider,
                   reportDataProvider over the SAME month rows the dashboard
                   sums); adult-only)
```

- Budgets and Reports reconcile by construction: both read
  `dashboardMonthTransactionsProvider` (+ categories/members/recurring), so
  the figures match the dashboard's month summary exactly. Only the 6-month
  trend goes through SQL (`monthly_totals`), because PostgREST would silently
  truncate a >1000-row response.

- Providers: Riverpod 3 `NotifierProvider`/`StreamProvider`/`FutureProvider`.
  Router listens via `ref.listen` in a `@Riverpod`-style provider
  (`routerProvider` + `_RouterRefresh`).
- Routing: go_router `redirect` = `appRedirect(location, auth, membership,
  member)` (pure, unit-tested). Paths: `/splash`, `/sign-in`, `/sign-up`,
  `/forgot-password`, `/setup`, `/setup/create`, `/setup/join`, `/claim`,
  `/household-members` (redirects to `/members`), `/` (dashboard),
  `/transactions`,
  `/transactions/new`, `/transactions/edit/:id`, `/members` (Family),
  `/categories`,
  `/vehicles`, `/vehicles/new`, `/vehicles/edit/:id`, `/vehicles/:id`,
  `/vehicles/:id/fuel/new`, `/vehicles/:id/maintenance/new`,
  `/vehicles/:id/maintenance/edit/:itemId`, `/recurring` (shell branch),
  `/recurring/new`, `/recurring/edit/:id`, `/pets` (shell branch),
  `/pets/new`, `/pets/edit/:id`, `/pets/:id`, `/pets/:id/reminders/new`,
  `/pets/:id/reminders/edit/:reminderId`, `/budgets` (shell branch),
  `/reports` (shell branch), `/export` (pushed from the Settings Data card and
  the Reports app bar), `/profile/:id` (`me` resolves
  to the caller's own person), `/settings`. Adult-only: `/vehicles`,
  `/recurring`, `/pets`, `/budgets`, `/reports`, `/export` (the reminder
  routes are covered by the `/pets/` prefix; the receipts section is inline in
  the transaction form, not a route). Detail routes are
  declared before the shell (and `/vehicles/new` before `/vehicles/:id`,
  `/pets/new` before `/pets/:id`). A
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
   definer fns REVOKE/GRANT hardened) → 14. pets + fixed links (new `pets`
   table, `pet` category group + 6 seeded pet categories, `pets_validate_name`
   trigger, `transactions.pet_id`, `recurring_rules.vehicle_id`/`pet_id`,
   `pet_in_household` helper, updated `seed_default_categories` (37
   defaults) and `generate_recurring_transactions`, RLS: pets are
   adult-only, child may still reference a same-household `pet_id`) →
   15. archived fixed expenses (`recurring_rules.archived_at`, generator
   skips archived rules, atomic `archive_recurring_rule(rule,
   delete_month_transactions)` RPC, direct DELETE on `recurring_rules`
   revoked — so deleting a posted fixed expense never orphans its
   transactions) → 16. budgets + reports (guards that no legacy
   `budgets.category_id is null` row survives, drops the unused
   `member_id`/period columns, adds `budgets.is_active` + two partial
   unique indexes (one limit per category, one overall), moves every write
   behind `set_category_budget` / `set_overall_budget` / `set_budget_active`
   / `delete_budget`, narrows `budgets` SELECT to **adults only**, and adds
   the SECURITY DEFINER `monthly_totals(household, start, end)` aggregate
   that the Reports trend uses instead of fetching >1000 transactions) →
   17. receipts + pet reminders + exports (new `transaction_receipts` and
   `pet_reminders` tables, both SELECT-only for **adults**; every write goes
   through `request_receipt_upload`, `attach_receipt`, `delete_receipt`,
   `list_orphan_receipts`, `complete_pet_reminder`, `delete_pet_reminder` —
   `attach_receipt` re-checks the object really exists in `storage.objects`
   (bucket `receipts`, exact path) and takes mime/size from the stored object,
   `complete_pet_reminder` posts the optional expense into the matching pet
   category and re-arms a repeating reminder server-side;
   `delete_transaction`, `delete_fuel_log` and `archive_recurring_rule` were
   recreated so they also return the receipt paths they orphaned; the private
   `receipts` bucket (5 MiB, `image/jpeg,image/png,image/webp,application/pdf`)
   plus three `storage.objects` policies — SELECT **household-scoped for
   adults**, INSERT transaction-scoped, DELETE household-scoped for adults,
   which is what keeps an orphaned object deletable after its transaction row
   is gone; the whole storage block is wrapped in
   `if exists (pg_namespace 'storage')` so the migration also runs on a bare
   DB).

Migration 11 is **frozen** (run green on the cloud DB together with the
isolation test). Migration 12 is **frozen** too. Migration 13 is validated
in Docker (all 13 files + extended isolation test green, privilege matrix
clean) — the user runs it on the cloud next; after that it is frozen.
Migration 14 is validated in Docker (all 14 files + the extended isolation
test green, privilege matrix clean) — the user runs it on the cloud next;
after that it is frozen. Migration 15 is validated in Docker (all 15 files
+ extended isolation test section 10 + privilege matrix clean) — the user
runs it on the cloud next; after that it is frozen. Migration 16 is
validated in Docker (all 16 files + extended isolation test section 11 +
privilege matrix clean, plus both legacy-guard cases `category_id is null`
aborts / category row kept) — the user runs it on the cloud next; after
that it is frozen. Migration 17 is validated in Docker two ways, both using
the honest stub in `supabase/tests/support/` (see `tool/docker/README.md`):
`fresh17final` (fresh DB + the Supabase stub *with* the storage schema — all
17 migration files, the full extended isolation test incl. sections 12/13 +
the amendment-G block, and the privilege matrix with 0 violations) and
`bare17final` (the stub *without* the storage schema — all 17 migration files
still apply, because migration 17 wraps its whole storage block in
`if exists (pg_namespace 'storage')`; the isolation test itself is not run
there, since its receipts section asserts against `storage.buckets`, which only
exists on Supabase). The user runs 17 on the cloud next; after that it is
frozen. Any further DB change must be a NEW migration file.

Two hosted-only Storage behaviours were found by running the isolation test on
the real project (Docker's stub predated them); both are now mirrored in the
stub, so the test fails locally instead of only on the cloud:

- `storage.buckets` has RLS enabled with **no** read policy for
  `authenticated`/`anon`, so §12.0's bucket-configuration check reads that row
  as the privileged login role (`set local role none`) instead of as
  `authenticated` (fixed in `ef637d4`). Enabling RLS on the stub's
  `storage.buckets` (no policy) makes this class of bug fail in Docker too.
- `storage.objects` carries `protect_objects_delete`, a `BEFORE DELETE ... FOR
  EACH STATEMENT` trigger that raises `42501` unless
  `storage.allow_delete_query = 'true'` — the GUC the Storage API sets when it
  deletes on a user's behalf. It fires even when zero rows match. The test's own
  direct deletes (§12.7-§12.13) set that GUC, §12.0a pins the refusal without
  it, and the GUC is switched back off afterwards so it cannot leak. Neither the
  app nor migration 17 ever deletes storage rows directly.

**Migration 17 deliberately does NOT revoke direct DELETE on `transactions`.**
Doing so would make isolation-test sections 3d/4d (which assert that a child
and an outsider delete 0 rows) raise `permission denied` instead of deleting
nothing, and those `0 rows affected` results are the real assertion. So the
`transactions_delete` RLS policy stays as a same-rule fallback, the app always
goes through the `delete_transaction` RPC (which is what returns the receipt
paths), and a direct delete can at worst orphan a storage object — healed by
the Settings "clean up unused receipt files" sweep.

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
  outside definer functions. (Migration 17 adds `transaction_receipts` +
  `pet_reminders`, and three policies on `storage.objects`, with the same
  `anon` = zero rule.)
- SELECT: members see their household's rows. Children additionally see
  only their own `members` row and that person's transactions; they can
  read categories (needed to record spending). Vehicles, fuel logs,
  maintenance reminders, recurring rules, pets, budgets (migration 16) and
  **receipts + pet reminders** (migration 17) are **adult-only —
  a child gets zero SELECT access** to them.
- INSERT/UPDATE/DELETE on `members`, `categories`, `vehicles`,
  `maintenance_items`, `recurring_rules`: owner/adult only.
  `fuel_logs` has a SELECT policy only — writes go through
  `add_fuel_log`/`delete_fuel_log` (RPC-only). `budgets` (migration 16) is
  SELECT-only for adults; every write goes through
  `set_category_budget` / `set_overall_budget` / `set_budget_active` /
  `delete_budget`, and the `monthly_totals` aggregate is a definer RPC.
  `transaction_receipts` and `pet_reminders` (migration 17) are the same
  shape: SELECT-only, every write behind an RPC.
- `transactions` insert/update also require member/category/vehicle/recurring
  rows to belong to the same household.
- Storage (`storage.objects`, migration 17, bucket `receipts`): the upload
  path is minted server-side (`request_receipt_upload`) and re-validated by
  `attach_receipt`, which also checks the object exists. SELECT and DELETE are
  **household-scoped and adult-only** (`storage.foldername(name)` puts the
  household id first: `household_id/transaction_id/<uuid>.<ext>`), INSERT is
  transaction-scoped. The DELETE policy is scoped by household rather than by
  transaction *on purpose*: Postgres only deletes rows the SELECT policy makes
  visible, so a transaction-scoped SELECT would strand an orphaned object
  forever. The storage DDL is inside
  `if exists (pg_namespace 'storage')` so the migration also applies to a
  plain Postgres (which is how it is Docker-tested).
- `households` update/delete: owner only; no insert policy.
- No INSERT/DELETE on `household_users`/`invites`: RPC-only.

Test: `supabase/tests/20261006900001_household_isolation.sql` (single
transaction, rolls back, prints `ALL RLS ISOLATION TESTS PASSED`).
Docker harness (honest stubs, privilege matrix, validate script + README):
`supabase/tests/support/` and `tool/docker/` — see `tool/docker/README.md`.

### Known item

Joining via invite with a person link auto-links `members.user_id` at
accept time (member-bound invites, migration 11); join-only invites now
let the joiner choose their own name (migration 12). A login that leaves
and later rejoins as a "New person" gets a **duplicate** person — the
owner can delete the leftover unlinked person from the Family tab.

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
- Phase 3.5 (done, awaiting approval): migration 14 + extended isolation
  test (section 9: pet name trigger, 37 categories incl. 6 pet ones, pet
  expense stores `pet_id`, child zero pet access, foreign-household pet id
  rejected, recurring rule links carried onto generated transactions;
  Docker-green, all 14 files + privilege matrix clean, user runs it on
  cloud next), Pets feature (list/form/detail with this-month total +
  expenses), profile screen (month income/expenses/balance + recent),
  People-tab tap-to-profile, owner-or-own-person rename gating, adaptive
  navigation reworked (bottom bar = dashboard/transactions/people/fixed;
  drawer + rail carry every allowed destination incl. settings, vehicles,
  pets, with an account header; `ShellScope` + `ShellMenuButton` open the
  drawer from any branch AppBar), dashboard fixed posted/still-due/left
  after fixed (`fixedMonthSummary` pure helper), "Make monthly fixed" from
  the transaction form, recurring-rules vehicle/pet links, new `pet`
  category group, `invalidPet` error code, tests (64), web release build
  OK.
- Phase 3.5 fix (wide-window crash): the account tile in the rail's
  `leading` held a `Row` with an `Expanded`, but a `Row` nested in a `Row`
  is laid out with unbounded width, so opening at >=840px threw
  "RenderFlex children have non-zero flex but incoming width constraints
  are unbounded" and the shell failed. The tile now uses
  `mainAxisSize: MainAxisSize.min` + a `ConstrainedBox(maxWidth: 200)` on
  the name (collapsed rail = avatar only, tooltip carries the name;
  extended = avatar + ellipsized name). Regression sweep
  `test/home_shell_layout_test.dart` pumps the shell at 360/800/900/1854px
  for owner/adult/child (collapsed + extended rail, drawer) and fails on
  any layout exception. Tests now 79.
- UX: Family members merge (People + Household members into one screen).
  One row per person with a reusable `RoleBadge` (role_badge.dart: text +
  icon + tonal color; owner/adult/child when linked, "No login" otherwise);
  row actions gated by role (owner: rename anyone, change role, remove
  login, connect login, delete unlinked person; adult: add person, invite
  adult/child, rename own person, connect/delete unlinked; child: sees only
  own row, rename self, leave). No DB change - reuses `rename_member`,
  `update_household_role`, `remove_household_login`, `create_invite`,
  `leave_household`. Invite picker never offers the owner role. The old
  `/household-members` route redirects to `/members`; `members_screen.dart`
  and `household_members_screen.dart` deleted; the nav entry is "Family".
  Badge also shown on the profile header and the account header (drawer +
  extended rail; collapsed-rail tooltip carries the role). Tests 102
  (`test/role_badge_test.dart`, `test/family_members_test.dart`,
  `test/family_members_layout_test.dart` sweep 360/800/1854 for all roles).
- UI: the Family screen's two look-alike app-bar buttons ("Add person" and
  "Invite someone") became ONE "Add family member" action opening a single
  dialog: name (required, trimmed, ≤40) → login choice ("No login" creates the
  person only, exactly like the old add; "Create invite code" creates the
  person and then a person-bound invite) → role (adult/child, shown only on
  the login path because a person without a login has no role; an invite can
  never carry the owner role). The role radios reuse `roleLabel`; the per-row
  action (was "Connect a login") is now "Create invite" and still binds an
  invite to an existing unlinked person. No DB change: reuses the
  `members_insert_adult` policy + `create_invite(p_member_id)` +
  `accept_invite`, so a child login still always has a person. ARB keys
  `family_add_member` / `family_add_login_label` / `family_add_no_login_hint` /
  `family_add_with_login_hint` / `family_add_action` / `family_create_invite`
  added (EN+AR); `member_add`, `family_invite_someone` and
  `member_connect_login` removed. Tests 385 (`test/family_add_member_test.dart`
  pins the exact repo calls, `test/family_members_layout_test.dart` sweeps
  360/800/1854 × AR/EN × owner/adult/child for the list and the dialog).
- Fix (fixed commitments didn't affect the dashboard): the form/DB wrote
  `next_due = start_date`, ignoring `day_of_month`, so the generator posted
  the first occurrence on the wrong day and the dashboard projection skipped
  an earlier day-of-month. New pure `recurring_schedule.dart`
  (`firstOccurrence` — a monthly rule's start date picks the *starting
  month* and `dayOfMonth` picks the day, clamped to the CURRENT month only
  so there is no multi-month backfill; `resolveNextDue` keeps a future
  cursor on edit; `occurrencesInMonth` compares by month). Repository
  create/update now write the corrected `next_due`; the form no longer
  resets the cursor to the start date on edit. The dashboard takes "Posted"
  from the real generated transactions (`Transaction.recurringRuleId`, now
  selected) and "Still due" from the rules, so a posted fixed expense counts
  once; it also surfaces generator errors (SnackBar) and invalidates
  `recurringRulesProvider`. One-line help added under the expenses / fixed /
  after-fixed cards. No DB change. Tests 119
  (`test/recurring_schedule_test.dart`, `test/dashboard_fixed_test.dart`,
  extended `test/fixed_summary_test.dart`); generator re-validated in Docker
  (3 posted incl. catch-up, no backfill, second call 0).
- Fix (delete + pause of fixed expenses): "Fixed" renamed to "Fixed
  expenses" (AR المصروفات الثابتة) with a short bottom-bar label
  (`nav_fixed_short`) that fits 360px. Any transaction row (transactions
  list, dashboard recent, person profile, pet detail, edit form) can now be
  deleted via swipe or action, using one shared rich dialog
  (`transaction_delete.dart`) that shows category/person/amount/date, notes
  the fuel-log cascade, warns a maintenance reminder is not un-completed,
  and — for fixed-expense postings — offers an optional "Also pause this
  fixed expense" checkbox (default off). Deleting a recurring-generated
  transaction never regenerates (proven in Docker: 1,1,0,0,0,0 with a rule
  edit in between). Fuel-linked deletes go through `delete_fuel_log`;
  provider invalidation refreshes every derived figure. Pausing a rule now
  writes `is_active=false` via `setRuleActive` and drops it from "Still due"
  immediately; resuming advances `next_due` with the new pure
  `nextOccurrenceOnOrAfter` so the paused period is not backfilled (Docker:
  0,1,1,0,1). No DB change. Tests 133
  (`test/recurring_schedule_test.dart`, `test/fixed_summary_test.dart`,
  `test/dashboard_fixed_test.dart`, new
  `test/transaction_delete_dialog_test.dart`); deprecated `RadioListTile`
  migrated to `RadioGroup`.
- Fix (delete fixed expense corrupted the dashboard): the "Keep posted
  transactions" path hard-deleted the rule, and
  `transactions.recurring_rule_id` is `on delete set null`, so spent rows
  lost their link and "Posted" dropped / "Left after fixed" rose (Docker
  repro: Posted 2,000→0, Left 7,500→9,500, FK `confdeltype='n'`). Now rules
  are archived: migration 15
  (`20261012000015_archive_fixed_expenses.sql`) adds
  `recurring_rules.archived_at`, rebuilds
  `generate_recurring_transactions()` to skip archived rules, adds the
  atomic `archive_recurring_rule(rule, delete_month_transactions)` RPC
  (optionally purges this month's posted rows, then archives; nothing
  deleted on failure), and revokes direct DELETE on `recurring_rules` from
  `authenticated`/`anon`. Archived rules are inactive, hidden from the list,
  never generated, and keep every link. App: `deleteRule` → `archiveRule`,
  `listRules` hides archived, `fixedMonthSummary` skips archived, shared
  delete dialog (`recurring_delete.dart`) states each option with the
  month's count, pure `dashboardSummary()` extracted, new
  `invalidRule`/`alreadyArchived` error codes. Docker-green (all 15 files on
  a fresh DB + extended isolation test section 10 + privilege matrix);
  analyze clean, 140 tests (`test/recurring_archive_test.dart` pins the exact
  figures: Keep ⇒ Posted 2,000 / due 0 / expenses unchanged; delete-month ⇒
  Posted 0 / expenses −2,000), web release build OK.
- Copy & translation pass (text only, no DB/behaviour change): full EN/AR
  audit against one glossary (Income=الإيرادات, Expenses=المصروفات,
  Balance=الرصيد, Fixed expenses=المصروفات الثابتة, Posted=المسجَّل,
  Still due=مستحق لاحقًا, Left after fixed=المتبقي بعد المصروفات الثابتة,
  Family=العائلة, Owner/Adult/Child=مالك/بالغ/طفل, Vehicles=السيارات,
  Pets=الحيوانات الأليفة, Odometer=عدّاد الكيلومترات, Pause/Resume=
  إيقاف مؤقت/استئناف, Make monthly fixed=تثبيت كمصروف شهري, Category=التصنيف,
  Person=الشخص). 120 strings changed + `invite_status_expired` added
  (expired invites used to read "Active"); Arabic rewritten to natural MSA
  with full ICU plural categories (e.g. `recurring_generated`,
  `recurring_delete_option_delete_month`), Western digits 0-9 in text (the
  Arabic-Indic toggle still converts displayed numbers), and "ترحيل/المنزل"
  replaced by "تسجيل/الأسرة". New `lib/core/utils/currency.dart` shows an
  Arabic currency symbol (EGP→ج.م) in Arabic and the ISO code in English at
  every amount site. Deliverable `docs/copy-review.md` (key | English | old
  Arabic | new Arabic, changed rows, grouped by screen). Tests 150
  (`test/currency_test.dart`, `test/arabic_dialogs_layout_test.dart`,
  extended parity checks for placeholders + plural categories); analyze
  clean, web release build OK.
- Copy-pass follow-up (text only, decisions from review): the expense/income
  segmented toggle now reads singular مصروف/إيراد while the dashboard cards
  keep the plural الإيرادات (new `dashboard_income`) / المصروفات; the
  fixed-expenses card labels are المسجَّل (posted), مستحق لاحقًا (still
  due) and المتبقي بعد المصروفات الثابتة, and the three help lines were
  reworded to match; the household currency dropdown shows name + symbol in
  Arabic and name + ISO code in English via the new `currency_name` ICU
  `select` (all 20 supported codes named in both languages); the
  expired-invite label (Expired/منتهي, never Active) is pinned by
  `test/invite_status_test.dart`; `test/l10n_parity_test.dart` now parses
  `select`/`plural` branch bodies so a branch literal like `{Euro}` is not
  mistaken for a placeholder. Tests 156; analyze clean, web release build OK.
- Phase 4a (done, awaiting approval): migration 16 + extended isolation test
  (section 11: budget upsert one-per-category, overall row, pause/resume/
  delete, amount validation, cross-household category rejected, category
  delete cascade, `monthly_totals` 1001-row exactness + dashboard-identical +
  empty-month omission + inverted range, child 0 budgets and every budget RPC
  `forbidden`, outsider lockout; plus the legacy guard proven BOTH ways — a
  `category_id is null` row aborts the migration before any DDL, a category
  row is kept and gets `is_active`). Docker-green (all 16 files on a fresh DB
  + extended isolation test + privilege matrix). Budgets feature: one monthly
  limit per category + one optional overall limit, alerts from SPENT
  (80% near / 100% over, icon + text, never colour alone), projected = spent
  + still-due fixed of the same scope, pause keeps the slot and drops it from
  alerts, owner/adult only, RPC-only writes. Reports feature: this-month
  expenses by category (fl_chart donut + legend with amount and share),
  income vs expenses for the last 6 months (grouped bars via the
  `monthly_totals` RPC — never truncated at PostgREST's 1000-row cap), and
  this-month spending per person (RTL-safe proportional bars). Budgets and
  Reports both read the SHARED dashboard month and the same month rows, so
  every figure reconciles exactly with the dashboard. Dashboard gains a
  compact alert card (category near/over count + overall limit, tap →
  Budgets). New shell branches 7 `/budgets` and 8 `/reports` (adult-only,
  drawer/rail only, bottom bar unchanged). Tests 221
  (`test/budget_progress_test.dart` exact figures incl. 80%/100% boundaries
  and paused exclusion, `test/report_data_test.dart` grouping + 6-month
  fill, `test/budget_report_reconcile_test.dart` 23,845.67 agreement across
  dashboard/budgets/reports + tap-to-open, `test/budget_editor_test.dart`
  0 / >2-decimals rejected and exact minor units stored,
  `test/budgets_reports_layout_test.dart` 360/800/1854 × AR/EN × all roles,
  `test/budgets_reports_nav_test.dart`); analyze clean, web release build OK.
- Phase 4b (done, awaiting approval): migration 17 + extended isolation test
  (sections 12/13 + the amendment-G block; Docker-green on `fresh17g` — all
  17 files + a storage stub — and `bare17` — no `storage` schema — plus the
  privilege matrix). **Receipts**: attach up to 3 image/PDF receipts per
  transaction via `request_receipt_upload` → client upload → `attach_receipt`
  (which re-checks the object exists and reads mime/size from storage);
  images picked with image_picker at 1600px/quality 80 and then **re-encoded
  through the pure `image` package on a `compute` isolate**, which strips
  EXIF/GPS and bakes the orientation; viewer via short-lived signed URLs;
  the picker opens by itself after a NEW transaction is saved
  (`/transactions/edit/:id?receipt=add`). **Deletes** all route through the
  `delete_transaction` RPC (which returns the receipt paths), and
  `delete_fuel_log`/`archive_recurring_rule` now return paths too, so the app
  removes the orphaned objects itself; a Settings action sweeps anything left
  over (`list_orphan_receipts`). **CSV export**: pure `csv_export.dart`
  (RFC-4180 quoting, UTF-8 BOM, plain decimals, injection guard for cells
  starting with `= + - @ \t \r`), filters by period/person/category, and
  client-side `.range()` paging because PostgREST caps a response at ~1000
  rows. **PDF summary**: built with the Cairo subset embedded (Arabic
  contextual shaping), machine-checked in `test/pdf_summary_test.dart`, but
  **gated off** behind `pdfExportEnabled = false` until the user eyeballs
  `docs/phase4b/pdf-sample-ar.pdf` (amendment F — see
  `docs/phase4b/README.md`). **Pet reminders**: vaccine/vet/other with a due
  date and optional repeat, overdue/due-soon (14 days)/scheduled/done status
  chips (icon + text, never colour alone), completing one may post a pet
  expense and re-arms the repeat server-side; `complete_pet_reminder` with no
  linked person raises `no_linked_person` and writes nothing. New error codes
  (`invalid_transaction` / `invalid_receipt` / `invalid_mime` /
  `limit_reached` / `invalid_reminder` / `no_pet_category`). Tests 359
  (`test/csv_export_test.dart` byte-exact quoting + every injection prefix,
  `test/export_pagination_test.dart` 1000-row paging,
  `test/receipt_image_processor_test.dart` EXIF/GPS/orientation-6 strip,
  `test/receipt_validation_test.dart`, `test/pet_reminder_status_test.dart`
  (day clamping, 14-day window), `test/export_reconcile_test.dart`
  (dashboard/CSV/PDF agree at 23,845.67), `test/pdf_summary_test.dart`
  (decompressed CMap carries `FE8D FEDF FEE4 FEE0 FEA8 FEBA`, not the raw
  letters), the layout sweeps `test/export_layout_test.dart` /
  `test/receipt_section_layout_test.dart` /
  `test/pet_reminders_layout_test.dart` (360/800/1854 × AR/EN × roles) and the
  nav tests `test/export_nav_test.dart` / `test/pet_reminder_nav_test.dart`);
  analyze clean, web release build OK.
- Phase 4b excluded on purpose: offline mode and push notifications.

### Phase 4b cloud checklist (what Docker cannot prove)

Docker now mirrors the two hosted-only Storage *metadata/guard* behaviours
(RLS on `storage.buckets`, and the `protect_objects_delete` trigger), so those
no longer need a manual check. What Docker still cannot prove is the Storage
**API** and the service behind it, so these five things are only proven once
migration 17 is applied on the cloud. Do them in this order, right after
pasting migration 17 (step 18 of the manual list):

1. **The bucket exists, is private, and has the right limits.** In the
   dashboard: Storage → `receipts` → it must show *Private* (no public URL),
   a 5 MiB file size limit and the allowed MIME list
   `image/jpeg,image/png,image/webp,application/pdf`. Migration 17 should have
   created it; if the storage schema rejected the insert, create it by hand
   with exactly those settings and re-run only the policy part.
2. **A signed URL works and expires.** Open a transaction → attach a photo →
   tap the thumbnail. The image must render (that is the signed URL working).
   Then reload the page after ~10 minutes; the same thumbnail must now fail
   with "Could not open this receipt", not a leaked permanent URL.
3. **Storage itself rejects bad uploads.** On an existing transaction, try
   attaching a 6 MB photo and a `.zip`/`.txt` file. Both must fail with the
   app's friendly message and *nothing* may appear in the bucket
   (Storage → `receipts` → the folder stays empty for that transaction). This
   is the one case the policies cannot cover: it is enforced by the bucket
   limits, not RLS.
4. **Cross-household and child lockout.** With two real households (or one
   household + an incognito login): household B must not see household A's
   receipts, and deleting B's transaction must not touch A's object (the
   sweep in Settings reports "Nothing to clean up" for B). Signed in as a
   child, the transaction form must show *no* receipts section content at all
   (RLS returns zero rows), and the `/export` route must bounce back to the
   dashboard.
5. **The app can remove its own receipt object through the Storage API.**
   Attach a photo, then delete that receipt (or the whole transaction). The
   thumbnail must disappear, the object must vanish from Storage → `receipts`,
   and Settings → "clean up unused receipt files" must then report *Nothing to
   clean up*. Docker proves the RLS DELETE policy but not the Storage API path
   that sets `storage.allow_delete_query` — this is the end-to-end check that
   the guard does not block the app's own delete.

