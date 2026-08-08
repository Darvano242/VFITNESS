-- =====================================================================
-- VFitness v2 — 05. Catalogue seed
--
-- The real VFitness packages and online programs. This is reference data,
-- not migrated data, so it is seeded rather than imported. Prices here are
-- what the storefront charges, so they must match docs/BRAND.md exactly.
--
-- Idempotent: re-running updates prices rather than duplicating rows.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Session packages
--
-- validity_days is set to 90 for every block. Confirm against actual
-- policy before launch; a wrong expiry silently voids client sessions.
-- ---------------------------------------------------------------------
insert into public.packages
  (legacy_id, name, description, session_count, price, currency, validity_days, is_active, display_order)
values
  ('pkg-1on1-1',  '1-on-1 Single Session', 'One 60 minute personal training session.',            1,   30.00, 'BSD',  30, true, 10),
  ('pkg-1on1-4',  '1-on-1 4 Sessions',     'The trial block. Enough to feel the difference.',      4,  120.00, 'BSD',  90, true, 11),
  ('pkg-1on1-6',  '1-on-1 6 Sessions',     'Six personal training sessions.',                      6,  180.00, 'BSD',  90, true, 12),
  ('pkg-1on1-8',  '1-on-1 8 Sessions',     'The workhorse block. Roughly a month of training.',    8,  221.00, 'BSD',  90, true, 13),
  ('pkg-1on1-12', '1-on-1 12 Sessions',    'The commitment tier. Best per session rate.',         12,  294.00, 'BSD', 120, true, 14),

  ('pkg-semi-1',  'Semi-Personal Single', 'One 60 minute semi-personal session, 2 to 4 people.',  1,   22.00, 'BSD',  30, true, 20),
  ('pkg-semi-4',  'Semi-Personal 4',       'Four semi-personal sessions.',                          4,   87.00, 'BSD',  90, true, 21),
  ('pkg-semi-6',  'Semi-Personal 6',       'Six semi-personal sessions.',                          6,  130.00, 'BSD',  90, true, 22),
  ('pkg-semi-8',  'Semi-Personal 8',       'Eight semi-personal sessions.',                        8,  173.00, 'BSD',  90, true, 23),
  ('pkg-semi-12', 'Semi-Personal 12',      'Twelve semi-personal sessions. Best value per head.', 12,  195.00, 'BSD', 120, true, 24),

  ('pkg-remote',  'Remote Coaching',       'Monthly remote coaching, programming and check-ins.',  4,   60.00, 'BSD',  30, true, 30)
on conflict (legacy_id) do update
  set name          = excluded.name,
      description   = excluded.description,
      session_count = excluded.session_count,
      price         = excluded.price,
      validity_days = excluded.validity_days,
      is_active     = excluded.is_active,
      display_order = excluded.display_order;

-- ---------------------------------------------------------------------
-- Online programs (storefront)
--
-- cover_image_url is left null on purpose. Point these at the real cover
-- art during the storage migration rather than seeding placeholder paths
-- that would ship to the storefront if the asset pass slipped.
-- ---------------------------------------------------------------------
insert into public.online_programs
  (legacy_id, title, slug, summary, description, price, currency, duration_weeks, difficulty, is_published, published_at)
values
  ('home-30day',
   'HOME 30', 'home-30',
   '30-Day Get In Shape Plan',
   'Transform at home in 30 days. No gym needed, bodyweight and minimal equipment. Built for busy people. Five workouts a week, video demos for every exercise, and a 30 day meal plan included.',
   25.00, 'BSD', 4, 'beginner', true, now()),

  ('flex-master-4week',
   'FLEX MASTER', 'flex-master',
   'Mobility and Flexibility',
   'Improve mobility, flexibility and movement quality. Feel younger, move better and eliminate pain. Three sessions a week with recovery focused nutrition.',
   15.00, 'BSD', 4, 'beginner', true, now()),

  ('hourglass-8week',
   'HOURGLASS', 'hourglass',
   'Ladies Weight Loss Program',
   'Sculpt curves and burn fat over eight weeks. Five workouts a week with targeted waist and glute training.',
   35.00, 'BSD', 8, 'intermediate', true, now()),

  ('shredded-six-8week',
   'SHREDDED SIX', 'shredded-six',
   'Men''s 6-Pack Abs Program',
   'Core focused ab training with fat burning HIIT and a shredding meal plan. Six workouts a week for eight weeks.',
   30.00, 'BSD', 8, 'intermediate', true, now()),

  ('booty-camp-8week',
   'BOOTY CAMP', 'booty-camp',
   'Glute Building Program',
   'Science based glute transformation built on progressive overload. Four workouts a week for eight weeks. The most popular program on the platform.',
   30.00, 'BSD', 8, 'intermediate', true, now()),

  ('mass-monster-8week',
   'MASS MONSTER', 'mass-monster',
   'Muscle Building Program',
   'Four brutal workouts a week designed for maximum muscle growth, paired with a high protein 2800 calorie meal plan.',
   35.00, 'BSD', 8, 'advanced', true, now()),

  ('iron-beast-8week',
   'IRON BEAST', 'iron-beast',
   'Powerlifting Strength Program',
   'Eight weeks focused on the squat, bench and deadlift, with a mass building 3200 calorie meal plan. Four sessions a week.',
   35.00, 'BSD', 8, 'advanced', true, now())
on conflict (legacy_id) do update
  set title          = excluded.title,
      slug           = excluded.slug,
      summary        = excluded.summary,
      description    = excluded.description,
      price          = excluded.price,
      duration_weeks = excluded.duration_weeks,
      difficulty     = excluded.difficulty,
      is_published   = excluded.is_published;

-- ---------------------------------------------------------------------
-- Membership tiers
--
-- Recurring continuity, distinct from session blocks. Modelled as
-- packages with session_count 0 would violate the check constraint, so
-- these get their own table rather than being forced into the package
-- catalogue.
-- ---------------------------------------------------------------------
create table if not exists public.membership_tiers (
  id            uuid primary key default gen_random_uuid(),
  legacy_id     text unique,
  name          text          not null,
  slug          text          not null unique,
  monthly_price numeric(10,2) not null check (monthly_price >= 0),
  currency      char(3)       not null default 'BSD',
  blurb         text,
  perks         text[]        not null default '{}',
  paypal_plan_id text,
  is_active     boolean       not null default true,
  display_order int           not null default 0,
  created_at    timestamptz   not null default now(),
  updated_at    timestamptz   not null default now()
);

alter table public.membership_tiers enable row level security;

create policy "membership_tiers: anyone reads active"
  on public.membership_tiers for select to anon, authenticated
  using (is_active or public.is_admin());

create policy "membership_tiers: admin writes"
  on public.membership_tiers for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

insert into public.membership_tiers
  (legacy_id, name, slug, monthly_price, blurb, display_order)
values
  ('tier-self-led', 'Self-Led', 'self-led', 19.00,
   'Programming and tracking on your own schedule.', 1),
  ('tier-coached',  'Coached',  'coached',  59.00,
   'Programming plus coach check-ins and plan adjustments.', 2),
  ('tier-elite',    'Elite',    'elite',    99.00,
   'Everything in Coached plus priority access and direct messaging.', 3)
on conflict (legacy_id) do update
  set name          = excluded.name,
      monthly_price = excluded.monthly_price,
      blurb         = excluded.blurb;

-- paypal_plan_id stays null until the three PayPal plan IDs are created.
-- Recurring billing will not activate without them.
