# VFitness v2 — Data Import Specification

The format each entity must be exported to before it can be loaded. Nothing
is imported until the schema, policies, and interface are signed off.

## Rules that apply to every file

| Rule | Detail |
|---|---|
| Format | CSV, UTF-8, comma-delimited, quoted fields, `\n` line endings. Header row required, lowercase, exactly matching the column names below. |
| Encoding | Strip BOM. Firestore exports frequently carry one and it corrupts the first header. |
| Dates | `YYYY-MM-DD` |
| Timestamps | ISO 8601 with offset — `2026-08-08T14:30:00-04:00`. Firestore timestamps export as epoch millis; convert before loading. Nassau is UTC−4 (EDT) / UTC−5 (EST); do not assume UTC. |
| Nulls | Empty field, not the string `NULL`, not `None`, not `undefined`. |
| Booleans | `true` / `false` lowercase. |
| Money | Plain decimal, no currency symbol, no thousands separator. `1250.00` |
| Weight / length | Metric. Convert lb → kg (÷ 2.20462) and in → cm (× 2.54) **at export time**, not in the database. |
| `legacy_id` | **Required on every row.** The original Firestore document ID, verbatim. This is what makes the import idempotent and what resolves every foreign key. |
| Foreign keys | Supply the **parent's Firestore document ID**, not a UUID. The loader resolves it against `legacy_id`. Columns below marked *(legacy ref)* work this way. |
| Arrays | Pipe-delimited in one field: `Strength\|Mobility\|Nutrition` |
| JSON columns | Valid JSON in a single quoted CSV field, inner quotes escaped. |

## Import order

Foreign keys are enforced, so order is not optional:

```
1  profiles          6  packages            11  workout_day_exercises  16  progress_records
2  trainers          7  client_packages     12  exercise_logs          17  progress_photos
3  clients           8  appointments        13  meal_plans             18  invoices
4  (link trainers)   9  training_sessions   14  nutrition_logs         19  payments
5  exercises        10  workout_programs +  15  online_programs +      20  trainer_commissions
                        workout_days            program_purchases      21  applications, notifications
```

Step 4 is a separate pass: `clients.assigned_trainer_id` can only be set after
both `clients` and `trainers` exist. Export it in the clients file anyway — the
loader defers it.

---

## Auth: the part that is not a CSV

`profiles.id` must equal `auth.users.id`. You cannot create profiles first and
hope they match. Two options:

**A — Preserve passwords (preferred).** Firebase Auth exports hashes via
`firebase auth:export users.json --format=json`. Firebase uses scrypt with
project-specific parameters (`hash_config` in the export). Supabase's GoTrue
expects bcrypt and **will not accept Firebase scrypt hashes**. There is no
lossless path. Do not plan around one.

**B — Migrate identities, reset credentials (what you should actually do).**
Create each user through the Admin API with `email_confirm: true` and a random
password, carrying the Firebase UID in `user_metadata.legacy_id`. Then send a
password-reset email at cutover. Clients log in once with a new password and
everything else — sessions, packages, photos, invoices — is already there.

Export `users.csv`:

| column | required | notes |
|---|---|---|
| `legacy_id` | yes | Firebase Auth UID |
| `email` | yes | lowercase, deduplicated; duplicates abort the run |
| `full_name` | yes | fall back to the email local-part if blank |
| `role` | yes | `admin` \| `trainer` \| `client` |
| `phone` | no | E.164 preferred: `+12423571234` |
| `avatar_url` | no | absolute URL; re-hosted during storage migration |
| `date_of_birth` | no | |
| `gender` | no | |
| `status` | yes | `active` \| `inactive` \| `suspended` \| `pending` |
| `created_at` | yes | original signup timestamp — preserve it, tenure is visible in the UI |

> Check duplicate emails **before** exporting. Firestore allowed them; `profiles.email` is unique and citext, so `D@vfitbah.com` and `d@vfitbah.com` collide.

---

## Entity formats

Columns marked **R** are required. *(legacy ref)* = supply the parent's Firestore ID.

### trainers.csv
`legacy_id`**R**, `profile_id`**R** *(legacy ref → users)*, `bio`, `specialties` *(pipe)*, `certifications` *(pipe)*, `years_experience`, `gym_locations` *(pipe)*, `hourly_rate`, `commission_rate`**R** *(decimal 0–1, e.g. `0.60` not `60`)*, `accepting_clients`**R**, `status`**R**

