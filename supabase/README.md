# AkFit — Supabase

## Overview

The `supabase/` directory is the source of truth for the database schema, RLS policies, edge functions, food catalog seed data, and integrity tests. All schema changes must go through a migration file in `supabase/migrations/` — never make undocumented manual changes in the Supabase dashboard.

Layout:

| Path | Purpose |
|---|---|
| `migrations/` | Schema, RLS, triggers, indexes — versioned by timestamped filenames |
| `seeds/food/` | `generic_foods` catalog data (USDA + restaurant menus); replayed by `supabase db reset` after migrations. See `seeds/food/README.md` |
| `tests/database/` | RLS behavior + policy-shape tests run in CI |
| `functions/` | Edge functions |
| `config.toml` | Supabase CLI config (already initialized) |

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

For a clean local rebuild (drops everything, replays migrations, then replays `seeds/food/*.sql`):

```bash
supabase db reset
```

### Option 2 — Supabase Dashboard SQL editor

1. Open the project at `https://supabase.com/dashboard/project/cofakxwmrxauqtdldilx`
2. Navigate to **SQL Editor**
3. Paste and run the contents of each migration file in filename order

---

## Migrations

| File | Description |
|---|---|
| `20260329000000_initial_schema` | Creates `profiles` with RLS, plus a legacy goals table that is replaced by `public.goals` in `20260401000014_reconcile_schema` |
| `20260329000001_food_logs` | Creates `food_logs` with RLS |
| `20260329000002_food_logs_delete_policy` | Adds `delete own` policy to `food_logs` |
| `20260329000003_generic_foods` | Creates `generic_foods` (public-read catalog) with a trigram GIN index |
| `20260329000005_favorite_foods` | Creates `favorite_foods` (per-user saved foods) |
| `20260330000000_food_logs_meal_slot` | Adds `meal_slot` (breakfast/lunch/dinner/snack) to `food_logs` |
| `20260330000001_bodyweight_logs` | Creates `bodyweight_logs` |
| `20260331000000_fix_goal_height_weight_types` | Predates the schema reconcile; superseded by `20260401000014` |
| `20260331000001_profiles_add_sex_activity_level` | Adds `sex` and `activity_level` to `profiles` |
| `20260401000001_generic_foods_brand` | Adds nullable `brand` column to `generic_foods` |
| `20260401000009_daily_notes` | Creates `daily_notes` (one free-text note per user per day) |
| `20260401000010_grocery_items` | Creates `grocery_items` (persistent shopping list) |
| `20260401000014_reconcile_schema` | **Replaces the legacy goals table with `public.goals` and adds `height_cm`, `weight_kg`, `birthdate`, `updated_at` to `profiles`** |
| `20260402000014_data_cleanup_search_text` | Adds normalized `search_text` column, auto-populate trigger, and trigram GIN index on `generic_foods` |
| `20260403000001_search_improvements` | Updates the `generic_foods` `search_text` trigger to also strip commas |
| `20260416000000_goals_profiles_update_with_check` | Adds `WITH CHECK` to UPDATE policies on `goals` and `profiles` to close a cross-user write hole |

