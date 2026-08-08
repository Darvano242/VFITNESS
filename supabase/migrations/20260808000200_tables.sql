-- =====================================================================
-- VFitness v2 — 02. Tables
--
-- Every table that receives migrated Firebase data carries `legacy_id`,
-- the original Firestore document ID, with a unique index. This makes the
-- import idempotent (re-runnable via ON CONFLICT) and lets foreign keys be
-- resolved from Firestore references without a lookup spreadsheet.
-- Drop the legacy_id columns once the migration is signed off.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Identity
-- ---------------------------------------------------------------------
create table public.profiles (
  id            uuid primary key references auth.users(id) on delete cascade,
  role          user_role      not null default 'client',
  full_name     text           not null,
  email         citext         not null unique,
  phone         text,
  avatar_url    text,
  date_of_birth date,
  gender        text,
  timezone      text           not null default 'America/Nassau',
  status        account_status not null default 'active',
  legacy_id     text unique,
  created_at    timestamptz    not null default now(),
  updated_at    timestamptz    not null default now()
);

create table public.trainers (
  id                uuid primary key default gen_random_uuid(),
  profile_id        uuid           not null unique references public.profiles(id) on delete cascade,
  bio               text,
  specialties       text[]         not null default '{}',
  certifications    text[]         not null default '{}',
  years_experience  int,
  gym_locations     text[]         not null default '{}',
  hourly_rate       numeric(10,2),
  commission_rate   numeric(5,4)   not null default 0.6000
                      check (commission_rate >= 0 and commission_rate <= 1),
  accepting_clients boolean        not null default true,
  status            account_status not null default 'active',
  legacy_id         text unique,
  created_at        timestamptz    not null default now(),
  updated_at        timestamptz    not null default now()
);

create table public.clients (
  id                      uuid primary key default gen_random_uuid(),
  profile_id              uuid           not null unique references public.profiles(id) on delete cascade,
  assigned_trainer_id     uuid           references public.trainers(id) on delete set null,
  primary_goal            text,
  experience_level        difficulty_level,
  height_cm               numeric(5,1),
  starting_weight_kg      numeric(5,1),
  target_weight_kg        numeric(5,1),
  medical_notes           text,
  emergency_contact_name  text,
  emergency_contact_phone text,
  joined_at               date           not null default current_date,
  status                  account_status not null default 'active',
  legacy_id               text unique,
  created_at              timestamptz    not null default now(),
  updated_at              timestamptz    not null default now()
);

create index on public.clients (assigned_trainer_id);
create index on public.clients (status);

-- ---------------------------------------------------------------------
-- Packages & sessions
--
-- `packages` is the sellable catalogue; `client_packages` is a purchased
-- instance. This split was not in the brief but is required — without it
-- every price change rewrites the history of what clients already bought.
-- ---------------------------------------------------------------------
create table public.packages (
  id                 uuid primary key default gen_random_uuid(),
  name               text        not null,
  description        text,
  session_count      int         not null check (session_count > 0),
  price              numeric(10,2) not null check (price >= 0),
  currency           char(3)     not null default 'BSD',
  validity_days      int,
  is_active          boolean     not null default true,
  display_order      int         not null default 0,
  legacy_id          text unique,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now()
);

create table public.client_packages (
  id                 uuid primary key default gen_random_uuid(),
  client_id          uuid           not null references public.clients(id) on delete cascade,
  package_id         uuid           references public.packages(id) on delete set null,
  trainer_id         uuid           references public.trainers(id) on delete set null,
  name               text           not null,
  sessions_purchased int            not null check (sessions_purchased >= 0),
  sessions_used      int            not null default 0 check (sessions_used >= 0),
  sessions_remaining int generated always as (sessions_purchased - sessions_used) stored,
  price_paid         numeric(10,2)  not null default 0,
  currency           char(3)        not null default 'BSD',
  purchased_at       timestamptz    not null default now(),
  starts_on          date,
  expires_on         date,
  status             package_status not null default 'active',
  notes              text,
  legacy_id          text unique,
  created_at         timestamptz    not null default now(),
  updated_at         timestamptz    not null default now(),
  constraint sessions_used_within_purchased check (sessions_used <= sessions_purchased)
);

create index on public.client_packages (client_id, status);
create index on public.client_packages (trainer_id);

create table public.appointments (
  id           uuid primary key default gen_random_uuid(),
  client_id    uuid               not null references public.clients(id) on delete cascade,
  trainer_id   uuid               not null references public.trainers(id) on delete cascade,
  starts_at    timestamptz        not null,
  ends_at      timestamptz        not null,
  location     text,
  status       appointment_status not null default 'confirmed',
  notes        text,
  legacy_id    text unique,
  created_at   timestamptz        not null default now(),
  updated_at   timestamptz        not null default now(),
  constraint appointment_ends_after_start check (ends_at > starts_at)
);

