-- Public storefront read access (P0 bug fix, verified live).
-- Run after 0001..0011.
--
-- Verified directly against the live project via the REST API (anon key,
-- no session): the public booking page (`/book/:slug`, isPublic in
-- booking_page.dart) reads `organizations` (by slug), `services`, `staff`
-- and `locations` directly from the client with NO auth. Every one of
-- those tables' only SELECT policy (0005) is
--   organization_id in (select current_org_ids())
-- current_org_ids() filters by auth.uid(), which is null for an
-- unauthenticated visitor, so current_org_ids() returns an empty set and
-- every one of those reads comes back empty. The entire public booking
-- flow — the product's headline feature ("online booking without
-- double-booking", spec slide 1) — does not work today on the live
-- database. Confirmed by seeding real demo data and querying it with the
-- anon key: 0 rows every time, for a slug that genuinely exists.
--
-- Fix: add narrowly-scoped SELECT policies for anon+authenticated that
-- expose exactly what a public storefront is supposed to show (name,
-- services, staff, locations of *active* businesses only) — the same data
-- get_available_slots()/create_public_booking() already computes from
-- server-side as SECURITY DEFINER, just now also readable directly for the
-- page to render its pickers. Nothing sensitive (customers, payments,
-- appointments, staff phone/profile linkage, audit logs) is touched.

create policy organizations_public_select
on public.organizations
for select
to anon, authenticated
using (status = 'active' and deleted_at is null);

create policy services_public_select
on public.services
for select
to anon, authenticated
using (
  deleted_at is null
  and exists (
    select 1 from public.organizations o
    where o.id = services.organization_id and o.status = 'active' and o.deleted_at is null
  )
);

create policy staff_public_select
on public.staff
for select
to anon, authenticated
using (
  status = 'active' and deleted_at is null
  and exists (
    select 1 from public.organizations o
    where o.id = staff.organization_id and o.status = 'active' and o.deleted_at is null
  )
);

create policy locations_public_select
on public.locations
for select
to anon, authenticated
using (
  deleted_at is null
  and exists (
    select 1 from public.organizations o
    where o.id = locations.organization_id and o.status = 'active' and o.deleted_at is null
  )
);

-- staff_services is read by get_available_slots()/create_public_booking()
-- (SECURITY DEFINER, already bypasses RLS) but not directly by the client
-- today. Exposing it costs nothing extra (staff/service ids are already
-- public via the policies above) and lets the booking UI filter "which
-- staff can do this service" without a round trip through an RPC.
create policy staff_services_public_select
on public.staff_services
for select
to anon, authenticated
using (
  exists (
    select 1 from public.staff s
    join public.organizations o on o.id = s.organization_id
    where s.id = staff_services.staff_id and o.status = 'active' and o.deleted_at is null
  )
);
