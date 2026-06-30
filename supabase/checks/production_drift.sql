-- Read-only production drift check for AkFit's critical Supabase contracts.
--
-- This file intentionally uses only catalog reads. It should be run with psql
-- through scripts/supabase/check-production-drift.sh so any returned rows fail
-- the job without exposing connection secrets.

begin read only;

set local statement_timeout = '15s';
set local lock_timeout = '2s';
set local idle_in_transaction_session_timeout = '30s';
set local search_path = pg_catalog, public;

with
expected_check_constraints(schema_name, table_name, column_name, constraint_name, expected_values) as (
    values
        ('public', 'goals',     'goal_type',      'goals_goal_type_check',          array['fat_loss', 'lean_bulk', 'maintenance']::text[]),
        ('public', 'goals',     'target_pace',    'goals_target_pace_check',        array['fast', 'moderate', 'slow']::text[]),
        ('public', 'food_logs', 'meal_slot',      'food_logs_meal_slot_check',      array['breakfast', 'dinner', 'lunch', 'snack']::text[]),
        ('public', 'profiles',  'sex',            'profiles_sex_check',             array['female', 'male']::text[]),
        ('public', 'profiles',  'activity_level', 'profiles_activity_level_check',  array['active', 'light', 'moderate', 'sedentary', 'very_active']::text[])
),

constraint_sources as (
    select
        expected.schema_name,
        expected.table_name,
        expected.column_name,
        expected.constraint_name,
        expected.expected_values,
        constraint_row.conname,
        pg_catalog.pg_get_constraintdef(constraint_row.oid, true) as constraint_def
    from expected_check_constraints expected
    left join pg_catalog.pg_namespace namespace_row
        on namespace_row.nspname = expected.schema_name
    left join pg_catalog.pg_class table_row
        on table_row.relnamespace = namespace_row.oid
       and table_row.relname = expected.table_name
       and table_row.relkind in ('r', 'p')
    left join pg_catalog.pg_attribute attribute_row
        on attribute_row.attrelid = table_row.oid
       and attribute_row.attname = expected.column_name
       and not attribute_row.attisdropped
    left join pg_catalog.pg_constraint constraint_row
        on constraint_row.conrelid = table_row.oid
       and constraint_row.contype = 'c'
       and attribute_row.attnum = any(constraint_row.conkey)
),

constraint_values as (
    select
        schema_name,
        table_name,
        column_name,
        constraint_name,
        expected_values,
        conname,
        coalesce(
            array_agg(distinct (literal_match.match)[1] order by (literal_match.match)[1])
                filter (where (literal_match.match)[1] is not null),
            array[]::text[]
        ) as actual_values
    from constraint_sources
    left join lateral pg_catalog.regexp_matches(constraint_def, '''([^'']+)''', 'g') as literal_match(match)
        on true
    group by schema_name, table_name, column_name, constraint_name, expected_values, conname
),

expected_rls_tables(schema_name, table_name) as (
    values
        ('public', 'bodyweight_logs'),
        ('public', 'daily_notes'),
        ('public', 'favorite_foods'),
        ('public', 'food_logs'),
        ('public', 'goals'),
        ('public', 'grocery_items'),
        ('public', 'profiles'),
        ('public', 'water_entries')
),

rls_table_state as (
    select
        expected.schema_name,
        expected.table_name,
        table_row.oid is not null as table_exists,
        coalesce(table_row.relrowsecurity, false) as rls_enabled
    from expected_rls_tables expected
    left join pg_catalog.pg_namespace namespace_row
        on namespace_row.nspname = expected.schema_name
    left join pg_catalog.pg_class table_row
        on table_row.relnamespace = namespace_row.oid
       and table_row.relname = expected.table_name
       and table_row.relkind in ('r', 'p')
),

