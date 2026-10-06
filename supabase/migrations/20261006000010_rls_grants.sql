-- Phase 1 / Migration 10 of 10: Row Level Security + grants + policies
--
-- ===================================================================
-- PLAIN-LANGUAGE SUMMARY OF EVERY POLICY (also commented per policy)
--   household of the caller is determined exclusively by the
--   SECURITY DEFINER helpers in this file, which read
--   household_users using auth.uid(). Helpers are definer functions so
--   policies can consult household_users WITHOUT recursive RLS loops.
-- ===================================================================
--
--  households        SELECT: members see their own household.
--                    UPDATE/DELETE: owner only.
--                    INSERT: (none) -> only create_household().
--  household_users   SELECT: members see who is in their household.
--                    UPDATE: owner only (role changes); user_id and
--                    household_id are frozen by trigger.
--                    INSERT/DELETE: (none) -> only create_household()
--                    and accept_invite().
--  members           SELECT: members see the household's people; a child
--                    sees only the row linked to their own login.
--                    INSERT/UPDATE/DELETE: owner/adult only.
--  categories        SELECT: everyone (children need categories to spend).
--                    INSERT/UPDATE/DELETE: owner/adult only.
--  vehicles          SELECT: members. INSERT/UPDATE/DELETE: owner/adult.
--  transactions      SELECT: owner/adult see all household transactions;
--                    a child sees only transactions of the person row
--                    linked to their login.
--                    INSERT: same rule + member/category/vehicle/recurring
--                    row must belong to the same household.
--                    UPDATE/DELETE: same visibility rule as SELECT.
--  recurring_rules   SELECT: members. INSERT/UPDATE/DELETE: owner/adult.
--  budgets           SELECT: members. INSERT/UPDATE/DELETE: owner/adult.
--  invites           SELECT: members (codes are shareable inside the
--                    family). INSERT/UPDATE/DELETE: (none) -> only
--                    create_invite()/accept_invite().
-- ===================================================================

-- ---------------------------------------------------------------------------
-- 0. Policy helper predicates (SECURITY DEFINER, no recursion)
-- ---------------------------------------------------------------------------

-- TRUE when the caller is owner or adult of the household.
create or replace function public.is_household_adult(p_household_id uuid)
returns boolean
language sql stable security definer set search_path = public parallel safe
as $$
  select public.household_role(p_household_id) in ('owner', 'adult');
$$;

-- TRUE when the caller's login is linked (members.user_id) to that member
-- row inside that household. This is the basis of all child policies.
create or replace function public.owns_member_row(p_household_id uuid, p_member_id uuid)
returns boolean
language sql stable security definer set search_path = public parallel safe
as $$
  select exists (
    select 1 from public.members m
    where m.id = p_member_id
      and m.household_id = p_household_id
      and m.user_id = auth.uid()
  );
$$;

-- Integrity predicates used by the transactions INSERT policy: the linked
-- row must live in the SAME household as the transaction.
create or replace function public.member_in_household(p_household_id uuid, p_member_id uuid)
returns boolean
language sql stable security definer set search_path = public parallel safe
as $$
  select exists (select 1 from public.members m
                 where m.id = p_member_id and m.household_id = p_household_id);
$$;

create or replace function public.category_in_household(p_household_id uuid, p_category_id uuid)
returns boolean
language sql stable security definer set search_path = public parallel safe
as $$
  select exists (select 1 from public.categories c
                 where c.id = p_category_id and c.household_id = p_household_id);
$$;

create or replace function public.vehicle_in_household(p_household_id uuid, p_vehicle_id uuid)
returns boolean
language sql stable security definer set search_path = public parallel safe
as $$
  select exists (select 1 from public.vehicles v
                 where v.id = p_vehicle_id and v.household_id = p_household_id);
$$;

create or replace function public.recurring_in_household(p_household_id uuid, p_rule_id uuid)
returns boolean
language sql stable security definer set search_path = public parallel safe
as $$
  select exists (select 1 from public.recurring_rules r
                 where r.id = p_rule_id and r.household_id = p_household_id);
$$;

-- ---------------------------------------------------------------------------
-- 1. Freeze membership identity: an UPDATE may change role only.
--    Without this, an owner UPDATE could set user_id to an arbitrary login
--    and bypass the invite flow.
-- ---------------------------------------------------------------------------
create or replace function public.household_users_immutable_identity()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  if new.user_id is distinct from old.user_id
     or new.household_id is distinct from old.household_id then
    raise exception 'membership_identity_immutable';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_household_users_immutable_identity on public.household_users;
