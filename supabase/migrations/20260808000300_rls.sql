-- =====================================================================
-- VFitness v2 — 03. Row Level Security
--
-- Model:
--   admin   — full read/write everywhere
--   trainer — read/write only for clients where clients.assigned_trainer_id
--             matches their own trainer row; read-only on their own money
--   client  — read/write only their own rows; read-only on money and on
--             anything a trainer prescribes to them
--
-- Every table has RLS enabled. Tables with no policy for a role are
-- closed to that role by default — that is deliberate, not an omission.
-- The service_role key bypasses RLS entirely and is what the import
-- scripts and PayPal webhook use.
-- =====================================================================

alter table public.profiles              enable row level security;
alter table public.trainers              enable row level security;
alter table public.clients               enable row level security;
alter table public.packages              enable row level security;
alter table public.client_packages       enable row level security;
alter table public.appointments          enable row level security;
alter table public.training_sessions     enable row level security;
alter table public.exercises             enable row level security;
alter table public.workout_programs      enable row level security;
alter table public.workout_days          enable row level security;
alter table public.workout_day_exercises enable row level security;
alter table public.exercise_logs         enable row level security;
alter table public.meal_plans            enable row level security;
alter table public.nutrition_logs        enable row level security;
alter table public.progress_records      enable row level security;
alter table public.progress_photos       enable row level security;
alter table public.online_programs       enable row level security;
alter table public.program_purchases     enable row level security;
alter table public.invoices              enable row level security;
alter table public.payments              enable row level security;
alter table public.trainer_commissions   enable row level security;
alter table public.applications          enable row level security;
alter table public.notifications         enable row level security;

-- ---------------------------------------------------------------------
-- profiles
-- ---------------------------------------------------------------------
create policy "profiles: read own"
  on public.profiles for select to authenticated
  using (id = auth.uid());

create policy "profiles: read as admin"
  on public.profiles for select to authenticated
  using (public.is_admin());

-- A trainer can see the profile of a client assigned to them.
create policy "profiles: trainer reads assigned client profiles"
  on public.profiles for select to authenticated
  using (
    exists (
      select 1 from public.clients c
      where c.profile_id = public.profiles.id
        and public.trainer_owns_client(c.id)
    )
  );

-- Clients may see the profile of their own trainer (name, avatar, bio).
create policy "profiles: client reads own trainer profile"
  on public.profiles for select to authenticated
  using (
    exists (
      select 1
      from public.clients c
      join public.trainers t on t.id = c.assigned_trainer_id
      where c.profile_id = auth.uid()
        and t.profile_id = public.profiles.id
    )
  );

create policy "profiles: update own"
  on public.profiles for update to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

create policy "profiles: admin writes"
  on public.profiles for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- NOTE: role escalation is blocked by a trigger in migration 04, not here.
-- A USING/WITH CHECK clause cannot compare old and new values.

-- ---------------------------------------------------------------------
-- trainers
-- ---------------------------------------------------------------------
create policy "trainers: readable by all signed-in users"
  on public.trainers for select to authenticated
  using (true);

create policy "trainers: update own"
  on public.trainers for update to authenticated
  using (profile_id = auth.uid())
  with check (profile_id = auth.uid());

create policy "trainers: admin writes"
  on public.trainers for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- ---------------------------------------------------------------------
-- clients
-- ---------------------------------------------------------------------
create policy "clients: read own"
  on public.clients for select to authenticated
  using (profile_id = auth.uid());

create policy "clients: trainer reads assigned"
  on public.clients for select to authenticated
  using (public.trainer_owns_client(id));

create policy "clients: update own"
  on public.clients for update to authenticated
  using (profile_id = auth.uid())
  with check (profile_id = auth.uid());

-- Trainers may edit training-relevant fields on their own clients.
-- assigned_trainer_id is protected by a trigger in migration 04 so a
-- trainer cannot reassign a client to themselves or away.
create policy "clients: trainer updates assigned"
  on public.clients for update to authenticated
  using (public.trainer_owns_client(id))
  with check (public.trainer_owns_client(id));

