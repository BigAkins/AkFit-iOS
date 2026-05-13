begin;

create extension if not exists pgtap with schema extensions;
set local search_path = extensions, public;

select plan(30);

create function public.test_affected_rows(sql text)
returns int
language plpgsql
as $$
declare
    affected_rows int;
begin
    execute sql;
    get diagnostics affected_rows = row_count;
    return affected_rows;
end;
$$;

-- Fixed local-only auth users keep the cross-user checks readable.
insert into auth.users (
    id,
    aud,
    role,
    email,
    email_confirmed_at,
    created_at,
    updated_at,
    raw_app_meta_data,
    raw_user_meta_data
)
values
    (
        '11111111-1111-1111-1111-111111111111',
        'authenticated',
        'authenticated',
        'rls-user-a@example.test',
        now(),
        now(),
        now(),
        '{}'::jsonb,
        '{}'::jsonb
    ),
    (
        '22222222-2222-2222-2222-222222222222',
        'authenticated',
        'authenticated',
        'rls-user-b@example.test',
        now(),
        now(),
        now(),
        '{}'::jsonb,
        '{}'::jsonb
    ),
    (
        '33333333-3333-3333-3333-333333333333',
        'authenticated',
        'authenticated',
        'rls-user-c@example.test',
        now(),
        now(),
        now(),
        '{}'::jsonb,
        '{}'::jsonb
    );

-- Seed user B's protected rows as database setup. The assertions below run as
-- user A through the authenticated role, so RLS must hide/protect these rows.
insert into public.profiles (id, display_name)
values ('22222222-2222-2222-2222-222222222222', 'User B');

insert into public.goals (
    id,
    user_id,
    goal_type,
    target_pace,
    daily_calories,
    daily_protein,
    daily_carbs,
    daily_fat
)
values (
    'aaaaaaaa-2222-2222-2222-222222222222',
    '22222222-2222-2222-2222-222222222222',
    'maintenance',
    'moderate',
    2100,
    150,
    220,
    70
);

insert into public.food_logs (
    id,
    user_id,
    food_name,
    serving_label,
    quantity,
    calories,
    protein_g,
    carbs_g,
    fat_g
)
values (
    'bbbbbbbb-2222-2222-2222-222222222222',
    '22222222-2222-2222-2222-222222222222',
    'User B oatmeal',
    '1 bowl',
    1,
    320,
    12,
    54,
    7
);

insert into public.daily_notes (
    id,
    user_id,
    note_date,
    content
)
values (
    'cccccccc-2222-2222-2222-222222222222',
    '22222222-2222-2222-2222-222222222222',
    '2026-01-01',
    'User B note'
);

select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true);
select set_config('request.jwt.claim.role', 'authenticated', true);
set local role authenticated;

-- profiles: recently hardened ownership check must work in behavior, not just metadata.
select lives_ok(
    $$insert into public.profiles (id, display_name)
      values ('11111111-1111-1111-1111-111111111111', 'User A')$$,
    'user A can insert their own profile'
);

select is(
    (select count(*)::int from public.profiles where id = '11111111-1111-1111-1111-111111111111'),
    1,
    'user A can read their own profile'
);

select is(
    (select count(*)::int from public.profiles where id = '22222222-2222-2222-2222-222222222222'),
    0,
    'user A cannot read user B profile'
);

select is(
    public.test_affected_rows(
        $$update public.profiles
             set display_name = 'User A updated'
           where id = '11111111-1111-1111-1111-111111111111'$$
    ),
    1,
    'user A can update their own profile'
);

select lives_ok(
    $$insert into public.profiles (
          id,
          display_name,
          height_cm,
          weight_kg,
          birthdate,
          sex,
          activity_level,
          updated_at
      )
      values (
          '11111111-1111-1111-1111-111111111111',
          'User A upserted',
          170,
          75,
          '1990-01-01',
          'male',
          'moderate',
          now()
      )
      on conflict (id) do update
          set display_name   = excluded.display_name,
              height_cm      = excluded.height_cm,
              weight_kg      = excluded.weight_kg,
              birthdate      = excluded.birthdate,
              sex            = excluded.sex,
              activity_level = excluded.activity_level,
              updated_at     = excluded.updated_at$$,
    'user A can upsert their existing profile under RLS'
);

select is(
    public.test_affected_rows(
        $$update public.profiles
             set display_name = 'User A touched B'
           where id = '22222222-2222-2222-2222-222222222222'$$
    ),
    0,
    'user A cannot update user B profile'
);

select throws_ok(
    $$update public.profiles
         set id = '33333333-3333-3333-3333-333333333333'
       where id = '11111111-1111-1111-1111-111111111111'$$,
    '42501',
    'new row violates row-level security policy for table "profiles"',
    'user A cannot transfer their profile ownership'
);

-- goals: protects the active macro target row used by onboarding/dashboard.
select lives_ok(
    $$insert into public.goals (
          id,
          user_id,
          goal_type,
          target_pace,
          daily_calories,
          daily_protein,
          daily_carbs,
          daily_fat
      )
      values (
          'aaaaaaaa-1111-1111-1111-111111111111',
          '11111111-1111-1111-1111-111111111111',
          'fat_loss',
          'moderate',
          1900,
          170,
          160,
          60
      )$$,
    'user A can insert their own goal'
);

select is(
    (select count(*)::int from public.goals where user_id = '11111111-1111-1111-1111-111111111111'),
    1,
    'user A can read their own goal'
);

select is(
    (select count(*)::int from public.goals where user_id = '22222222-2222-2222-2222-222222222222'),
    0,
    'user A cannot read user B goal'
);