create trigger trg_household_users_immutable_identity
before update on public.household_users
for each row execute function public.household_users_immutable_identity();

-- ---------------------------------------------------------------------------
-- 2. Enable RLS on EVERY table (default deny)
-- ---------------------------------------------------------------------------
alter table public.households      enable row level security;
alter table public.household_users enable row level security;
alter table public.members         enable row level security;
alter table public.categories      enable row level security;
alter table public.vehicles        enable row level security;
alter table public.transactions    enable row level security;
alter table public.recurring_rules enable row level security;
alter table public.budgets         enable row level security;
alter table public.invites         enable row level security;

-- ---------------------------------------------------------------------------
-- 3. Privileges
--    Table access: authenticated (and service_role for admin tooling) only.
--    The app ships NO service-role key; this grant exists for Supabase's own
--    tooling, never for client code.
--    Function access: create_household / create_invite / accept_invite are
--    executable by authenticated; seed_default_categories is executable by
--    NOBODY outside definer functions (revoked below).
-- ---------------------------------------------------------------------------
grant usage on schema public to authenticated, service_role;
grant select, insert, update, delete on all tables in schema public to authenticated, service_role;
grant usage on all sequences in schema public to authenticated, service_role;
grant execute on all functions in schema public to authenticated, service_role;
revoke all on all tables in schema public from anon;
revoke all on all sequences in schema public from anon;
revoke execute on function public.seed_default_categories(uuid) from public, anon, authenticated, service_role;
grant execute on function public.create_household(text, text) to authenticated;
grant execute on function public.create_invite(uuid, text, integer) to authenticated;
grant execute on function public.accept_invite(text) to authenticated;

-- ---------------------------------------------------------------------------
-- 4. households
-- ---------------------------------------------------------------------------
drop policy if exists "households_select_member" on public.households;
-- "Every member of a household can read that household's row (name/currency)."
create policy "households_select_member" on public.households
  for select to authenticated
  using (public.is_household_member(id));

drop policy if exists "households_update_owner" on public.households;
-- "Only the owner can rename the household or change its currency."
create policy "households_update_owner" on public.households
  for update to authenticated
  using (public.household_role(id) = 'owner')
  with check (public.household_role(id) = 'owner');

drop policy if exists "households_delete_owner" on public.households;
-- "Only the owner can delete the household (cascades to all its data)."
create policy "households_delete_owner" on public.households
  for delete to authenticated
  using (public.household_role(id) = 'owner');

-- NO INSERT POLICY -> households only via create_household().

-- ---------------------------------------------------------------------------
-- 5. household_users
-- ---------------------------------------------------------------------------
drop policy if exists "household_users_select_member" on public.household_users;
-- "Members can see who belongs to their household, including their own role."
create policy "household_users_select_member" on public.household_users
  for select to authenticated
  using (public.is_household_member(household_id));

drop policy if exists "household_users_update_owner" on public.household_users;
-- "Only the owner can change a member's role (owner/adult/child).
--  user_id and household_id cannot change: trigger above."
create policy "household_users_update_owner" on public.household_users
  for update to authenticated
  using (public.household_role(household_id) = 'owner')
  with check (
    public.household_role(household_id) = 'owner'
    and role in ('owner', 'adult', 'child')
  );

-- NO INSERT POLICY, NO DELETE POLICY ->
-- joining only via create_household()/accept_invite(); nobody can silently
-- add themselves to an arbitrary household or evict other members.

-- ---------------------------------------------------------------------------
-- 6. members (the people whose spending is tracked)
-- ---------------------------------------------------------------------------
drop policy if exists "members_select_visible" on public.members;
-- "Members of a household see all of its people; a child sees ONLY the
--  person row linked to their own login (members.user_id = auth.uid())."
create policy "members_select_visible" on public.members
  for select to authenticated
  using (
    public.is_household_member(household_id)
    and (public.household_role(household_id) <> 'child' or user_id = auth.uid())
  );

drop policy if exists "members_insert_adult" on public.members;
-- "Only owners and adults can add people to the household."
create policy "members_insert_adult" on public.members
  for insert to authenticated
  with check (public.is_household_member(household_id) and public.is_household_adult(household_id));

