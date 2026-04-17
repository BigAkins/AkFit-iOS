# AkFit food seed data

Food/catalog seed data for `public.generic_foods`. Replayed by
`supabase db reset` **after** all schema migrations in `supabase/migrations`
have been applied. Wired in via `supabase/config.toml`:

```toml
[db.seed]
enabled = true
sql_paths = ["./seeds/food/*.sql"]
```

## Why this exists

Food rows ballooned the `migrations/` folder to ~44 files, making schema
diffs hard to find and slowing `supabase db reset`. Seed data that only
touches `generic_foods` rows belongs here; anything that changes schema,
RLS, or triggers belongs in `supabase/migrations`.

## Ordering

Files are executed in alphabetical order by the glob. The `NNN_` prefix
preserves the original chronological order of the seed migrations they
replaced so cross-file operations (e.g. the duplicate cleanup in `026`
deleting rows that `002` inserted) still work.

## Files

| Prefix | Source migration | Purpose |
|---|---|---|
| `001_generic_foods_seed`              | `20260329000004` | Initial USDA generic foods |
| `002_generic_foods_expand`            | `20260401000000` | More common produce / pantry |
| `003_generic_foods_staples`           | `20260401000002` | Additional staples |
| `004_fast_food_mcdonalds`             | `20260401000003` | McDonald's |
| `005_fast_food_chipotle`              | `20260401000004` | Chipotle |
| `006_fast_food_taco_bell`             | `20260401000005` | Taco Bell |
| `007_fast_food_wendys`                | `20260401000006` | Wendy's |
| `008_fast_food_cava`                  | `20260401000007` | CAVA |
| `009_fast_food_qdoba`                 | `20260401000008` | Qdoba |
| `010_desserts`                        | `20260401000011` | Desserts |
| `011_grocery_private_label`           | `20260401000012` | Trader Joe's / 365 / Great Value |
| `012_nigerian_west_african`           | `20260401000013` | Nigerian / West African |
| `013_fast_food_chick_fil_a`           | `20260402000001` | Chick-fil-A |
| `014_fast_food_raising_canes`         | `20260402000002` | Raising Cane's |
| `015_fast_food_in_n_out`              | `20260402000003` | In-N-Out |
| `016_fast_food_mod_pizza`             | `20260402000004` | MOD Pizza |
| `017_snacks_and_bars`                 | `20260402000005` | Snacks and bars |
| `018_fresh_produce_snackable`         | `20260402000006` | Snackable produce |
| `019_fast_food_whataburger`           | `20260402000007` | Whataburger |
| `020_fast_food_subway`                | `20260402000008` | Subway |
| `021_fast_food_panera`                | `20260402000009` | Panera |
| `022_starbucks_food`                  | `20260402000010` | Starbucks food |
| `023_fast_food_popeyes`               | `20260402000011` | Popeyes |
| `024_frozen_taquitos`                 | `20260402000012` | Frozen taquitos |
| `025_healthy_convenience`             | `20260402000013` | Healthy convenience |
| `026_data_cleanup`                    | `20260402000014` (data parts) | Duplicate removal + Grapes rename |
| `027_final_food_expansion`            | `20260403000000` | Final batch of generic foods |
| `028_search_improvements_seed`        | `20260403000001` (data part) | Comma-stripping friendly additions |
| `029_in_n_out_additions`              | `20260403000002` | In-N-Out menu additions |
| `030_in_n_out_corrections`            | `20260403000003` | In-N-Out nutrition corrections |

## Invariant

No file in this directory may contain `CREATE`, `ALTER`, `DROP`, or any
other schema statement — only `INSERT`, `UPDATE`, `DELETE` on existing
tables. Schema changes go in `supabase/migrations`.

## Adding a new seed

1. Pick the next `NNN_` prefix.
2. Create `NNN_descriptive_name.sql` with only data statements.
3. Run `supabase db reset` locally to confirm it loads cleanly.

## Production replay

`supabase db reset` affects only the local Supabase instance. The hosted
project already has the original pre-split migrations recorded in its
`supabase_migrations.schema_migrations` table; the effective row-level
state is identical either way.
