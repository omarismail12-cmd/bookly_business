-- Phase 2 offline-sync: adds a free-text description field to services so
-- there is a real, non-financial, non-booking column to exercise the
-- expanded sync_queue write path against (queued via update_service_description
-- in lib/core/sync/sync_service.dart). Purely additive: nullable column, no
-- default, no constraint — existing RLS policies are table-scoped (see
-- 0005_rls.sql) so they apply to this column automatically with no changes.
alter table public.services add column if not exists description text;
