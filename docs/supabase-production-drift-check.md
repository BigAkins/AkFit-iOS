# Supabase Production Drift Check

AkFit has a read-only production drift check for the database contracts that can
break onboarding, logging, or user data isolation even when local migration CI is
green. The check lives in `supabase/checks/production_drift.sql` and is run by
`scripts/supabase/check-production-drift.sh`.

## What It Verifies

The check reads only PostgreSQL catalog metadata and validates:

- The canonical CHECK constraints and accepted values for:
  `public.goals.goal_type`, `public.goals.target_pace`,
  `public.food_logs.meal_slot`, `public.profiles.sex`, and
  `public.profiles.activity_level`.
- No additional CHECK constraint on those same columns has a different accepted
  value set.
- RLS is enabled on user-owned tables:
  `bodyweight_logs`, `daily_notes`, `favorite_foods`, `food_logs`, `goals`,
  `grocery_items`, `profiles`, and `water_entries`.
- The expected owner-scoped RLS policies exist with the same command, policy
  mode, role set, `USING`, and `WITH CHECK` expressions tracked by migrations
  and local pgTAP tests.
- No extra policies exist on those user-owned tables.

Naming note: the app-facing "pace" value is stored in
`public.goals.target_pace`. Food log entries are stored in `public.food_logs`;
there is no separate production `log_entries` table.

## GitHub Actions Configuration

The workflow is `.github/workflows/supabase-production-drift.yml`. It runs:

- manually through `workflow_dispatch`
- every Monday at 12:17 UTC
- on pushes to `main` when Supabase contracts or the drift check change

Configure these repository secrets:

- `SUPABASE_PROD_DB_HOST`
- `SUPABASE_PROD_DB_PORT` (optional; defaults to `5432` when absent)
- `SUPABASE_PROD_DB_NAME`
- `SUPABASE_PROD_DB_USER`
- `SUPABASE_PROD_DB_PASSWORD`
- `SUPABASE_PROD_DB_SSLMODE` (optional; defaults to `require` when absent)

Prefer a dedicated read-only Postgres role for these secrets. If that is not
available yet, use the normal production Postgres connection values and keep the
script's `BEGIN READ ONLY` transaction in place. Do not use a Supabase
`service_role` API key; this check uses direct Postgres catalog reads, not
PostgREST or Supabase Admin APIs.

Never commit these values to the repo. The workflow and script only check
whether required values are present; they do not print them.

## Safe Local Run

Install `psql`, then run:

```bash
SUPABASE_PROD_DB_HOST="db.example.supabase.co" \
SUPABASE_PROD_DB_NAME="postgres" \
SUPABASE_PROD_DB_USER="readonly_user" \
SUPABASE_PROD_DB_PASSWORD="..." \
scripts/supabase/check-production-drift.sh
```

To sanity-check the query against a local Supabase stack after `supabase db
reset --local --yes`, the script also supports a local connection URL:

```bash
SUPABASE_PROD_DB_URL="postgresql://postgres:postgres@127.0.0.1:54322/postgres" scripts/supabase/check-production-drift.sh
```

`SUPABASE_PROD_DB_URL` is intentionally rejected when `GITHUB_ACTIONS=true`;
use the separate GitHub secrets above for production runs.

The SQL starts a `BEGIN READ ONLY` transaction, sets short timeouts, queries only
catalog views/tables, prints drift rows if any, then rolls back.

## When Drift Is Detected

Treat drift as release-blocking until triaged:

1. Compare the failed object with the matching migration, Swift enum/model, and
   local pgTAP contract test.
2. If production is wrong and migrations are correct, apply the missing
   migration through the normal Supabase deployment path, then rerun the drift
   check.
3. If the app contract changed intentionally, add or update the migration,
   update `supabase/checks/production_drift.sql`, and add/update the matching
   Swift or pgTAP contract coverage before rerunning the check.
4. If a policy failure appears, review it as a security issue. Do not loosen RLS
   to make the check pass.

The check should never be fixed by editing production manually without a
follow-up migration that makes the repository match production.
