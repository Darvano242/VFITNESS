# VFitness v2 — Brand and Business Constants

Single source of truth. Nothing in this file gets invented, substituted, or
"improved" in a redesign. If a build contradicts this file, the build is wrong.

## Design tokens

```
--vf-bg          #08090a    page base
--vf-bg2         #0c0e10    raised base
--vf-surface     rgba(255,255,255,0.035)
--vf-surface-hi  rgba(255,255,255,0.06)
--vf-border      rgba(255,255,255,0.08)
--vf-border-hi   rgba(255,255,255,0.14)
--vf-text        #f5f6f7
--vf-dim         #9aa0a6
--vf-mute        #6b7177
--vf-primary     #3d7dff    electric azure
--vf-primary-2   #6f5bff    violet
--vf-accent      #2dd4bf    teal
--vf-green       #22c55e
--vf-gold        #f59e0b
--vf-red         #f43f5e
```

Signature gradient: `linear-gradient(120deg, #3d7dff, #6f5bff)`
Teal gradient: `linear-gradient(120deg, #2dd4bf, #3d7dff)`

**Type:** Geist (display and body), Geist Mono (data, labels, figures).
**Mark:** zap bolt.
**Tagline:** Built for training, tracking, and real results.
**Aesthetic:** dark glass, gradient hairlines, aurora backdrop.

## Copy rules

1. **No em dashes or en dashes anywhere in user-facing copy.** Use commas,
   periods, or restructure the sentence. This has broken builds before.
2. Exercise name fields keep their hyphens. Firestore `customWeights` keys
   depend on them, and the migration carries those keys across.
3. Gym membership question, approved wording, do not paraphrase:
   > Yes, a gym membership is not included in VFITNESS packages. Your package
   > covers your coaching only, and we will walk you through training location
   > options at your consultation.

## Team

| Name | Role |
|---|---|
| Darvano Andrews | Founder. Body recomposition and glute specialist |
| Lanardo Mackey | Trainer |
| Chavese Moss | Trainer |
| Kevin Mackey | Trainer |

## Training locations

Empire Fitness · Fanta C Fitness · Royal Bahamas Police College

Gym membership is not included in any package.

## Session packages

**1-on-1**

| Sessions | Price | Per session |
|---|---|---|
| 1 | $30 | $30.00 |
| 4 | $120 | $30.00 |
| 6 | $180 | $30.00 |
| 8 | $221 | $27.63 |
| 12 | $294 | $24.50 |

**Semi-Personal**

| Sessions | Price | Per session |
|---|---|---|
| 1 | $22 | $22.00 |
| 4 | $87 | $21.75 |
| 6 | $130 | $21.67 |
| 8 | $173 | $21.63 |
| 12 | $195 | $16.25 |

**Remote:** $60 per month.

## Online programs

| Program | Price | Duration | Focus |
|---|---|---|---|
| HOME 30 | $25 | 30 days | 30-day get in shape, no gym needed |
| FLEX MASTER | $15 | 4 weeks | Mobility and flexibility |
| HOURGLASS | $35 | 8 weeks | Ladies weight loss |
| SHREDDED SIX | $30 | 8 weeks | Men's 6-pack abs |
| BOOTY CAMP | $30 | 8 weeks | Glute building. Most popular |
| MASS MONSTER | $35 | 8 weeks | Muscle building |
| IRON BEAST | $35 | 8 weeks | Powerlifting strength |

> **Unresolved:** an older admin assign-modal listed FLEX MASTER at $25 and
> HOME 30 at $20, which contradicts the table above. The table follows the
> most recent build. Confirm before this seeds production, because
> `online_programs.price` is what the storefront charges.

## Membership tiers

| Tier | Monthly |
|---|---|
| Self-Led | $19 |
| Coached | $59 |
| Elite | $99 |

HOME 30 doubles as the $25 attraction offer that graduates buyers into Coached.

## Commission

Trainer commission is settled in person and never appears in the app. No
trainer-facing screen shows earnings, payout, gross billed, or a rate. The
`trainer_commissions` table and `trainers.commission_rate` exist for admin
bookkeeping only, and are unreadable from any non-admin session. See
migration `20260808000600_commission_off_app.sql`.

Read trainer details from the `trainer_directory` view, never from
`public.trainers`, which no longer grants select on the rate columns.

## Contact

WhatsApp: `https://wa.me/12424549063`
