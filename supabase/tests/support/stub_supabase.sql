-- Supabase environment stub for local migration/isolation-test validation.
-- Canonical copy: supabase/tests/support/stub_supabase.sql
-- Run by tool/docker/validate.sh. Idempotent: safe to re-run on a stubbed DB.
--
-- It reproduces the parts of hosted Supabase this project touches, including
-- the two hosted Storage behaviours that only show up on the cloud:
--   1. RLS enabled on storage.buckets with NO read policy for authenticated
--      (a metadata read made as `authenticated` returns zero rows); and
--   2. the protect_objects_delete BEFORE DELETE FOR EACH STATEMENT trigger
--      (raises 42501 unless storage.allow_delete_query = 'true').
-- See tool/docker/README.md.
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
-- ------------------------------------------------------------------
-- Storage stub (Phase 4b): enough of Supabase Storage for migration 17's
-- bucket row + storage.objects policies to be created and tested.
-- Mirrors the real columns/policies surface we touch. Enabled RLS so the
-- policies are the deciding factor (as on the cloud).
-- ------------------------------------------------------------------
create schema if not exists storage;

create table if not exists storage.buckets (
  id                   text primary key,
  name                 text not null,
  owner                uuid,
  owner_id             text,
  public               boolean default false,
  avif_autodetection   boolean default false,
  file_size_limit      bigint,
  allowed_mime_types   text[],
  created_at           timestamptz default now(),
  updated_at           timestamptz default now()
);

create table if not exists storage.objects (
  id                 uuid primary key default gen_random_uuid(),
  bucket_id          text references storage.buckets(id),
  name               text,
  owner              uuid,
  owner_id           text,
  metadata           jsonb,
  path_tokens        text[],
  version            text,
  user_metadata      jsonb,
  created_at         timestamptz default now(),
  updated_at         timestamptz default now(),
  last_accessed_at   timestamptz
);

-- Same definition as Supabase's storage.foldername: the path tokens with
-- the FILE NAME removed ('hh/tx/f.jpg' -> {hh,tx}).
create or replace function storage.foldername(name text)
returns text[]
language plpgsql
immutable
as $$
declare
  _parts text[];
begin
  select string_to_array(name, '/') into _parts;
  return _parts[1:array_length(_parts, 1) - 1];
end $$;

alter table storage.objects enable row level security;

-- Honest stub, lesson learned in the cloud: on hosted Supabase storage.buckets
-- has RLS enabled with NO policy that lets `authenticated` (or `anon`) read it,
-- so a SELECT from inside a `set local role authenticated` block returns zero
-- rows. Enabling it here means the isolation test's metadata reads fail in
-- Docker too if they forget to use the privileged role, instead of only failing
-- on the cloud.
alter table storage.buckets enable row level security;

grant usage on schema storage to anon, authenticated, service_role;
grant execute on function storage.foldername(text) to anon, authenticated, service_role;
grant select, insert, update, delete on storage.objects to authenticated, service_role;
grant select on storage.buckets to authenticated, service_role;

-- ------------------------------------------------------------------
-- Storage stub: the hosted delete guard + updated_at trigger.
--
-- Learned the hard way on the cloud. Hosted storage.objects carries:
--   * protect_objects_delete  BEFORE DELETE FOR EACH STATEMENT -> raises
--     42501 "Direct deletion from storage tables is not allowed" unless
--     storage.allow_delete_query = 'true' (the Storage API sets that GUC
--     when it deletes on a user's behalf). Note: FOR EACH STATEMENT, so it
--     fires even when zero rows match;
--   * update_objects_updated_at BEFORE UPDATE FOR EACH ROW -> stamps
--     updated_at = now().
-- Mirrored verbatim (same names, timing and granularity) so a direct
-- storage.objects delete that forgets the GUC fails in Docker too, exactly
-- like it does on the cloud, instead of silently passing here.
-- ------------------------------------------------------------------
create or replace function storage.protect_delete()
returns trigger
language plpgsql
as $$
BEGIN
  IF COALESCE(current_setting('storage.allow_delete_query', true), 'false') != 'true' THEN
    RAISE EXCEPTION 'Direct deletion from storage tables is not allowed. Use the Storage API instead.'
      USING HINT = 'This prevents accidental data loss from orphaned objects.', ERRCODE = '42501';
  END IF;
  RETURN NULL;
END;
$$;

create or replace function storage.update_updated_at_column()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists protect_objects_delete on storage.objects;
create trigger protect_objects_delete
  before delete on storage.objects
  for each statement execute function storage.protect_delete();

drop trigger if exists update_objects_updated_at on storage.objects;
create trigger update_objects_updated_at
  before update on storage.objects
  for each row execute function storage.update_updated_at_column();

grant execute on function storage.protect_delete() to anon, authenticated, service_role;
grant execute on function storage.update_updated_at_column() to anon, authenticated, service_role;