expected_policies(schema_name, table_name, policy_name, command, policy_mode, roles, using_expr, with_check_expr) as (
    values
        ('public', 'bodyweight_logs', 'bodyweight_logs: delete own', 'DELETE', 'PERMISSIVE', '{public}', '(auth.uid() = user_id)', '<null>'),
        ('public', 'bodyweight_logs', 'bodyweight_logs: insert own', 'INSERT', 'PERMISSIVE', '{public}', '<null>', '(auth.uid() = user_id)'),
        ('public', 'bodyweight_logs', 'bodyweight_logs: select own', 'SELECT', 'PERMISSIVE', '{public}', '(auth.uid() = user_id)', '<null>'),
        ('public', 'daily_notes', 'Users manage own daily notes', 'ALL', 'PERMISSIVE', '{public}', '(auth.uid() = user_id)', '(auth.uid() = user_id)'),
        ('public', 'favorite_foods', 'favorite_foods: users manage own rows', 'ALL', 'PERMISSIVE', '{public}', '(auth.uid() = user_id)', '(auth.uid() = user_id)'),
        ('public', 'food_logs', 'food_logs: delete own', 'DELETE', 'PERMISSIVE', '{public}', '(auth.uid() = user_id)', '<null>'),
        ('public', 'food_logs', 'food_logs: insert own', 'INSERT', 'PERMISSIVE', '{public}', '<null>', '(auth.uid() = user_id)'),
        ('public', 'food_logs', 'food_logs: select own', 'SELECT', 'PERMISSIVE', '{public}', '(auth.uid() = user_id)', '<null>'),
        ('public', 'goals', 'goals: delete own', 'DELETE', 'PERMISSIVE', '{public}', '(auth.uid() = user_id)', '<null>'),
        ('public', 'goals', 'goals: insert own', 'INSERT', 'PERMISSIVE', '{public}', '<null>', '(auth.uid() = user_id)'),
        ('public', 'goals', 'goals: select own', 'SELECT', 'PERMISSIVE', '{public}', '(auth.uid() = user_id)', '<null>'),
        ('public', 'goals', 'goals: update own', 'UPDATE', 'PERMISSIVE', '{public}', '(auth.uid() = user_id)', '(auth.uid() = user_id)'),
        ('public', 'grocery_items', 'Users manage own grocery items', 'ALL', 'PERMISSIVE', '{public}', '(auth.uid() = user_id)', '(auth.uid() = user_id)'),
        ('public', 'profiles', 'profiles: insert own', 'INSERT', 'PERMISSIVE', '{public}', '<null>', '(auth.uid() = id)'),
        ('public', 'profiles', 'profiles: select own', 'SELECT', 'PERMISSIVE', '{public}', '(auth.uid() = id)', '<null>'),
        ('public', 'profiles', 'profiles: update own', 'UPDATE', 'PERMISSIVE', '{public}', '(auth.uid() = id)', '(auth.uid() = id)'),
        ('public', 'water_entries', 'water_entries: delete own', 'DELETE', 'PERMISSIVE', '{public}', '(auth.uid() = user_id)', '<null>'),
        ('public', 'water_entries', 'water_entries: insert own', 'INSERT', 'PERMISSIVE', '{public}', '<null>', '(auth.uid() = user_id)'),
        ('public', 'water_entries', 'water_entries: select own', 'SELECT', 'PERMISSIVE', '{public}', '(auth.uid() = user_id)', '<null>'),
        ('public', 'water_entries', 'water_entries: update own', 'UPDATE', 'PERMISSIVE', '{public}', '(auth.uid() = user_id)', '(auth.uid() = user_id)')
),

actual_policies as (
    select
        schemaname as schema_name,
        tablename as table_name,
        policyname as policy_name,
        cmd as command,
        permissive as policy_mode,
        roles::text as roles,
        pg_catalog.regexp_replace(coalesce(qual, '<null>'), '\s+', ' ', 'g') as using_expr,
        pg_catalog.regexp_replace(coalesce(with_check, '<null>'), '\s+', ' ', 'g') as with_check_expr
    from pg_catalog.pg_policies
    where schemaname = 'public'
      and tablename in (select table_name from expected_rls_tables)
),

