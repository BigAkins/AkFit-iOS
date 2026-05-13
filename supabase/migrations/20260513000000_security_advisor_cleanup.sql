-- =============================================================================
-- Migration: 20260513000000_security_advisor_cleanup
-- Purpose:   Address low-risk Supabase Security Advisor warnings without
--            changing app behavior, RLS policy scope, or seed data.
--
-- Notes:
--   * `pg_trgm` remains in `public` for now. Moving an installed extension can
--     affect the existing trigram operator class/index used by food search and
--     should be handled in a separate, explicitly planned migration.
--   * Leaked password protection is an Auth dashboard/project setting, not a
--     database schema change, so it is intentionally not represented here.
-- =============================================================================

-- Function Search Path Mutable: generic_foods_set_search_text
do $$
begin
    if to_regprocedure('public.generic_foods_set_search_text()') is not null then
        execute 'alter function public.generic_foods_set_search_text() set search_path = pg_catalog, pg_temp';
    else
        raise notice 'Skipping generic_foods_set_search_text search_path cleanup; function does not exist';
    end if;
end
$$;

-- Function Search Path Mutable: handle_updated_at
do $$
begin
    if to_regprocedure('public.handle_updated_at()') is not null then
        execute 'alter function public.handle_updated_at() set search_path = pg_catalog, pg_temp';
    else
        raise notice 'Skipping handle_updated_at search_path cleanup; function does not exist';
    end if;
end
$$;

-- SECURITY DEFINER hardening: rls_auto_enable()
--
-- Hosted production currently has this helper, while fresh local rebuilds may
-- not. Keep owner/service behavior intact, but remove app-facing execute access.
do $$
begin
    if to_regprocedure('public.rls_auto_enable()') is not null then
        execute 'revoke execute on function public.rls_auto_enable() from public';
        execute 'revoke execute on function public.rls_auto_enable() from anon';
        execute 'revoke execute on function public.rls_auto_enable() from authenticated';
    else
        raise notice 'Skipping rls_auto_enable privilege cleanup; function does not exist';
    end if;
end
$$;
