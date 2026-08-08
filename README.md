# VFitness v2

Rebuild of vfitbah.com on Next.js and Supabase, replacing the single-file
React PWA on Firebase and Netlify.

## Read these first

- `docs/BRAND.md` — locked design tokens, team, locations, every price, and the
  copy rules. If a build contradicts this file, the build is wrong.
- `docs/IMPORT_SPEC.md` — the exact export format for every entity, the import
  order, and the auth migration path.

## Setup

```bash
npm install
cp .env.example .env.local     # fill in the keys
npm run dev
```

Apply the migrations in order:

```bash
supabase link --project-ref hxpsbhhkemccmmrukhji
supabase db push
npm run db:types               # regenerate src/lib/database.types.ts
```

## How security works here

Three layers, in this order:

1. **RLS** is the real boundary. Every table has it enabled. A trainer reaches
   only clients where `clients.assigned_trainer_id` matches their own trainer
   row, routed through the single `trainer_owns_client()` function.
2. **Triggers** cover what RLS cannot express, which is comparing a value
   against its previous value. They block role self-escalation, client
   reassignment by a trainer, and commission-rate edits.
3. **Route guards** (`requireRole`) stop the wrong shell rendering. They are
   convenience, not protection. Never rely on them alone.

The `service_role` key bypasses all of it. It belongs in the PayPal webhook and
the import scripts only. Reaching for it to fix an RLS error almost always
means the policy is wrong.

## Commission

Settled in person. It is not displayed, calculated, or reachable anywhere in
the app for any role. `trainers.commission_rate` has column-level select
revoked. Read trainer details from the `trainer_directory` view, never from
`public.trainers`.

## Routes

| Path | Role |
|---|---|
| `/login` | public |
| `/dashboard` | client |
| `/coach` | trainer, admin |
| `/admin` | admin |

## Status

Done: schema (24 tables), RLS, triggers, catalogue seed, auth and role
routing, app shell, three dashboard pages wired to real queries.

Not done: public storefront, Start Here intake, workout tracker, nutrition
logging, progress photo upload, PayPal one-time and recurring checkout, the
data import scripts themselves.

## Open decisions

1. FLEX MASTER and HOME 30 prices conflict between two earlier builds. The
   seed uses $15 and $25. Confirm before this reaches production.
2. Package expiry is seeded at 90 days, 120 for twelve-blocks. These were
   assumed. A wrong value silently voids sessions clients already paid for.
3. Whether commission should be tracked for admin at all, or dropped entirely.
