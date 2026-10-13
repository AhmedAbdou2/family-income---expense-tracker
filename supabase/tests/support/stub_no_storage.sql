-- Same as stub_supabase.sql but WITHOUT the storage schema, to prove
-- migration 17 still applies on a plain Postgres (its whole storage block is
-- wrapped in `if exists (pg_namespace 'storage')`).
-- Canonical copy: supabase/tests/support/stub_no_storage.sql
-- Run by tool/docker/validate.sh <db> bare
do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then
    create role anon nologin;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then
    create role authenticated nologin;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'service_role') then
    create role service_role nologin;
  end if;
end
$$;

create schema if not exists extensions;
create schema if not exists auth;

create table if not exists auth.users (
  instance_id            uuid,
  id                     uuid primary key,
  aud                    varchar(255),
  role                   varchar(255),
  email                  varchar(255),
  encrypted_password     varchar(255),
  email_confirmed_at     timestamptz,
  raw_app_meta_data      jsonb,
  raw_user_meta_data     jsonb,
  created_at             timestamptz,
  updated_at             timestamptz
);

create or replace function auth.uid() returns uuid
language sql stable
as $$
  select nullif(
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub'),
    ''
  )::uuid;
$$;

grant usage on schema public to anon, authenticated, service_role;
grant usage on schema auth to anon, authenticated, service_role;
grant execute on function auth.uid() to anon, authenticated, service_role;
grant usage on schema extensions to anon, authenticated, service_role;
-- (deliberately NO storage schema: proves migration 17 skips the storage block)
