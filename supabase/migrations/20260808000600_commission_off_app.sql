-- =====================================================================
-- VFitness v2 — 06. Commission is off-app
--
-- Trainer commission is settled in person. It must not be readable by
-- trainers or clients through the app under any circumstances.
--
-- Two leaks existed in migration 03:
--   1. "trainers: readable by all signed-in users" exposed the whole row,
--      including commission_rate and hourly_rate, to every authenticated
--      user. A client could read their trainer's rate; trainers could read
--      each other's.
--   2. "trainer_commissions: trainer reads own" let a trainer pull their
--      own commission ledger.
--
-- The records stay in the database for admin bookkeeping, since admins
-- retain full control per the brief. They are simply unreachable from any
-- non-admin session.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Close the trainers table
-- ---------------------------------------------------------------------
drop policy if exists "trainers: readable by all signed-in users" on public.trainers;

create policy "trainers: read own row"
  on public.trainers for select to authenticated
  using (profile_id = auth.uid());

create policy "trainers: admin reads"
  on public.trainers for select to authenticated
  using (public.is_admin());

-- Clients and the storefront still need trainer names, bios and
-- specialties. They get them from a view that simply has no commission or
-- rate column to leak. The view runs with owner rights (not
-- security_invoker), so it can read past the policies above.
create or replace view public.trainer_directory as
select
  t.id,
  t.profile_id,
  p.full_name,
  p.avatar_url,
  t.bio,
  t.specialties,
  t.certifications,
  t.years_experience,
  t.gym_locations,
  t.accepting_clients,
  t.status
from public.trainers t
join public.profiles p on p.id = t.profile_id
where t.status = 'active';

revoke all on public.trainer_directory from anon, authenticated;
grant select on public.trainer_directory to anon, authenticated;

comment on view public.trainer_directory is
  'Safe public projection of trainers. Deliberately omits commission_rate '
  'and hourly_rate. Read this from the app, never public.trainers.';

-- ---------------------------------------------------------------------
-- 2. Close the commission ledger
-- ---------------------------------------------------------------------
drop policy if exists "trainer_commissions: trainer reads own" on public.trainer_commissions;

-- Only "trainer_commissions: admin reads" and "...: admin writes" remain.
-- With RLS enabled and no policy matching a trainer or client, the table
-- returns zero rows to them rather than erroring, which is the behaviour
-- we want: it does not exist as far as the app is concerned.

-- ---------------------------------------------------------------------
-- 3. Belt and braces on the column itself
--
-- Policies gate rows, not columns. If a future policy is ever added that
-- widens select on public.trainers, this revoke keeps the two money
-- columns unreadable regardless.
-- ---------------------------------------------------------------------
revoke select (commission_rate, hourly_rate) on public.trainers from authenticated;
revoke select (commission_rate, hourly_rate) on public.trainers from anon;

-- ---------------------------------------------------------------------
-- 4. Verification
--
-- Run as a trainer and as a client. Both must return zero rows.
--
--   select * from public.trainer_commissions;
--   select commission_rate from public.trainers;   -- must raise permission denied
--   select * from public.trainer_directory;        -- must succeed, no rate column
-- ---------------------------------------------------------------------
