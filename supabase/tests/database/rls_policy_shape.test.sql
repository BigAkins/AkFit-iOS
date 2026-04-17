begin;

create extension if not exists pgtap with schema extensions;
set local search_path = extensions, public;

select plan(10);

select ok(
    to_regclass('public.user_goals') is null,
    'legacy user_goals table stays removed after reconcile_schema'
);

select set_eq(
$$
select c.relname
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relkind = 'r'
  and c.relname in (
        'bodyweight_logs',
        'daily_notes',
        'favorite_foods',
        'food_logs',
        'goals',
        'grocery_items',
        'profiles'
  )
  and c.relrowsecurity
$$,
$$
values
    ('bodyweight_logs'),
    ('daily_notes'),
    ('favorite_foods'),
    ('food_logs'),
    ('goals'),
    ('grocery_items'),
    ('profiles')
$$,
'user-scoped public tables keep RLS enabled'
);

select policies_are(
    'public',
    'bodyweight_logs',
    array[
        'bodyweight_logs: delete own',
        'bodyweight_logs: insert own',
        'bodyweight_logs: select own'
    ],
    'bodyweight_logs exposes only its expected policies'
);

select policies_are(
    'public',
    'daily_notes',
    array[
        'Users manage own daily notes'
    ],
    'daily_notes exposes only its expected policies'
);

select policies_are(
    'public',
    'favorite_foods',
    array[
        'favorite_foods: users manage own rows'
    ],
    'favorite_foods exposes only its expected policies'
);

select policies_are(
    'public',
    'food_logs',
    array[
        'food_logs: delete own',
        'food_logs: insert own',
        'food_logs: select own'
    ],
    'food_logs exposes only its expected policies'
);

select policies_are(
    'public',
    'goals',
    array[
        'goals: delete own',
        'goals: insert own',
        'goals: select own',
        'goals: update own'
    ],
    'goals exposes only its expected policies'
);

select policies_are(
    'public',
    'grocery_items',
    array[
        'Users manage own grocery items'
    ],
    'grocery_items exposes only its expected policies'
);

select policies_are(
    'public',
    'profiles',
    array[
        'profiles: insert own',
        'profiles: select own',
        'profiles: update own'
    ],
    'profiles exposes only its expected policies'
);

select set_eq(
$$
select
    tablename,
    policyname,
    cmd,
    coalesce(regexp_replace(qual, '\s+', ' ', 'g'), '<null>') as using_expr,
    coalesce(regexp_replace(with_check, '\s+', ' ', 'g'), '<null>') as with_check_expr
from pg_policies
where schemaname = 'public'
  and tablename in (
        'bodyweight_logs',
        'daily_notes',
        'favorite_foods',
        'food_logs',
        'goals',
        'grocery_items',
        'profiles'
  )
$$,
$$
values
    ('bodyweight_logs', 'bodyweight_logs: delete own', 'DELETE', '(auth.uid() = user_id)', '<null>'),
    ('bodyweight_logs', 'bodyweight_logs: insert own', 'INSERT', '<null>', '(auth.uid() = user_id)'),
    ('bodyweight_logs', 'bodyweight_logs: select own', 'SELECT', '(auth.uid() = user_id)', '<null>'),
    ('daily_notes', 'Users manage own daily notes', 'ALL', '(auth.uid() = user_id)', '(auth.uid() = user_id)'),
    ('favorite_foods', 'favorite_foods: users manage own rows', 'ALL', '(auth.uid() = user_id)', '(auth.uid() = user_id)'),
    ('food_logs', 'food_logs: delete own', 'DELETE', '(auth.uid() = user_id)', '<null>'),
    ('food_logs', 'food_logs: insert own', 'INSERT', '<null>', '(auth.uid() = user_id)'),
    ('food_logs', 'food_logs: select own', 'SELECT', '(auth.uid() = user_id)', '<null>'),
    ('goals', 'goals: delete own', 'DELETE', '(auth.uid() = user_id)', '<null>'),
    ('goals', 'goals: insert own', 'INSERT', '<null>', '(auth.uid() = user_id)'),
    ('goals', 'goals: select own', 'SELECT', '(auth.uid() = user_id)', '<null>'),
    ('goals', 'goals: update own', 'UPDATE', '(auth.uid() = user_id)', '(auth.uid() = user_id)'),
    ('grocery_items', 'Users manage own grocery items', 'ALL', '(auth.uid() = user_id)', '(auth.uid() = user_id)'),
    ('profiles', 'profiles: insert own', 'INSERT', '<null>', '(auth.uid() = id)'),
    ('profiles', 'profiles: select own', 'SELECT', '(auth.uid() = id)', '<null>'),
    ('profiles', 'profiles: update own', 'UPDATE', '(auth.uid() = id)', '(auth.uid() = id)')
$$,
'user-scoped policies keep their expected USING and WITH CHECK shape'
);

select * from finish();
rollback;
