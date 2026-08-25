-- P0 bug fix, verified live: the public booking page (`/book/:slug`,
-- isPublic in booking_page.dart) reads organizations/services/staff/
-- locations directly with no auth. 0012_public_storefront_access.sql added
-- anon-safe SELECT policies for exactly this, but they never actually
-- worked: organizations_select/services_select/staff_select/locations_select
-- (0005_rls.sql) have no `to` clause, so they apply to PUBLIC (including
-- anon) and filter via `organization_id in (select current_org_ids())`.
-- That's an uncorrelated scalar subquery, which Postgres hoists into an
-- InitPlan evaluated unconditionally — before the OR against 0012's
-- anon-safe policy can short-circuit. 0016 revoked anon's EXECUTE on
-- current_org_ids(), so that unconditional evaluation throws
-- "permission denied for function current_org_ids" on every anon read of
-- these tables, regardless of what 0012's policy would have granted.
-- Verified live with real seeded data: every anon read of organizations,
-- services, staff, and locations failed with exactly this error — the
-- entire public booking flow does not work today.
--
-- Fix: restrict the 0005 org-scoped policies on the 5 tables that also
-- have an 0012 anon-safe policy to `to authenticated`. Anon access to
-- these tables now comes exclusively through 0012's narrow, already-correct
-- policies. Authenticated org-member access is unchanged (current_org_ids()
-- still resolves the same way for authenticated callers).
--
-- (No CREATE OR REPLACE POLICY in Postgres — drop and recreate, same
-- pattern used throughout this project, e.g. 0021.)
-- Run after 0001..0034.

drop policy if exists organizations_select on public.organizations;
create policy organizations_select
on public.organizations
for select
to authenticated
using (
  id in (
    select public.current_org_ids()
  )
);

drop policy if exists services_select on public.services;
create policy services_select
on public.services
for select
to authenticated
using (
  organization_id in (
    select public.current_org_ids()
  )
);

drop policy if exists staff_select on public.staff;
create policy staff_select
on public.staff
for select
to authenticated
using (
  organization_id in (
    select public.current_org_ids()
  )
);

drop policy if exists locations_select on public.locations;
create policy locations_select
on public.locations
for select
to authenticated
using (
  organization_id in (
    select public.current_org_ids()
  )
);

drop policy if exists staff_services_select on public.staff_services;
create policy staff_services_select
on public.staff_services
for select
to authenticated
using (
  exists (
    select 1
    from public.staff s
    where s.id = staff_services.staff_id
    and s.organization_id in (
      select public.current_org_ids()
    )
  )
);