select is(
    public.test_affected_rows(
        $$update public.goals
             set daily_calories = 1950
           where id = 'aaaaaaaa-1111-1111-1111-111111111111'$$
    ),
    1,
    'user A can update their own goal'
);

select is(
    public.test_affected_rows(
        $$update public.goals
             set daily_calories = 9999
           where id = 'aaaaaaaa-2222-2222-2222-222222222222'$$
    ),
    0,
    'user A cannot update user B goal'
);

select is(
    public.test_affected_rows(
        $$delete from public.goals
           where id = 'aaaaaaaa-2222-2222-2222-222222222222'$$
    ),
    0,
    'user A cannot delete user B goal'
);

select lives_ok(
    $$insert into public.goals (
          user_id,
          goal_type,
          target_pace,
          daily_calories,
          daily_protein,
          daily_carbs,
          daily_fat
      )
      values (
          '11111111-1111-1111-1111-111111111111',
          'maintenance',
          null,
          2100,
          165,
          230,
          58
      )$$,
    'user A can insert a maintenance goal with no target pace'
);

select throws_ok(
    $$insert into public.goals (
          user_id,
          goal_type,
          target_pace,
          daily_calories,
          daily_protein,
          daily_carbs,
          daily_fat
      )
      values (
          '22222222-2222-2222-2222-222222222222',
          'fat_loss',
          'moderate',
          1800,
          160,
          150,
          55
      )$$,
    '42501',
    'new row violates row-level security policy for table "goals"',
    'user A cannot insert a goal for user B'
);

select throws_ok(
    $$update public.goals
         set user_id = '22222222-2222-2222-2222-222222222222'
       where id = 'aaaaaaaa-1111-1111-1111-111111111111'$$,
    '42501',
    'new row violates row-level security policy for table "goals"',
    'user A cannot transfer goal ownership'
);

-- food_logs: protects the daily macro log from cross-user reads/deletes.
select lives_ok(
    $$insert into public.food_logs (
          id,
          user_id,
          food_name,
          serving_label,
          quantity,
          calories,
          protein_g,
          carbs_g,
          fat_g
      )
      values (
          'bbbbbbbb-1111-1111-1111-111111111111',
          '11111111-1111-1111-1111-111111111111',
          'User A chicken bowl',
          '1 bowl',
          1,
          540,
          42,
          48,
          18
      )$$,
    'user A can insert their own food log'
);

select is(
    (select count(*)::int from public.food_logs where user_id = '11111111-1111-1111-1111-111111111111'),
    1,
    'user A can read their own food log'
);

select is(
    (select count(*)::int from public.food_logs where user_id = '22222222-2222-2222-2222-222222222222'),
    0,
    'user A cannot read user B food log'
);

select throws_ok(
    $$insert into public.food_logs (
          user_id,
          food_name,
          serving_label,
          quantity,
          calories,
          protein_g,
          carbs_g,
          fat_g
      )
      values (
          '22222222-2222-2222-2222-222222222222',
          'Cross-user snack',
          '1 serving',
          1,
          100,
          5,
          12,
          3
      )$$,
    '42501',
    'new row violates row-level security policy for table "food_logs"',
    'user A cannot insert a food log for user B'
);

select is(
    public.test_affected_rows(
        $$delete from public.food_logs
           where id = 'bbbbbbbb-2222-2222-2222-222222222222'$$
    ),
    0,
    'user A cannot delete user B food log'
);

select is(
    public.test_affected_rows(
        $$delete from public.food_logs
           where id = 'bbbbbbbb-1111-1111-1111-111111111111'$$
    ),
    1,
    'user A can delete their own food log'
);

-- daily_notes: one FOR ALL table proves combined read/write/delete ownership behavior.
select lives_ok(
    $$insert into public.daily_notes (
          id,
          user_id,
          note_date,
          content
      )
      values (
          'cccccccc-1111-1111-1111-111111111111',
          '11111111-1111-1111-1111-111111111111',
          '2026-01-02',
          'User A note'
      )$$,
    'user A can insert their own daily note'
);

select is(
    (select count(*)::int from public.daily_notes where user_id = '11111111-1111-1111-1111-111111111111'),
    1,
    'user A can read their own daily note'
);

select is(
    (select count(*)::int from public.daily_notes where user_id = '22222222-2222-2222-2222-222222222222'),
    0,
    'user A cannot read user B daily note'
);

select is(
    public.test_affected_rows(
        $$update public.daily_notes
             set content = 'User A updated note'
           where id = 'cccccccc-1111-1111-1111-111111111111'$$
    ),
    1,
    'user A can update their own daily note'
);

select is(
    public.test_affected_rows(
        $$update public.daily_notes
             set content = 'User A touched B'
           where id = 'cccccccc-2222-2222-2222-222222222222'$$
    ),
    0,
    'user A cannot update user B daily note'
);

select is(
    public.test_affected_rows(
        $$delete from public.daily_notes
           where id = 'cccccccc-2222-2222-2222-222222222222'$$
    ),
    0,
    'user A cannot delete user B daily note'
);

select throws_ok(
    $$insert into public.daily_notes (
          user_id,
          note_date,
          content
      )
      values (
          '22222222-2222-2222-2222-222222222222',
          '2026-01-03',
          'Cross-user note'
      )$$,
    '42501',
    'new row violates row-level security policy for table "daily_notes"',
    'user A cannot insert a daily note for user B'
);

select is(
    public.test_affected_rows(
        $$delete from public.daily_notes
           where id = 'cccccccc-1111-1111-1111-111111111111'$$
    ),
    1,
    'user A can delete their own daily note'
);

reset role;

select * from finish();
rollback;