drop policy if exists "members_update_adult" on public.members;
-- "Only owners and adults can rename/deactivate/link people (including
--  setting members.user_id to link a login)."
create policy "members_update_adult" on public.members
  for update to authenticated
  using (public.is_household_member(household_id) and public.is_household_adult(household_id))
  with check (public.is_household_member(household_id) and public.is_household_adult(household_id));

drop policy if exists "members_delete_adult" on public.members;
-- "Only owners and adults can remove people."
create policy "members_delete_adult" on public.members
  for delete to authenticated
  using (public.is_household_member(household_id) and public.is_household_adult(household_id));

-- ---------------------------------------------------------------------------
-- 7. categories (including the seeded defaults)
-- ---------------------------------------------------------------------------
drop policy if exists "categories_select_member" on public.categories;
-- "Everyone in the household - children too - can browse categories,
--  because children need them to record their own spending."
create policy "categories_select_member" on public.categories
  for select to authenticated
  using (public.is_household_member(household_id));

drop policy if exists "categories_insert_adult" on public.categories;
-- "Only owners and adults can add custom categories."
create policy "categories_insert_adult" on public.categories
  for insert to authenticated
  with check (public.is_household_member(household_id) and public.is_household_adult(household_id));

drop policy if exists "categories_update_adult" on public.categories;
-- "Only owners and adults can edit categories (names, icons, colors)."
create policy "categories_update_adult" on public.categories
  for update to authenticated
  using (public.is_household_member(household_id) and public.is_household_adult(household_id))
  with check (public.is_household_member(household_id) and public.is_household_adult(household_id));

drop policy if exists "categories_delete_adult" on public.categories;
-- "Only owners and adults can delete categories."
create policy "categories_delete_adult" on public.categories
  for delete to authenticated
  using (public.is_household_member(household_id) and public.is_household_adult(household_id));

-- ---------------------------------------------------------------------------
-- 8. vehicles
-- ---------------------------------------------------------------------------
drop policy if exists "vehicles_select_member" on public.vehicles;
-- "Members can see the household's vehicles."
create policy "vehicles_select_member" on public.vehicles
  for select to authenticated
  using (public.is_household_member(household_id));

drop policy if exists "vehicles_insert_adult" on public.vehicles;
-- "Only owners and adults can add vehicles."
create policy "vehicles_insert_adult" on public.vehicles
  for insert to authenticated
  with check (public.is_household_member(household_id) and public.is_household_adult(household_id));

drop policy if exists "vehicles_update_adult" on public.vehicles;
-- "Only owners and adults can edit vehicles (name, plate, odometer)."
create policy "vehicles_update_adult" on public.vehicles
  for update to authenticated
  using (public.is_household_member(household_id) and public.is_household_adult(household_id))
  with check (public.is_household_member(household_id) and public.is_household_adult(household_id));

drop policy if exists "vehicles_delete_adult" on public.vehicles;
-- "Only owners and adults can delete vehicles."
create policy "vehicles_delete_adult" on public.vehicles
  for delete to authenticated
  using (public.is_household_member(household_id) and public.is_household_adult(household_id));

-- ---------------------------------------------------------------------------
-- 9. transactions
-- ---------------------------------------------------------------------------
drop policy if exists "transactions_select" on public.transactions;
-- "Owners/adults read every transaction of their household.
--  A child reads ONLY transactions recorded for the person row linked to
--  their login (owns_member_row). Members of other households see nothing."
create policy "transactions_select" on public.transactions
  for select to authenticated
  using (
    public.is_household_member(household_id)
    and (
      public.is_household_adult(household_id)
      or public.owns_member_row(household_id, member_id)
    )
  );

drop policy if exists "transactions_insert" on public.transactions;
-- "Same visibility rule as reading, PLUS every referenced row (person,
--  category, vehicle, recurring rule) must live in the SAME household -
--  so nobody can smuggle foreign ids into their transactions."
create policy "transactions_insert" on public.transactions
  for insert to authenticated
  with check (
    public.is_household_member(household_id)
    and (
      public.is_household_adult(household_id)
      or public.owns_member_row(household_id, member_id)
    )
    and public.member_in_household(household_id, member_id)
    and public.category_in_household(household_id, category_id)
    and (vehicle_id is null or public.vehicle_in_household(household_id, vehicle_id))
    and (recurring_rule_id is null or public.recurring_in_household(household_id, recurring_rule_id))
  );