create policy "clients: admin writes"
  on public.clients for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- ---------------------------------------------------------------------
-- packages (public catalogue)
-- ---------------------------------------------------------------------
create policy "packages: anyone reads active"
  on public.packages for select to anon, authenticated
  using (is_active or public.is_admin());

create policy "packages: admin writes"
  on public.packages for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- ---------------------------------------------------------------------
-- client_packages
-- ---------------------------------------------------------------------
create policy "client_packages: read if permitted"
  on public.client_packages for select to authenticated
  using (public.can_access_client(client_id));

create policy "client_packages: admin writes"
  on public.client_packages for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- Clients and trainers never write packages directly — session completion
-- decrements the balance via trigger, and purchase goes through the
-- payment webhook on the service_role key.

-- ---------------------------------------------------------------------
-- appointments
-- ---------------------------------------------------------------------
create policy "appointments: read if permitted"
  on public.appointments for select to authenticated
  using (public.can_access_client(client_id));

create policy "appointments: client requests own"
  on public.appointments for insert to authenticated
  with check (client_id = public.current_client_id());

create policy "appointments: client cancels own"
  on public.appointments for update to authenticated
  using (client_id = public.current_client_id())
  with check (client_id = public.current_client_id());

create policy "appointments: trainer manages assigned"
  on public.appointments for all to authenticated
  using (public.trainer_owns_client(client_id))
  with check (public.trainer_owns_client(client_id));

create policy "appointments: admin writes"
  on public.appointments for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- ---------------------------------------------------------------------
-- training_sessions
-- ---------------------------------------------------------------------
create policy "training_sessions: read if permitted"
  on public.training_sessions for select to authenticated
  using (public.can_access_client(client_id));

create policy "training_sessions: trainer manages assigned"
  on public.training_sessions for all to authenticated
  using (public.trainer_owns_client(client_id))
  with check (public.trainer_owns_client(client_id));

create policy "training_sessions: client rates own"
  on public.training_sessions for update to authenticated
  using (client_id = public.current_client_id())
  with check (client_id = public.current_client_id());

create policy "training_sessions: admin writes"
  on public.training_sessions for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- ---------------------------------------------------------------------
-- exercises (shared library)
-- ---------------------------------------------------------------------
create policy "exercises: read public or own"
  on public.exercises for select to authenticated
  using (is_public or created_by = auth.uid() or public.is_admin());

create policy "exercises: trainer creates"
  on public.exercises for insert to authenticated
  with check (public.current_user_role() in ('trainer', 'admin'));

create policy "exercises: author updates own"
  on public.exercises for update to authenticated
  using (created_by = auth.uid())
  with check (created_by = auth.uid());

create policy "exercises: admin writes"
  on public.exercises for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- ---------------------------------------------------------------------
-- workout_programs / days / day_exercises
-- ---------------------------------------------------------------------
create policy "workout_programs: read if permitted"
  on public.workout_programs for select to authenticated
  using (
    (client_id is not null and public.can_access_client(client_id))
    or (is_template and public.current_user_role() in ('trainer', 'admin'))
  );

create policy "workout_programs: trainer manages"
  on public.workout_programs for all to authenticated
  using (
    (client_id is not null and public.trainer_owns_client(client_id))
    or (is_template and trainer_id = public.current_trainer_id())
  )
  with check (
    (client_id is not null and public.trainer_owns_client(client_id))
    or (is_template and trainer_id = public.current_trainer_id())
  );

create policy "workout_programs: admin writes"
  on public.workout_programs for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- Child tables inherit access from the parent program.
create policy "workout_days: inherit program access"
  on public.workout_days for select to authenticated
  using (
    exists (
      select 1 from public.workout_programs p
      where p.id = program_id
        and ((p.client_id is not null and public.can_access_client(p.client_id))
             or (p.is_template and public.current_user_role() in ('trainer', 'admin')))
    )
  );