### clients.csv
`legacy_id`**R**, `profile_id`**R** *(legacy ref → users)*, `assigned_trainer_id` *(legacy ref → trainers)*, `primary_goal`, `experience_level` *(`beginner`\|`intermediate`\|`advanced`)*, `height_cm`, `starting_weight_kg`, `target_weight_kg`, `medical_notes`, `emergency_contact_name`, `emergency_contact_phone`, `joined_at`**R**, `status`**R**

### packages.csv
`legacy_id`**R**, `name`**R**, `description`, `session_count`**R**, `price`**R**, `currency`**R** *(`BSD`)*, `validity_days`, `is_active`**R**, `display_order`

### client_packages.csv
`legacy_id`**R**, `client_id`**R** *(legacy ref)*, `package_id` *(legacy ref)*, `trainer_id` *(legacy ref)*, `name`**R**, `sessions_purchased`**R**, `sessions_used`**R**, `price_paid`**R**, `currency`**R**, `purchased_at`**R**, `starts_on`, `expires_on`, `status`**R** *(`pending`\|`active`\|`completed`\|`expired`\|`cancelled`)*, `notes`

> `sessions_used` must be ≤ `sessions_purchased` or the row is rejected by a check constraint. Reconcile against the session history first — this is the single most common source of import failures, because Firestore had no constraint holding the two in agreement.

### appointments.csv
`legacy_id`**R**, `client_id`**R** *(legacy ref)*, `trainer_id`**R** *(legacy ref)*, `starts_at`**R**, `ends_at`**R** *(must be > `starts_at`)*, `location`, `status`**R** *(`requested`\|`confirmed`\|`cancelled`\|`completed`)*, `notes`

### training_sessions.csv
`legacy_id`**R**, `client_id`**R** *(legacy ref)*, `trainer_id` *(legacy ref)*, `client_package_id` *(legacy ref)*, `appointment_id` *(legacy ref)*, `session_date`**R**, `duration_minutes`**R**, `status`**R** *(`scheduled`\|`completed`\|`no_show`\|`cancelled`)*, `deducts_from_package`**R**, `trainer_notes`, `client_feedback`, `client_rating` *(1–5)*, `completed_at`

> Load with the balance trigger disabled (`alter table public.training_sessions disable trigger sync_package_on_session_change;`), because `sessions_used` is being imported directly. Re-enable after, then run the reconciliation query in the checklist below.

### exercises.csv
`legacy_id`**R**, `name`**R**, `muscle_group`, `equipment`, `instructions`, `video_url`, `thumbnail_url`, `is_public`**R**, `created_by` *(legacy ref → users)*

### workout_programs.csv
`legacy_id`**R**, `name`**R**, `description`, `client_id` *(legacy ref; empty for templates)*, `trainer_id` *(legacy ref)*, `created_by` *(legacy ref → users)*, `goal`, `difficulty`, `duration_weeks`, `is_template`**R**, `status`**R** *(`draft`\|`assigned`\|`active`\|`completed`\|`archived`)*, `starts_on`

> A row with `is_template = true` **and** a `client_id` is rejected. Templates belong to nobody.

### workout_days.csv
`legacy_id`**R**, `program_id`**R** *(legacy ref)*, `week_number`**R**, `day_number`**R**, `name`**R**, `focus`, `is_rest_day`**R**, `notes` — unique on (`program_id`, `week_number`, `day_number`)

### workout_day_exercises.csv
`legacy_id`**R**, `workout_day_id`**R** *(legacy ref)*, `exercise_id`**R** *(legacy ref)*, `order_index`**R**, `target_sets`, `target_reps` *(text — `8-12` and `AMRAP` are both valid)*, `target_weight`, `rest_seconds`, `tempo`, `notes`

### exercise_logs.csv
`legacy_id`**R**, `client_id`**R** *(legacy ref)*, `exercise_id`**R** *(legacy ref)*, `workout_day_exercise_id` *(legacy ref)*, `training_session_id` *(legacy ref)*, `performed_on`**R**, `set_number`**R**, `reps`, `weight_kg`, `rpe` *(1–10)*, `duration_seconds`, `distance_m`, `notes`