drop policy if exists "transactions_update" on public.transactions;
-- "You may edit a transaction only if you can see it (rules above);
--  the edited row must still satisfy the insert rule."
create policy "transactions_update" on public.transactions
  for update to authenticated
  using (
    public.is_household_member(household_id)
    and (
      public.is_household_adult(household_id)
      or public.owns_member_row(household_id, member_id)
    )
  )
  with check (
    public.is_household_member(household_id)
    and (
      public.is_household_adult(household_id)
      or public.owns_member_row(household_id, member_id)
    )
    and public.member_in_household(household_id, member_id)
    and public.category_in_household(household_id, category_id)
    and (vehicle_id is null or public.vehicle_in_household(household_id, vehicle_id))
    and (recurring_rule_id is null or public.recurring_in_household(household_id, recurring_rule_id))
  );

drop policy if exists "transactions_delete" on public.transactions;
-- "You may delete a transaction only if you can see it."
create policy "transactions_delete" on public.transactions
  for delete to authenticated
  using (
    public.is_household_member(household_id)
    and (
      public.is_household_adult(household_id)
      or public.owns_member_row(household_id, member_id)
    )
  );

-- ---------------------------------------------------------------------------
-- 10. recurring_rules
-- ---------------------------------------------------------------------------
drop policy if exists "recurring_select_member" on public.recurring_rules;
-- "Members can see the household's recurring rules (upcoming dues)."
create policy "recurring_select_member" on public.recurring_rules
  for select to authenticated
  using (public.is_household_member(household_id));

drop policy if exists "recurring_insert_adult" on public.recurring_rules;
-- "Only owners and adults can create recurring rules."
create policy "recurring_insert_adult" on public.recurring_rules
  for insert to authenticated
  with check (public.is_household_member(household_id) and public.is_household_adult(household_id));

drop policy if exists "recurring_update_adult" on public.recurring_rules;
-- "Only owners and adults can edit/pause recurring rules."
create policy "recurring_update_adult" on public.recurring_rules
  for update to authenticated
  using (public.is_household_member(household_id) and public.is_household_adult(household_id))
  with check (public.is_household_member(household_id) and public.is_household_adult(household_id));

drop policy if exists "recurring_delete_adult" on public.recurring_rules;
-- "Only owners and adults can delete recurring rules."
create policy "recurring_delete_adult" on public.recurring_rules
  for delete to authenticated
  using (public.is_household_member(household_id) and public.is_household_adult(household_id));

-- ---------------------------------------------------------------------------
-- 11. budgets
-- ---------------------------------------------------------------------------
drop policy if exists "budgets_select_member" on public.budgets;
-- "Members can see the household's budgets."
create policy "budgets_select_member" on public.budgets
  for select to authenticated
  using (public.is_household_member(household_id));

drop policy if exists "budgets_insert_adult" on public.budgets;
-- "Only owners and adults can set budgets."
create policy "budgets_insert_adult" on public.budgets
  for insert to authenticated
  with check (public.is_household_member(household_id) and public.is_household_adult(household_id));

drop policy if exists "budgets_update_adult" on public.budgets;
-- "Only owners and adults can change budgets."
create policy "budgets_update_adult" on public.budgets
  for update to authenticated
  using (public.is_household_member(household_id) and public.is_household_adult(household_id))
  with check (public.is_household_member(household_id) and public.is_household_adult(household_id));

drop policy if exists "budgets_delete_adult" on public.budgets;
-- "Only owners and adults can delete budgets."
create policy "budgets_delete_adult" on public.budgets
  for delete to authenticated
  using (public.is_household_member(household_id) and public.is_household_adult(household_id));

-- ---------------------------------------------------------------------------
-- 12. invites
-- ---------------------------------------------------------------------------
drop policy if exists "invites_select_member" on public.invites;
-- "Members can see their household's invite codes (to share with family).
--  A child seeing a code is harmless: accepting it fails with
--  already_member."
create policy "invites_select_member" on public.invites
  for select to authenticated
  using (public.is_household_member(household_id));

-- NO INSERT / UPDATE / DELETE POLICIES ->
-- codes are created by create_invite() and consumed by accept_invite().