create policy "workout_days: trainer and admin write"
  on public.workout_days for all to authenticated
  using (
    public.is_admin() or exists (
      select 1 from public.workout_programs p
      where p.id = program_id
        and ((p.client_id is not null and public.trainer_owns_client(p.client_id))
             or (p.is_template and p.trainer_id = public.current_trainer_id()))
    )
  )
  with check (
    public.is_admin() or exists (
      select 1 from public.workout_programs p
      where p.id = program_id
        and ((p.client_id is not null and public.trainer_owns_client(p.client_id))
             or (p.is_template and p.trainer_id = public.current_trainer_id()))
    )
  );

create policy "workout_day_exercises: inherit day access"
  on public.workout_day_exercises for select to authenticated
  using (
    exists (
      select 1
      from public.workout_days d
      join public.workout_programs p on p.id = d.program_id
      where d.id = workout_day_id
        and ((p.client_id is not null and public.can_access_client(p.client_id))
             or (p.is_template and public.current_user_role() in ('trainer', 'admin')))
    )
  );

create policy "workout_day_exercises: trainer and admin write"
  on public.workout_day_exercises for all to authenticated
  using (
    public.is_admin() or exists (
      select 1
      from public.workout_days d
      join public.workout_programs p on p.id = d.program_id
      where d.id = workout_day_id
        and ((p.client_id is not null and public.trainer_owns_client(p.client_id))
             or (p.is_template and p.trainer_id = public.current_trainer_id()))
    )
  )
  with check (
    public.is_admin() or exists (
      select 1
      from public.workout_days d
      join public.workout_programs p on p.id = d.program_id
      where d.id = workout_day_id
        and ((p.client_id is not null and public.trainer_owns_client(p.client_id))
             or (p.is_template and p.trainer_id = public.current_trainer_id()))
    )
  );

-- ---------------------------------------------------------------------
-- exercise_logs — the client owns these; the trainer reads them
-- ---------------------------------------------------------------------
create policy "exercise_logs: read if permitted"
  on public.exercise_logs for select to authenticated
  using (public.can_access_client(client_id));

create policy "exercise_logs: client writes own"
  on public.exercise_logs for all to authenticated
  using (client_id = public.current_client_id())
  with check (client_id = public.current_client_id());

create policy "exercise_logs: trainer writes for assigned"
  on public.exercise_logs for all to authenticated
  using (public.trainer_owns_client(client_id))
  with check (public.trainer_owns_client(client_id));

create policy "exercise_logs: admin writes"
  on public.exercise_logs for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- ---------------------------------------------------------------------
-- meal_plans / nutrition_logs
-- ---------------------------------------------------------------------
create policy "meal_plans: read if permitted"
  on public.meal_plans for select to authenticated
  using (
    (client_id is not null and public.can_access_client(client_id))
    or (is_template and public.current_user_role() in ('trainer', 'admin'))
  );

create policy "meal_plans: trainer manages"
  on public.meal_plans for all to authenticated
  using (
    (client_id is not null and public.trainer_owns_client(client_id))
    or (is_template and trainer_id = public.current_trainer_id())
  )
  with check (
    (client_id is not null and public.trainer_owns_client(client_id))
    or (is_template and trainer_id = public.current_trainer_id())
  );

create policy "meal_plans: admin writes"
  on public.meal_plans for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

create policy "nutrition_logs: read if permitted"
  on public.nutrition_logs for select to authenticated
  using (public.can_access_client(client_id));

create policy "nutrition_logs: client writes own"
  on public.nutrition_logs for all to authenticated
  using (client_id = public.current_client_id())
  with check (client_id = public.current_client_id());

create policy "nutrition_logs: admin writes"
  on public.nutrition_logs for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- ---------------------------------------------------------------------
-- progress_records / progress_photos
-- ---------------------------------------------------------------------
create policy "progress_records: read if permitted"
  on public.progress_records for select to authenticated
  using (public.can_access_client(client_id));

create policy "progress_records: client writes own"
  on public.progress_records for all to authenticated
  using (client_id = public.current_client_id())
  with check (client_id = public.current_client_id());

