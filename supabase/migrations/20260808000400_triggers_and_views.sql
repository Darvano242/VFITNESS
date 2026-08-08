-- =====================================================================
-- VFitness v2 — 04. Triggers, guards, and views
-- =====================================================================

-- ---------------------------------------------------------------------
-- updated_at on every mutable table
-- ---------------------------------------------------------------------
do $$
declare t text;
begin
  foreach t in array array[
    'profiles','trainers','clients','packages','client_packages','appointments',
    'training_sessions','exercises','workout_programs','workout_days','meal_plans',
    'progress_records','online_programs','program_purchases','invoices',
    'trainer_commissions','applications'
  ]
  loop
    execute format(
      'create trigger set_updated_at before update on public.%I
       for each row execute function public.set_updated_at()', t);
  end loop;
end $$;

-- ---------------------------------------------------------------------
-- GUARD: nobody escalates their own role
--
-- RLS cannot express "you may update this row but not this column's
-- value relative to its old value". Without this, the "profiles: update
-- own" policy would let any client set role = 'admin' on themselves.
-- ---------------------------------------------------------------------
create or replace function public.guard_profile_role()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if new.role is distinct from old.role and not public.is_admin() then
    raise exception 'Only an administrator can change a user role'
      using errcode = '42501';
  end if;
  if new.status is distinct from old.status and not public.is_admin() then
    raise exception 'Only an administrator can change account status'
      using errcode = '42501';
  end if;
  return new;
end;
$$;

create trigger guard_profile_role
  before update on public.profiles
  for each row execute function public.guard_profile_role();

-- ---------------------------------------------------------------------
-- GUARD: a trainer cannot reassign clients or change their own rate
-- ---------------------------------------------------------------------
create or replace function public.guard_client_assignment()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if new.assigned_trainer_id is distinct from old.assigned_trainer_id
     and not public.is_admin() then
    raise exception 'Only an administrator can reassign a client'
      using errcode = '42501';
  end if;
  return new;
end;
$$;

create trigger guard_client_assignment
  before update on public.clients
  for each row execute function public.guard_client_assignment();

create or replace function public.guard_commission_rate()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if new.commission_rate is distinct from old.commission_rate
    and not public.is_admin() then
    raise exception 'Only an administrator can change a commission rate'
      using errcode = '42501';
  end if;
  return new;
end;
$$;

create trigger guard_commission_rate
  before update on public.trainers
  for each row execute function public.guard_commission_rate();

-- -------------------------------------------------------------------
-- Session completion decrements the package balance, exactly once.
--
-- Fires only on the scheduled -> completed transition, so re-saving a
-- completed session or reopening and recompleting it cannot double-count.
-- ---------------------------------------------------------------------
create or replace function public.sync_package_on_session_change()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if tg_op = 'UPDATE'
     and new.status = 'completed'
     and old.status <> 'completed'
     and new.deducts_from_package
     and new.client_package_id is not null
  then
    update public.client_packages
       set sessions_used = sessions_used + 1
     where id = new.client_package_id;

    if new.completed_at is null then
      new.completed_at = now();
    end if;
  end if;

  -- Reversal: a completed session moved back to any other status.
  if tg_op = 'UPDATE'
     and old.status = 'completed'
     and new.status <> 'completed'
     and old.deducts_from_package
     and old.client_package_id is not null
  then
    update public.client_packages
       set sessions_used = greatest(sessions_used - 1, 0)
     where id = old.client_package_id;
  end if;

  return new;
end;
$$;

create trigger sync_package_on_session_change
  before update on public.training_sessions
  for each row execute function public.sync_package_on_session_change();

-- Close out a package once its last session is consumed.
create or replace function public.close_exhausted_package()
returns trigger
language plpgsql
as $$
begin
  if new.sessions_used >= new.sessions_purchased and new.status = 'active' then
    new.status = 'completed';
  end if;
  return new;
end;
$$;

create trigger close_exhausted_package
  before update on public.client_packages
  for each row execute function public.close_exhausted_package();

-- ---------------------------------------------------------------------
-- Invoice totals stay consistent with recorded payments
-- ---------------------------------------------------------------------
create or replace function public.recalc_invoice_totals()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  target_invoice uuid := coalesce(new.invoice_id, old.invoice_id);
  paid numeric(10,2);
  inv  public.invoices%rowtype;
begin
  if target_invoice is null then
    return coalesce(new, old);
  end if;

  select coalesce(sum(amount), 0) into paid
    from public.payments
   where invoice_id = target_invoice and status = 'completed';

  select * into inv from public.invoices where id = target_invoice;

  update public.invoices
     set amount_paid = paid,
         status = case
                    when status = 'void' then 'void'
                    when paid >= inv.total and inv.total > 0 then 'paid'
                    when paid > 0 then 'partial'
                    when inv.due_on is not null and inv.due_on < current_date then 'overdue'
                    else status
                  end
   where id = target_invoice;

  return coalesce(new, old);
end;
$$;

create trigger recalc_invoice_totals
  after insert or update or delete on public.payments
  for each row execute function public.recalc_invoice_totals();

-- ---------------------------------------------------------------------
-- New auth user gets a profile automatically
-- ---------------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  insert into public.profiles (id, full_name, email, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', split_part(new.email, '@', 1)),
    new.email,
    -- Role never comes from user-supplied signup metadata. Everyone starts
    -- as a client; admins promote from the admin dashboard.
    'client'
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------
-- Client dashboard rollup
--
-- Backs the whole top section of the client dashboard in one query.
-- security_invoker means the caller's RLS applies, so a client sees only
-- their own row and a trainer only their assigned clients.
-- ---------------------------------------------------------------------
create or replace view public.client_dashboard
with (security_invoker = true)
as
select
  c.id                as client_id,
  c.profile_id,
  p.full_name,
  p.avatar_url,
  c.primary_goal,
  c.assigned_trainer_id,
  tp.full_name        as trainer_name,
  tp.avatar_url       as trainer_avatar_url,

  cp.id               as active_package_id,
  cp.name             as active_package_name,
  cp.sessions_purchased,
  cp.sessions_used    as sessions_completed,
  cp.sessions_remaining,
  cp.expires_on       as package_expires_on,

  (select count(*) from public.training_sessions ts
    where ts.client_id = c.id and ts.status = 'completed')  as lifetime_sessions_completed,

  (select min(a.starts_at) from public.appointments a
    where a.client_id = c.id
      and a.starts_at > now()
      and a.status in ('confirmed', 'requested'))           as next_appointment_at,

  (select wp.id from public.workout_programs wp
    where wp.client_id = c.id and wp.status = 'active'
    order by wp.created_at desc limit 1)                    as current_program_id,

  (select mp.id from public.meal_plans mp
    where mp.client_id = c.id and mp.status = 'active'
    order by mp.created_at desc limit 1)                    as current_meal_plan_id,

  (select pr.weight_kg from public.progress_records pr
    where pr.client_id = c.id and pr.weight_kg is not null
    order by pr.recorded_on desc limit 1)                   as latest_weight_kg,

  c.starting_weight_kg,
  c.target_weight_kg,

  (select count(*) from public.progress_photos pp
    where pp.client_id = c.id)                              as progress_photo_count,

  (select coalesce(sum(i.total - i.amount_paid), 0) from public.invoices i
    where i.client_id = c.id
      and i.status in ('sent', 'partial', 'overdue'))       as balance_outstanding

from public.clients c
join public.profiles p on p.id = c.profile_id
left join public.trainers t  on t.id = c.assigned_trainer_id
left join public.profiles tp on tp.id = t.profile_id
left join lateral (
  select * from public.client_packages
   where client_id = c.id and status = 'active'
   order by purchased_at desc limit 1
) cp on true;

grant select on public.client_dashboard to authenticated;