Food catalog rows that do not change schema live in `supabase/seeds/food/` (see that folder's README for the file-by-file list).

---

## Schema summary

### `profiles`
One row per authenticated user. Created during onboarding.

| Column | Type | Notes |
|---|---|---|
| `id` | uuid PK | FK → `auth.users(id)`, cascade delete |
| `display_name` | text | Nullable, set during onboarding |
| `sex` | text | `male` \| `female`, nullable |
| `activity_level` | text | `sedentary` \| `light` \| `moderate` \| `active` \| `very_active`, nullable |
| `height_cm` | integer | Nullable; integer for clean PostgREST→Double decoding |
| `weight_kg` | integer | Nullable; integer for clean PostgREST→Double decoding |
| `birthdate` | date | Nullable, returned as `"YYYY-MM-DD"` |
| `created_at` | timestamptz | Default `now()` |
| `updated_at` | timestamptz | NOT NULL, default `now()` |

### `goals`
Stores calorie/macro targets. Multiple rows per user are allowed (goal history); `AuthManager.fetchActiveGoal` reads the newest row by `created_at`.

| Column | Type | Notes |
|---|---|---|
| `id` | uuid PK | `gen_random_uuid()` |
| `user_id` | uuid | FK → `auth.users(id)`, cascade delete |
| `goal_type` | text | `fat_loss` \| `maintenance` \| `lean_bulk` |
| `target_weight` | numeric(5,2) | Nullable, kg |
| `target_pace` | text | `slow` \| `moderate` \| `fast`, nullable |
| `daily_calories` | int | > 0 |
| `daily_protein` | int | ≥ 0 |
| `daily_carbs` | int | ≥ 0 |
| `daily_fat` | int | ≥ 0 |
| `created_at` | timestamptz | Default `now()` |
| `updated_at` | timestamptz | Default `now()` |

Indexed on `(user_id, created_at desc)` for the active-goal read path.

### `food_logs`
One row per logged meal. Pre-scaled nutrition values (food value × quantity).

| Column | Type | Notes |
|---|---|---|
| `id` | uuid PK | `gen_random_uuid()` |
| `user_id` | uuid | FK → `auth.users(id)`, cascade delete |
| `food_name` | text | |
| `serving_label` | text | e.g. `"100g"`, `"2 tbsp (32g)"` |
| `quantity` | numeric(5,2) | > 0 |
| `calories` | int | ≥ 0 |
| `protein_g` / `carbs_g` / `fat_g` | numeric(6,1) | ≥ 0 |
| `meal_slot` | text | `breakfast` \| `lunch` \| `dinner` \| `snack`, default `'snack'` |
| `logged_at` | timestamptz | Default `now()` |
| `created_at` | timestamptz | Default `now()` |

### `generic_foods`
Public-read food catalog. Seeded from `seeds/food/*.sql`.

| Column | Type | Notes |
|---|---|---|
| `id` | uuid PK | `gen_random_uuid()` |
| `food_name` | text | |
| `serving_label` | text | |
| `serving_weight_g` | numeric(6,2) | Nullable |
| `calories` | integer | ≥ 0 |
| `protein_g` / `carbs_g` / `fat_g` | numeric(6,2) | ≥ 0 |
| `brand` | text | Nullable; restaurant or brand name (e.g. "McDonald's") |
| `source` | text | Default `'usda'` |
| `search_text` | text | Auto-populated by trigger; punctuation-stripped, lowercase |
| `created_at` | timestamptz | Default `now()` |

Trigram GIN index on `search_text` for punctuation-tolerant fuzzy search.

### `favorite_foods`
User-saved foods for fast repeat logging.

| Column | Type | Notes |
|---|---|---|
| `id` | uuid PK | |
| `user_id` | uuid | FK → `auth.users(id)`, cascade delete |
| `food_name`, `serving_label` | text | |
| `serving_weight_g`, `calories`, `protein_g`, `carbs_g`, `fat_g` | numeric / int | ≥ 0 |
| `brand_or_category` | text | Nullable |
| `created_at` | timestamptz | Default `now()` |

Unique on `(user_id, food_name, serving_label)`.

### `bodyweight_logs`

| Column | Type | Notes |
|---|---|---|
| `id` | uuid PK | |
| `user_id` | uuid | FK → `auth.users(id)`, cascade delete |
| `weight_kg` | numeric(5,2) | > 0 |
| `logged_at` | timestamptz | Default `now()` |
| `created_at` | timestamptz | Default `now()` |

### `daily_notes`
One free-text note per user per date. Unique on `(user_id, note_date)`.

### `grocery_items`
Persistent shopping list. `is_checked` boolean + `sort_order` int for ordering.

---

## RLS verification

After applying migrations, verify RLS is enabled on every user-owned table:

```sql
-- All listed tables should report rowsecurity = true:
select tablename, rowsecurity
from pg_tables
where schemaname = 'public'
  and tablename in (
    'profiles', 'goals',
    'food_logs', 'generic_foods', 'favorite_foods',
    'bodyweight_logs', 'daily_notes', 'grocery_items'
  )
order by tablename;

-- Inspect policies (per-table list):
select tablename, policyname, cmd, qual, with_check
from pg_policies
where schemaname = 'public'
order by tablename, policyname;
```

`generic_foods` is the only public-read table — its single policy is `select using (true)` with no write policy. All other tables enforce `auth.uid() = user_id` on both `using` and `with check`.

Behavior tests live in `supabase/tests/database/`:

- `rls_policy_shape.test.sql` — checks that policies exist with the expected shape
- `rls_behavior.test.sql` — exercises actual cross-user reads/writes to confirm RLS blocks them

The `CI` GitHub workflow (`.github/workflows/ci.yml`) runs both files against a local Supabase stack on every PR.

---

## Testing auth routing manually

To exercise the full routing matrix without going through onboarding, insert a goal directly in the dashboard:

```sql
-- Replace <your-user-uuid> with the UUID from auth.users for your test account.
insert into public.goals (
    user_id, goal_type,
    daily_calories, daily_protein, daily_carbs, daily_fat,
    target_pace
)
values (
    '<your-user-uuid>', 'fat_loss',
    2000, 175, 200, 65,
    'moderate'
);
```

After inserting, relaunch the app — `AuthManager.fetchActiveGoal` will read this row and route directly to `MainTabView`.

---

## Adding a new migration

1. Create a new file in `migrations/` with the format `YYYYMMDDHHMMSS_description.sql`
2. Write the SQL (always enable RLS on new user-owned tables; add `WITH CHECK` to UPDATE policies)
3. Test locally with `supabase db reset` (rebuilds from scratch and replays seeds) or apply to the remote with `supabase db push`
4. Commit the migration file

For data-only changes to `generic_foods` (no `CREATE` / `ALTER` / `DROP`), add a new file under `seeds/food/` instead — see `seeds/food/README.md`.