create policy "progress_records: trainer writes for assigned"
  on public.progress_records for all to authenticated
  using (public.trainer_owns_client(client_id))
  with check (public.trainer_owns_client(client_id));

create policy "progress_records: admin writes"
  on public.progress_records for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- Photos are the most sensitive rows in the database. A client can mark a
-- photo client_only and it disappears from the trainer's view.
create policy "progress_photos: client reads own"
  on public.progress_photos for select to authenticated
  using (client_id = public.current_client_id());

create policy "progress_photos: trainer reads shared"
  on public.progress_photos for select to authenticated
  using (public.trainer_owns_client(client_id) and not client_only);

create policy "progress_photos: admin reads"
  on public.progress_photos for select to authenticated
  using (public.is_admin());

create policy "progress_photos: client writes own"
  on public.progress_photos for all to authenticated
  using (client_id = public.current_client_id())
  with check (client_id = public.current_client_id());

create policy "progress_photos: admin writes"
  on public.progress_photos for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- ---------------------------------------------------------------------
-- Storefront
-- ---------------------------------------------------------------------
create policy "online_programs: anyone reads published"
  on public.online_programs for select to anon, authenticated
  using (is_published or public.is_admin());

create policy "online_programs: admin writes"
  on public.online_programs for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

create policy "program_purchases: client reads own"
  on public.program_purchases for select to authenticated
  using (client_id = public.current_client_id());

create policy "program_purchases: admin reads"
  on public.program_purchases for select to authenticated
  using (public.is_admin());

-- Clients may update progress_pct as they work through a program.
create policy "program_purchases: client updates own progress"
  on public.program_purchases for update to authenticated
  using (client_id = public.current_client_id())
  with check (client_id = public.current_client_id());

create policy "program_purchases: admin writes"
  on public.program_purchases for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- ---------------------------------------------------------------------
-- Money — read-only for everyone except admin. Writes come from the
-- payment webhook running on the service_role key.
-- ---------------------------------------------------------------------
create policy "invoices: client reads own"
  on public.invoices for select to authenticated
  using (client_id = public.current_client_id());

create policy "invoices: admin reads"
  on public.invoices for select to authenticated
  using (public.is_admin());

create policy "invoices: admin writes"
  on public.invoices for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

create policy "payments: client reads own"
  on public.payments for select to authenticated
  using (client_id = public.current_client_id());

create policy "payments: admin reads"
  on public.payments for select to authenticated
  using (public.is_admin());

create policy "payments: admin writes"
  on public.payments for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

create policy "trainer_commissions: trainer reads own"
  on public.trainer_commissions for select to authenticated
  using (trainer_id = public.current_trainer_id());

create policy "trainer_commissions: admin reads"
  on public.trainer_commissions for select to authenticated
  using (public.is_admin());

create policy "trainer_commissions: admin writes"
  on public.trainer_commissions for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- ---------------------------------------------------------------------
-- applications — the public intake form writes here unauthenticated
-- ---------------------------------------------------------------------
create policy "applications: anyone submits"
  on public.applications for insert to anon, authenticated
  with check (status = 'new' and reviewed_by is null and reviewed_at is null);

create policy "applications: applicant reads own"
  on public.applications for select to authenticated
  using (profile_id = auth.uid());

create policy "applications: admin manages"
  on public.applications for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- ---------------------------------------------------------------------
-- notifications
-- ---------------------------------------------------------------------
create policy "notifications: read own"
  on public.notifications for select to authenticated
  using (recipient_profile_id = auth.uid());

-- Recipients may mark as read; they cannot create notifications for
-- themselves or anyone else. Creation is server-side only.
create policy "notifications: mark own as read"
  on public.notifications for update to authenticated
  using (recipient_profile_id = auth.uid())
  with check (recipient_profile_id = auth.uid());

create policy "notifications: admin manages"
  on public.notifications for all to authenticated
  using (public.is_admin()) with check (public.is_admin());
