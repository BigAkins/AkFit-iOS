# AkFit — Supabase

## Overview

The `supabase/` directory is the source of truth for the database schema and migrations. All schema changes must go through a migration file here — never make undocumented manual changes in the Supabase dashboard.

The Supabase CLI is already initialized for this project (`config.toml` is present).

---

## Applying migrations

### Option 1 — Supabase CLI (recommended)

First, link the CLI to the hosted project if you haven't already:

```bash
supabase link --project-ref cofakxwmrxauqtdldilx
```

Then push all pending migrations:

```bash
supabase db push
```

This applies any migration files in `migrations/` that have not yet been applied to the remote project. It is idempotent — already-applied migrations are skipped.

### Option 2 — Supabase Dashboard SQL editor

1. Open the project at `https://supabase.com/dashboard/project/cofakxwmrxauqtdldilx`
2. Navigate to **SQL Editor**
3. Paste and run the contents of each migration file in filename order

---

## Migrations

| File | Description |
|---|---|
| `20260329000000_initial_schema.sql` | Creates `profiles` and `user_goals` tables with RLS |

---

## Schema summary

### `profiles`
One row per authenticated user. Created during onboarding.

| Column | Type | Notes |
|---|---|---|
| `id` | uuid PK | FK → `auth.users(id)`, cascade delete |
| `display_name` | text | Nullable, set during onboarding |
| `created_at` | timestamptz | Default `now()` |

### `user_goals`
Stores calorie/macro targets and the body stats used to calculate them. Multiple rows per user are allowed (goal history). Exactly one row should have `is_active = true` at any time.

| Column | Type | Notes |
|---|---|---|
| `id` | uuid PK | `gen_random_uuid()` |
| `user_id` | uuid | FK → `auth.users(id)`, cascade delete |
| `goal_type` | text | `fat_loss` \| `maintenance` \| `lean_bulk` |
| `target_calories` | int | > 0 |
| `target_protein_g` | int | ≥ 0 |
| `target_carbs_g` | int | ≥ 0 |
| `target_fat_g` | int | ≥ 0 |
| `height_cm` | numeric(5,1) | Nullable |
| `weight_kg` | numeric(5,2) | Nullable |
| `age` | int | Nullable, 1–129 |
| `sex` | text | `male` \| `female` |
| `activity_level` | text | `sedentary` \| `light` \| `moderate` \| `active` \| `very_active` |
| `pace` | text | `slow` \| `moderate` \| `fast` |
| `is_active` | boolean | Default `true` |
| `created_at` | timestamptz | Default `now()` |
| `updated_at` | timestamptz | Default `now()` |

---

## RLS verification

After applying migrations, verify RLS is correctly enforced:

```sql
-- Both tables should show RLS enabled:
select tablename, rowsecurity
from pg_tables
where schemaname = 'public'
  and tablename in ('profiles', 'user_goals');

-- Verify policies exist:
select tablename, policyname, cmd, qual
from pg_policies
where schemaname = 'public'
order by tablename, policyname;
```

Expected: each table has `rowsecurity = true` and 3 policies (select, insert, update).

---

## Testing auth routing manually

To exercise the full routing matrix without building the onboarding flow, insert a test goal directly in the dashboard:

```sql
-- Replace <your-user-uuid> with the UUID from auth.users for your test account.
insert into public.user_goals (
    user_id, goal_type, target_calories,
    target_protein_g, target_carbs_g, target_fat_g
)
values (
    '<your-user-uuid>', 'fat_loss', 2000, 175, 200, 65
);
```

After inserting, relaunch the app — it should route directly to `MainTabView`.

---

## Adding a new migration

1. Create a new file in `migrations/` with the format `YYYYMMDDHHMMSS_description.sql`
2. Write the SQL (always enable RLS on new user-owned tables)
3. Test locally with `supabase db reset` (rebuilds from scratch) or apply to the remote with `supabase db push`
4. Commit the migration file