check_constraint_failures as (
    select
        'check_constraint'::text as area,
        format('%I.%I.%I constraint %I', expected.schema_name, expected.table_name, expected.column_name, expected.constraint_name) as object_name,
        format('canonical constraint with values {%s}', array_to_string(expected.expected_values, ', ')) as expected,
        case
            when actual.conname is null then '<missing canonical check constraint>'
            else format('{%s}', array_to_string(actual.actual_values, ', '))
        end as actual
    from expected_check_constraints expected
    left join constraint_values actual
        on actual.schema_name = expected.schema_name
       and actual.table_name = expected.table_name
       and actual.column_name = expected.column_name
       and actual.conname = expected.constraint_name
    where actual.conname is null
       or actual.actual_values is distinct from expected.expected_values
),

additional_check_constraint_failures as (
    select
        'check_constraint'::text as area,
        format('%I.%I.%I constraint %I', schema_name, table_name, column_name, conname) as object_name,
        format('no additional same-column CHECK constraint with values other than {%s}', array_to_string(expected_values, ', ')) as expected,
        format('{%s}', array_to_string(actual_values, ', ')) as actual
    from constraint_values
    where conname is not null
      and conname <> constraint_name
      and actual_values is distinct from expected_values
),

rls_failures as (
    select
        'rls_enabled'::text as area,
        format('%I.%I', schema_name, table_name) as object_name,
        'RLS enabled'::text as expected,
        case
            when not table_exists then '<missing table>'
            when not rls_enabled then 'RLS disabled'
            else '<unknown>'
        end as actual
    from rls_table_state
    where not table_exists
       or not rls_enabled
),

policy_failures as (
    select
        'policy_shape'::text as area,
        format('%I.%I policy %L', expected.schema_name, expected.table_name, expected.policy_name) as object_name,
        format(
            'command=%s, mode=%s, roles=%s, using=%s, with_check=%s',
            expected.command,
            expected.policy_mode,
            expected.roles,
            expected.using_expr,
            expected.with_check_expr
        ) as expected,
        case
            when actual.policy_name is null then '<missing policy>'
            else format(
                'command=%s, mode=%s, roles=%s, using=%s, with_check=%s',
                actual.command,
                actual.policy_mode,
                actual.roles,
                actual.using_expr,
                actual.with_check_expr
            )
        end as actual
    from expected_policies expected
    left join actual_policies actual
        on actual.schema_name = expected.schema_name
       and actual.table_name = expected.table_name
       and actual.policy_name = expected.policy_name
    where actual.policy_name is null
       or actual.command <> expected.command
       or actual.policy_mode <> expected.policy_mode
       or actual.roles <> expected.roles
       or actual.using_expr <> expected.using_expr
       or actual.with_check_expr <> expected.with_check_expr
),

unexpected_policy_failures as (
    select
        'unexpected_policy'::text as area,
        format('%I.%I policy %L', actual.schema_name, actual.table_name, actual.policy_name) as object_name,
        'only the owner-scoped policies tracked in migrations'::text as expected,
        format(
            'command=%s, mode=%s, roles=%s, using=%s, with_check=%s',
            actual.command,
            actual.policy_mode,
            actual.roles,
            actual.using_expr,
            actual.with_check_expr
        ) as actual
    from actual_policies actual
    left join expected_policies expected
        on expected.schema_name = actual.schema_name
       and expected.table_name = actual.table_name
       and expected.policy_name = actual.policy_name
    where expected.policy_name is null
),

all_failures as (
    select * from check_constraint_failures
    union all
    select * from additional_check_constraint_failures
    union all
    select * from rls_failures
    union all
    select * from policy_failures
    union all
    select * from unexpected_policy_failures
)

select format('%s | %s | expected: %s | actual: %s', area, object_name, expected, actual)
from all_failures
order by area, object_name;

rollback;