> One row per set, not per exercise. If Firestore stored sets as a nested array, flatten at export — this is usually the largest file in the migration.

### meal_plans.csv
`legacy_id`**R**, `client_id` *(legacy ref; empty for templates)*, `trainer_id` *(legacy ref)*, `name`**R**, `description`, `daily_calories`, `protein_g`, `carbs_g`, `fat_g`, `meals` *(JSON)*, `is_template`**R**, `status`**R**, `starts_on`, `ends_on`

`meals` shape:
```json
[{"meal":"breakfast","time":"07:00","items":[
  {"food":"Oats","quantity":80,"unit":"g","calories":304,"protein_g":11,"carbs_g":54,"fat_g":5}
]}]
```

### nutrition_logs.csv
`legacy_id`**R**, `client_id`**R** *(legacy ref)*, `meal_plan_id` *(legacy ref)*, `logged_on`**R**, `meal`**R** *(`breakfast`\|`lunch`\|`dinner`\|`snack`\|`pre_workout`\|`post_workout`)*, `food_name`**R**, `quantity`, `unit`, `calories`, `protein_g`, `carbs_g`, `fat_g`, `notes`

### progress_records.csv
`legacy_id`**R**, `client_id`**R** *(legacy ref)*, `recorded_by` *(legacy ref → users)*, `recorded_on`**R**, `weight_kg`, `body_fat_pct`, `neck_cm`, `shoulders_cm`, `chest_cm`, `arm_cm`, `waist_cm`, `hips_cm`, `thigh_cm`, `calf_cm`, `resting_hr`, `notes`

> Unique on (`client_id`, `recorded_on`) — one measurement set per client per day. If Firestore has same-day duplicates, decide now whether to keep the latest or merge; the import will fail on the second row otherwise.

### progress_photos.csv
`legacy_id`**R**, `client_id`**R** *(legacy ref)*, `progress_record_id` *(legacy ref)*, `source_url`**R** *(current Firebase Storage download URL)*, `pose`**R** *(`front`\|`side_left`\|`side_right`\|`back`\|`other`)*, `taken_on`**R**, `client_only`**R**, `uploaded_by` *(legacy ref → users)*

> `source_url` is not a database column. The photo migration script downloads each file, uploads it to the private `progress-photos` bucket at `{client_id}/{legacy_id}.{ext}`, and writes that path into `storage_path`. Firebase download tokens expire — run this pass **before** decommissioning Firebase, and verify the count matches.

### online_programs.csv
`legacy_id`**R**, `title`**R**, `slug`**R** *(unique, lowercase, hyphenated)*, `summary`, `description`, `cover_image_url`, `preview_video_url`, `price`**R**, `currency`**R**, `duration_weeks`, `difficulty`, `workout_program_id` *(legacy ref)*, `meal_plan_id` *(legacy ref)*, `content` *(JSON)*, `is_published`**R**, `published_at`, `created_by` *(legacy ref → users)*

### program_purchases.csv
`legacy_id`**R**, `online_program_id`**R** *(legacy ref)*, `client_id`**R** *(legacy ref)*, `price_paid`**R**, `currency`**R**, `purchased_at`**R**, `access_expires_at`, `progress_pct`**R** *(0–100)*, `status`**R** *(`pending`\|`active`\|`refunded`\|`expired`)* — unique on (`online_program_id`, `client_id`)

### invoices.csv
`legacy_id`**R**, `invoice_number`**R** *(unique)*, `client_id`**R** *(legacy ref)*, `trainer_id` *(legacy ref)*, `client_package_id` *(legacy ref)*, `program_purchase_id` *(legacy ref)*, `issued_on`**R**, `due_on`, `subtotal`**R**, `tax`**R**, `discount`**R**, `total`**R**, `amount_paid`**R**, `currency`**R**, `status`**R**, `line_items` *(JSON)*, `notes`

`line_items` shape:
```json
[{"description":"10-Session Personal Training","quantity":1,"unit_price":850.00,"amount":850.00}]
```

> If Firestore has no invoice numbers, generate them at export as `VF-{YYYY}-{0001}` ordered by `issued_on`. Never let the database mint them retroactively — the sequence would not match anything a client already received.