create index on public.appointments (client_id, starts_at desc);
create index on public.appointments (trainer_id, starts_at desc);

create table public.training_sessions (
  id                    uuid primary key default gen_random_uuid(),
  client_id             uuid           not null references public.clients(id) on delete cascade,
  trainer_id            uuid           references public.trainers(id) on delete set null,
  client_package_id     uuid           references public.client_packages(id) on delete set null,
  appointment_id        uuid           references public.appointments(id) on delete set null,
  session_date          date           not null,
  duration_minutes      int            not null default 60,
  status                session_status not null default 'scheduled',
  deducts_from_package  boolean        not null default true,
  trainer_notes         text,
  client_feedback       text,
  client_rating         int check (client_rating between 1 and 5),
  completed_at          timestamptz,
  legacy_id             text unique,
  created_at            timestamptz    not null default now(),
  updated_at            timestamptz    not null default now()
);

create index on public.training_sessions (client_id, session_date desc);
create index on public.training_sessions (trainer_id, session_date desc);
create index on public.training_sessions (client_package_id);

-- ---------------------------------------------------------------------
-- Training content
-- ---------------------------------------------------------------------
create table public.exercises (
  id             uuid primary key default gen_random_uuid(),
  name           text        not null,
  muscle_group   text,
  equipment      text,
  instructions   text,
  video_url      text,
  thumbnail_url  text,
  is_public      boolean     not null default true,
  created_by     uuid        references public.profiles(id) on delete set null,
  legacy_id      text unique,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

create index on public.exercises (muscle_group);

create table public.workout_programs (
  id             uuid primary key default gen_random_uuid(),
  name           text           not null,
  description    text,
  client_id      uuid           references public.clients(id) on delete cascade,
  trainer_id     uuid           references public.trainers(id) on delete set null,
  created_by     uuid           references public.profiles(id) on delete set null,
  goal           text,
  difficulty     difficulty_level,
  duration_weeks int,
  is_template    boolean        not null default false,
  status         program_status not null default 'draft',
  starts_on      date,
  legacy_id      text unique,
  created_at     timestamptz    not null default now(),
  updated_at     timestamptz    not null default now(),
  -- A template belongs to nobody; an assigned program must have an owner.
  constraint template_has_no_client check (not (is_template and client_id is not null))
);

create index on public.workout_programs (client_id, status);
create index on public.workout_programs (is_template) where is_template;

create table public.workout_days (
  id          uuid primary key default gen_random_uuid(),
  program_id  uuid        not null references public.workout_programs(id) on delete cascade,
  week_number int         not null default 1,
  day_number  int         not null,
  name        text        not null,
  focus       text,
  is_rest_day boolean     not null default false,
  notes       text,
  legacy_id   text unique,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique (program_id, week_number, day_number)
);

-- Junction: which exercises, in what order, with what targets.
-- Not in the brief's entity list but unavoidable — WorkoutDays and
-- Exercises are many-to-many and the prescription lives on the link.
create table public.workout_day_exercises (
  id             uuid primary key default gen_random_uuid(),
  workout_day_id uuid        not null references public.workout_days(id) on delete cascade,
  exercise_id    uuid        not null references public.exercises(id) on delete restrict,
  order_index    int         not null default 0,
  target_sets    int,
  target_reps    text,
  target_weight  numeric(6,2),
  rest_seconds   int,
  tempo          text,
  notes          text,
  legacy_id      text unique,
  created_at     timestamptz not null default now()
);

create index on public.workout_day_exercises (workout_day_id, order_index);

create table public.exercise_logs (
  id                       uuid primary key default gen_random_uuid(),
  client_id                uuid        not null references public.clients(id) on delete cascade,
  exercise_id              uuid        not null references public.exercises(id) on delete restrict,
  workout_day_exercise_id  uuid        references public.workout_day_exercises(id) on delete set null,
  training_session_id      uuid        references public.training_sessions(id) on delete set null,
  performed_on             date        not null default current_date,
  set_number               int         not null default 1,
  reps                     int,
  weight_kg                numeric(6,2),
  rpe                      numeric(3,1) check (rpe between 1 and 10),
  duration_seconds         int,
  distance_m               numeric(8,2),
  notes                    text,
  legacy_id                text unique,
  created_at               timestamptz not null default now()
);

create index on public.exercise_logs (client_id, performed_on desc);
create index on public.exercise_logs (client_id, exercise_id, performed_on desc);

-- ---------------------------------------------------------------------
-- Nutrition
-- ---------------------------------------------------------------------
create table public.meal_plans (
  id             uuid primary key default gen_random_uuid(),
  client_id      uuid           references public.clients(id) on delete cascade,
  trainer_id     uuid           references public.trainers(id) on delete set null,
  name           text           not null,
  description    text,
  daily_calories int,
  protein_g      int,
  carbs_g        int,
  fat_g          int,
  -- Meal structure is intentionally jsonb: plans are authored and revised
  -- as a whole document, never queried meal-by-meal.
  meals          jsonb          not null default '[]'::jsonb,
  is_template    boolean        not null default false,
  status         program_status not null default 'draft',
  starts_on      date,
  ends_on        date,
  legacy_id      text unique,
  created_at     timestamptz    not null default now(),
  updated_at     timestamptz    not null default now(),
  constraint meal_template_has_no_client check (not (is_template and client_id is not null))
);

create index on public.meal_plans (client_id, status);

create table public.nutrition_logs (
  id           uuid primary key default gen_random_uuid(),
  client_id    uuid        not null references public.clients(id) on delete cascade,
  meal_plan_id uuid        references public.meal_plans(id) on delete set null,
  logged_on    date        not null default current_date,
  meal         meal_type   not null,
  food_name    text        not null,
  quantity     numeric(8,2),
  unit         text,
  calories     numeric(8,2),
  protein_g    numeric(6,2),
  carbs_g      numeric(6,2),
  fat_g        numeric(6,2),
  notes        text,
  legacy_id    text unique,
  created_at   timestamptz not null default now()
);

create index on public.nutrition_logs (client_id, logged_on desc);

-- ---------------------------------------------------------------------
-- Progress
-- ---------------------------------------------------------------------
create table public.progress_records (
  id            uuid primary key default gen_random_uuid(),
  client_id     uuid        not null references public.clients(id) on delete cascade,
  recorded_by   uuid        references public.profiles(id) on delete set null,
  recorded_on   date        not null default current_date,
  weight_kg     numeric(5,1),
  body_fat_pct  numeric(4,1),
  neck_cm       numeric(5,1),
  shoulders_cm  numeric(5,1),
  chest_cm      numeric(5,1),
  arm_cm        numeric(5,1),
  waist_cm      numeric(5,1),
  hips_cm       numeric(5,1),
  thigh_cm      numeric(5,1),
  calf_cm       numeric(5,1),
  resting_hr    int,
  notes         text,
  legacy_id     text unique,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  unique (client_id, recorded_on)
);

create index on public.progress_records (client_id, recorded_on desc);

create table public.progress_photos (
  id                  uuid primary key default gen_random_uuid(),
  client_id           uuid        not null references public.clients(id) on delete cascade,
  progress_record_id  uuid        references public.progress_records(id) on delete set null,
  storage_path        text        not null,
  pose                photo_pose  not null default 'front',
  taken_on            date        not null default current_date,
  -- When true the assigned trainer cannot view it; admin and the client can.
  client_only         boolean     not null default false,
  uploaded_by         uuid        references public.profiles(id) on delete set null,
  legacy_id           text unique,
  created_at          timestamptz not null default now()
);

create index on public.progress_photos (client_id, taken_on desc);

-- ---------------------------------------------------------------------
-- Storefront
-- ---------------------------------------------------------------------
create table public.online_programs (
  id                uuid primary key default gen_random_uuid(),
  title             text          not null,
  slug              text          not null unique,
  summary           text,
  description       text,
  cover_image_url   text,
  preview_video_url text,
  price             numeric(10,2) not null check (price >= 0),
  currency          char(3)       not null default 'BSD',
  duration_weeks    int,
  difficulty        difficulty_level,
  workout_program_id uuid         references public.workout_programs(id) on delete set null,
  meal_plan_id      uuid          references public.meal_plans(id) on delete set null,
  content           jsonb         not null default '{}'::jsonb,
  is_published      boolean       not null default false,
  published_at      timestamptz,
  created_by        uuid          references public.profiles(id) on delete set null,
  legacy_id         text unique,
  created_at        timestamptz   not null default now(),
  updated_at        timestamptz   not null default now()
);

create index on public.online_programs (is_published, published_at desc);

create table public.program_purchases (
  id                 uuid primary key default gen_random_uuid(),
  online_program_id  uuid            not null references public.online_programs(id) on delete restrict,
  client_id          uuid            not null references public.clients(id) on delete cascade,
  price_paid         numeric(10,2)   not null,
  currency           char(3)         not null default 'BSD',
  purchased_at       timestamptz     not null default now(),
  access_expires_at  timestamptz,
  progress_pct       numeric(5,2)    not null default 0 check (progress_pct between 0 and 100),
  status             purchase_status not null default 'active',
  legacy_id          text unique,
  created_at         timestamptz     not null default now(),
  updated_at         timestamptz     not null default now(),
  unique (online_program_id, client_id)
);

create index on public.program_purchases (client_id, purchased_at desc);

-- ---------------------------------------------------------------------
-- Money
-- ---------------------------------------------------------------------
create table public.invoices (
  id                 uuid primary key default gen_random_uuid(),
  invoice_number     text           not null unique,
  client_id          uuid           not null references public.clients(id) on delete restrict,
  trainer_id         uuid           references public.trainers(id) on delete set null,
  client_package_id  uuid           references public.client_packages(id) on delete set null,
  program_purchase_id uuid          references public.program_purchases(id) on delete set null,
  issued_on          date           not null default current_date,
  due_on             date,
  subtotal           numeric(10,2)  not null default 0,
  tax                numeric(10,2)  not null default 0,
  discount           numeric(10,2)  not null default 0,
  total              numeric(10,2)  not null default 0,
  amount_paid        numeric(10,2)  not null default 0,
  currency           char(3)        not null default 'BSD',
  status             invoice_status not null default 'draft',
  line_items         jsonb          not null default '[]'::jsonb,
  notes              text,
  legacy_id          text unique,
  created_at         timestamptz    not null default now(),
  updated_at         timestamptz    not null default now()
);

create index on public.invoices (client_id, issued_on desc);
create index on public.invoices (status) where status in ('sent', 'partial', 'overdue');

create table public.payments (
  id                       uuid primary key default gen_random_uuid(),
  invoice_id               uuid           references public.invoices(id) on delete set null,
  client_id                uuid           not null references public.clients(id) on delete restrict,
  amount                   numeric(10,2)  not null check (amount > 0),
  currency                 char(3)        not null default 'BSD',
  method                   payment_method not null default 'paypal',
  status                   payment_status not null default 'completed',
  provider_txn_id          text unique,
  provider_subscription_id text,
  paid_at                  timestamptz    not null default now(),
  raw_payload              jsonb,
  legacy_id                text unique,
  created_at               timestamptz    not null default now()
);

create index on public.payments (client_id, paid_at desc);
create index on public.payments (invoice_id);
create index on public.payments (provider_subscription_id);

create table public.trainer_commissions (
  id                uuid primary key default gen_random_uuid(),
  trainer_id        uuid              not null references public.trainers(id) on delete cascade,
  source_type       commission_source not null,
  source_id         uuid,
  gross_amount      numeric(10,2)     not null,
  commission_rate   numeric(5,4)      not null,
  commission_amount numeric(10,2)     not null,
  currency          char(3)           not null default 'BSD',
  period_start      date              not null,
  period_end        date              not null,
  status            commission_status not null default 'pending',
  paid_at           timestamptz,
  payment_reference text,
  notes             text,
  legacy_id         text unique,
  created_at        timestamptz       not null default now(),
  updated_at        timestamptz       not null default now(),
  constraint commission_period_valid check (period_end >= period_start)
);

create index on public.trainer_commissions (trainer_id, period_start desc);
create index on public.trainer_commissions (status);

-- ---------------------------------------------------------------------
-- Intake & messaging
-- ---------------------------------------------------------------------
create table public.applications (
  id             uuid primary key default gen_random_uuid(),
  kind           application_kind   not null default 'client',
  full_name      text               not null,
  email          citext             not null,
  phone          text,
  profile_id     uuid               references public.profiles(id) on delete set null,
  goals          text,
  experience     text,
  message        text,
  resume_url     text,
  preferred_location text,
  status         application_status not null default 'new',
  reviewed_by    uuid               references public.profiles(id) on delete set null,
  reviewed_at    timestamptz,
  review_notes   text,
  legacy_id      text unique,
  created_at     timestamptz        not null default now(),
  updated_at     timestamptz        not null default now()
);

create index on public.applications (status, created_at desc);

create table public.notifications (
  id                   uuid primary key default gen_random_uuid(),
  recipient_profile_id uuid        not null references public.profiles(id) on delete cascade,
  type                 text        not null,
  title                text        not null,
  body                 text,
  link_url             text,
  metadata             jsonb       not null default '{}'::jsonb,
  read_at              timestamptz,
  legacy_id            text unique,
  created_at           timestamptz not null default now()
);

create index on public.notifications (recipient_profile_id, created_at desc);
create index on public.notifications (recipient_profile_id) where read_at is null;
