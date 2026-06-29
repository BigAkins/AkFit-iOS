#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "$script_dir/../.." && pwd)"
sql_file="$repo_root/supabase/checks/production_drift.sql"

if [[ ! -f "$sql_file" ]]; then
  echo "::error::Missing drift check SQL at $sql_file"
  exit 2
fi

export PGCONNECT_TIMEOUT="${PGCONNECT_TIMEOUT:-10}"

psql_args=()
if [[ -n "${SUPABASE_PROD_DB_URL:-}" ]]; then
  if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
    echo "::error::Use separate SUPABASE_PROD_DB_* secrets in GitHub Actions, not SUPABASE_PROD_DB_URL."
    exit 2
  fi
  psql_args+=("$SUPABASE_PROD_DB_URL")
else
  missing_vars=()
  for var_name in \
    SUPABASE_PROD_DB_HOST \
    SUPABASE_PROD_DB_NAME \
    SUPABASE_PROD_DB_USER \
    SUPABASE_PROD_DB_PASSWORD
  do
    if [[ -z "${!var_name:-}" ]]; then
      missing_vars+=("$var_name")
    fi
  done

  if (( ${#missing_vars[@]} > 0 )); then
    echo "::error::Missing production database connection secret(s): ${missing_vars[*]}"
    echo "Set either SUPABASE_PROD_DB_URL or the separate SUPABASE_PROD_DB_* connection values."
    exit 2
  fi

  export PGHOST="$SUPABASE_PROD_DB_HOST"
  export PGPORT="${SUPABASE_PROD_DB_PORT:-5432}"
  export PGDATABASE="$SUPABASE_PROD_DB_NAME"
  export PGUSER="$SUPABASE_PROD_DB_USER"
  export PGPASSWORD="$SUPABASE_PROD_DB_PASSWORD"
  export PGSSLMODE="${SUPABASE_PROD_DB_SSLMODE:-require}"
fi

if ! command -v psql >/dev/null 2>&1; then
  echo "::error::psql is required to run the Supabase production drift check."
  exit 2
fi

set +e
drift_output="$(
  psql "${psql_args[@]}" \
    --no-psqlrc \
    --set=ON_ERROR_STOP=1 \
    --set=VERBOSITY=terse \
    --quiet \
    --tuples-only \
    --no-align \
    --field-separator=" | " \
    --file "$sql_file" \
    2>&1
)"
psql_status=$?
set -e

if [[ $psql_status -ne 0 ]]; then
  echo "::error::Production drift query failed before completing."
  printf '%s\n' "$drift_output"
  exit "$psql_status"
fi

if [[ -n "$drift_output" ]]; then
  echo "::error::Production Supabase drift detected."
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    printf 'drift: %s\n' "$line"
  done <<< "$drift_output"
  exit 1
fi

echo "Production Supabase drift check passed."
