-- =====================================================================
-- VFitness v2 — 01. Extensions, enums, and RLS helper functions
-- =====================================================================

create extension if not exists "pgcrypto";
create extension if not exists "citext";

-- ---------------------------------------------------------------------
-- Enums
-- ---------------------------------------------------------------------
create type user_role          as enum ('admin', 'trainer', 'client');
create type account_status     as enum ('active', 'inactive', 'suspended', 'pending');
create type package_status     as enum ('pending', 'active', 'completed', 'expired', 'cancelled');
create type session_status     as enum ('scheduled', 'completed', 'no_show', 'cancelled');
create type appointment_status as enum ('requested', 'confirmed', 'cancelled', 'completed');
create type program_status     as enum ('draft', 'assigned', 'active', 'completed', 'archived');
create type invoice_status     as enum ('draft', 'sent', 'paid', 'partial', 'overdue', 'void');
create type payment_status     as enum ('pending', 'completed', 'failed', 'refunded');
create type payment_method     as enum ('paypal', 'card', 'cash', 'bank_transfer', 'other');
create type application_kind   as enum ('client', 'trainer');
create type application_status as enum ('new', 'reviewing', 'approved', 'rejected', 'waitlist');
create type commission_status  as enum ('pending', 'approved', 'paid', 'void');
create type commission_source  as enum ('session', 'package', 'online_program', 'invoice', 'manual');
create type photo_pose         as enum ('front', 'side_left', 'side_right', 'back', 'other');
create type meal_type          as enum ('breakfast', 'lunch', 'dinner', 'snack', 'pre_workout', 'post_workout');
create type difficulty_level   as enum ('beginner', 'intermediate', 'advanced');
create type purchase_status    as enum ('pending', 'active', 'refunded', 'expired');

-- ---------------------------------------------------------------------
-- RLS helper functions
--
-- All are SECURITY DEFINER so they can read profiles/clients/trainers
-- without being re-filtered by the very policies that call them. This is
-- what prevents infinite RLS recursion. search_path is pinned so the
-- definer rights cannot be hijacked by a caller-set search_path.
-- ---------------------------------------------------------------------

create or replace function public.current_user_role()
returns user_role
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select role from public.profiles where id = auth.uid();
$$;

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select coalesce((select role = 'admin' from public.profiles where id = auth.uid()), false);
$$;

create or replace function public.current_client_id()
returns uuid
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select id from public.clients where profile_id = auth.uid();
$$;

create or replace function public.current_trainer_id()
returns uuid
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select id from public.trainers where profile_id = auth.uid();
$$;

-- True when the signed-in trainer is the assigned trainer for that client.
-- This is the single chokepoint for "trainers see only their own clients" —
-- every trainer policy in 03_rls.sql routes through it, so the rule is
-- defined once and cannot drift between tables.
create or replace function public.trainer_owns_client(target_client_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.clients c
    join public.trainers t on t.id = c.assigned_trainer_id
    where c.id = target_client_id
      and t.profile_id = auth.uid()
  );
$$;

-- Convenience: admin OR the client themselves OR their assigned trainer.
create or replace function public.can_access_client(target_client_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select
    public.is_admin()
    or target_client_id = public.current_client_id()
    or public.trainer_owns_client(target_client_id);
$$;

revoke execute on function public.current_user_role()    from public;
revoke execute on function public.is_admin()             from public;
revoke execute on function public.current_client_id()    from public;
revoke execute on function public.current_trainer_id()   from public;
revoke execute on function public.trainer_owns_client(uuid) from public;
revoke execute on function public.can_access_client(uuid)   from public;

grant execute on function public.current_user_role()    to authenticated;
grant execute on function public.is_admin()             to authenticated;
grant execute on function public.current_client_id()    to authenticated;
grant execute on function public.current_trainer_id()   to authenticated;
grant execute on function public.trainer_owns_client(uuid) to authenticated;
grant execute on function public.can_access_client(uuid)   to authenticated;

-- Shared updated_at trigger
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;