### payments.csv
`legacy_id`**R**, `invoice_id` *(legacy ref)*, `client_id`**R** *(legacy ref)*, `amount`**R** *(> 0)*, `currency`**R**, `method`**R** *(`paypal`\|`card`\|`cash`\|`bank_transfer`\|`other`)*, `status`**R** *(`pending`\|`completed`\|`failed`\|`refunded`)*, `provider_txn_id` *(unique if present)*, `provider_subscription_id`, `paid_at`**R**, `raw_payload` *(JSON)*

> **Carry `provider_subscription_id` across for every active PayPal recurring plan.** Without it the new deployment receives subscription webhooks it cannot match to a client, and renewals silently stop being recorded. This is the one field where a gap causes revenue loss rather than a cosmetic defect.
>
> Load with the invoice-total trigger disabled, then recalculate once at the end.

### trainer_commissions.csv
`legacy_id`**R**, `trainer_id`**R** *(legacy ref)*, `source_type`**R** *(`session`\|`package`\|`online_program`\|`invoice`\|`manual`)*, `source_legacy_id` *(legacy ref, resolved per `source_type`)*, `gross_amount`**R**, `commission_rate`**R**, `commission_amount`**R**, `currency`**R**, `period_start`**R**, `period_end`**R** *(≥ `period_start`)*, `status`**R**, `paid_at`, `payment_reference`, `notes`

### applications.csv
`legacy_id`**R**, `kind`**R** *(`client`\|`trainer`)*, `full_name`**R**, `email`**R**, `phone`, `profile_id` *(legacy ref → users)*, `goals`, `experience`, `message`, `resume_url`, `preferred_location`, `status`**R**, `reviewed_by` *(legacy ref → users)*, `reviewed_at`, `review_notes`, `created_at`**R**

### notifications.csv
`legacy_id`**R**, `recipient_profile_id`**R** *(legacy ref → users)*, `type`**R**, `title`**R**, `body`, `link_url`, `metadata` *(JSON)*, `read_at`, `created_at`**R**

> Consider not migrating these at all. Notifications older than ~30 days are noise, and their `link_url` values point at old routes that will 404 on the new site. Filter to unread-and-recent, or skip the file.

---

## Loading

Every load runs on the **`service_role`** key, which bypasses RLS. The
anon/authenticated keys cannot write most of these tables by design.

Idempotent pattern, so a failed run can be re-run without duplicating:

```sql
insert into public.clients (legacy_id, profile_id, primary_goal, joined_at, status)
select
  s.legacy_id,
  p.id,
  s.primary_goal,
  s.joined_at::date,
  s.status::account_status
from staging_clients s
join public.profiles p on p.legacy_id = s.profile_legacy_id
on conflict (legacy_id) do update
  set primary_goal = excluded.primary_goal,
      status       = excluded.status;
```

Stage each CSV into a `staging_*` table of all-text columns first, cast on the
way into the real table. Casting inside `COPY` gives you an error on line 4,712
with no indication of which value was bad.

## Post-import checklist

```sql
-- 1. Every client_package balance agrees with its session history
select cp.id, cp.legacy_id, cp.sessions_used, count(ts.id) as completed
from public.client_packages cp
left join public.training_sessions ts
  on ts.client_package_id = cp.id
 and ts.status = 'completed'
 and ts.deducts_from_package
group by cp.id
having cp.sessions_used <> count(ts.id);

-- 2. Invoice amount_paid agrees with completed payments
select i.id, i.invoice_number, i.amount_paid, coalesce(sum(p.amount), 0) as actual
from public.invoices i
left join public.payments p on p.invoice_id = i.id and p.status = 'completed'
group by i.id
having i.amount_paid <> coalesce(sum(p.amount), 0);

-- 3. No orphaned clients
select count(*) from public.clients c
left join public.profiles p on p.id = c.profile_id where p.id is null;

-- 4. Photo count matches the export manifest
select count(*) from public.progress_photos;

-- 5. Every active PayPal subscription carried across
select count(distinct provider_subscription_id) from public.payments
where provider_subscription_id is not null;
```

Then re-enable the disabled triggers and spot-check three real client accounts
end to end — log in as each, confirm sessions, package balance, photos,
invoices, and next appointment all render correctly — before pointing DNS.
