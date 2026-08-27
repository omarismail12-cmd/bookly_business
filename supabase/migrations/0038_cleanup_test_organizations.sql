-- Cleanup, authorized explicitly: this engagement's own automated
-- integration-test runs (dart test integration_test) and throwaway
-- diagnostic probe scripts created ~166 real rows in this live project —
-- every one publicly visible via organizations_public_select
-- (0012/0035_fix_anon_storefront_rls.sql), which has no per-row secrecy,
-- only a `status = 'active'` filter.
--
-- REVISED after the first push attempt failed with:
--   update or delete on table "services" violates foreign key
--   constraint "appointment_services_service_id_fkey" (SQLSTATE 23503)
-- Root cause, verified directly against 0001_foundation.sql (and every
-- later migration, checked for ALTERs to these constraints — there are
-- none): a straight `delete from organizations` relies on every
-- descendant table cascading via `on delete cascade`, but a full audit
-- of every foreign key in the schema (0001, 0002, 0003, 0004, 0009,
-- 0010, 0037) found 28 non-cascading references into tables that
-- themselves cascade from organizations — appointment_services.service_id
-- was only one of them. Postgres does not guarantee the order in which
-- independent cascade triggers from the same parent DELETE fire, so any
-- of these can block the delete depending on ordering luck, not just the
-- one that happened to error first.
--
-- Fix: compute the target org ids once, then explicitly delete every
-- non-cascading child row for those orgs, in dependency order (deepest
-- leaves first), before touching organizations at all. Once every
-- non-cascading reference is cleared, organizations' own cascades
-- (`on delete cascade`, already correct for every *_id -> organizations
-- reference) clean up everything else automatically — organization_members,
-- audit_logs, device_tokens, staff_services/working_hours/staff_breaks/
-- blocked_times (via staff's cascade), and the now-empty tables below.
--
-- Run after 0001..0037.

create temporary table _cleanup_org_ids on commit drop as
select id from public.organizations
where (
  slug like 'itest-%'
  or slug like 'demo-%'
  or slug like 'campaign-check-%'
  or name = 'Anon Probe Org'
  or name like 'Integration Test Salon %'
  or name = 'Campaign Check Org'
  or name = 'Bookly Demo Salon'
)
and slug not in ('trv', 'snszxx', 'hairism', 'staff', 'owner');

-- Level 0/1: tables with no other non-cascading table referencing them.
-- appointment_services and campaign_recipients have no organization_id
-- column of their own, so they're scoped via their parent instead.
delete from public.appointment_services
where appointment_id in (
  select id from public.appointments
  where organization_id in (select id from _cleanup_org_ids)
);

delete from public.queue_entries
where organization_id in (select id from _cleanup_org_ids);

delete from public.package_usage
where organization_id in (select id from _cleanup_org_ids);

delete from public.customer_memberships
where organization_id in (select id from _cleanup_org_ids);

delete from public.customer_packages
where organization_id in (select id from _cleanup_org_ids);

delete from public.coupon_redemptions
where organization_id in (select id from _cleanup_org_ids);

delete from public.loyalty_accounts
where organization_id in (select id from _cleanup_org_ids);

delete from public.loyalty_transactions
where organization_id in (select id from _cleanup_org_ids);

delete from public.campaign_recipients
where campaign_id in (
  select id from public.campaigns
  where organization_id in (select id from _cleanup_org_ids)
);

delete from public.notification_jobs
where organization_id in (select id from _cleanup_org_ids);

-- Level 2: payments. Referenced by customer_memberships/customer_packages/
-- loyalty_transactions/coupon_redemptions (all cleared above) via
-- source_payment_id/payment_id, and self-referencing via
-- reversed_payment_id — break that self-reference first.
update public.payments
set reversed_payment_id = null
where organization_id in (select id from _cleanup_org_ids);

delete from public.payments
where organization_id in (select id from _cleanup_org_ids);

-- Level 3: appointments. Referenced by payments (cleared above),
-- package_usage/loyalty_transactions/coupon_redemptions (cleared above),
-- appointment_services/notification_jobs (cleared above, and those two
-- do cascade from appointments anyway — cleared for the other
-- non-cascading refs they hold, not because appointments needed it).
delete from public.appointments
where organization_id in (select id from _cleanup_org_ids);

-- Level 4: packages/memberships/coupons. Referenced by package_usage/
-- customer_packages (-> packages), customer_memberships (-> memberships),
-- coupon_redemptions (-> coupons) — all cleared above. packages itself
-- references services (packages.service_id, no cascade), so packages
-- must go before services.
delete from public.packages
where organization_id in (select id from _cleanup_org_ids);

delete from public.memberships
where organization_id in (select id from _cleanup_org_ids);

delete from public.coupons
where organization_id in (select id from _cleanup_org_ids);

-- Level 5: services. Blocked before by appointment_services (cleared),
-- queue_entries (cleared), and packages.service_id (cleared above).
delete from public.services
where organization_id in (select id from _cleanup_org_ids);

-- Level 6: staff/locations. Blocked before by appointments (cleared)
-- and queue_entries (cleared, staff only). staff_services/working_hours/
-- staff_breaks/blocked_times all cascade from staff's own deletion.
delete from public.staff
where organization_id in (select id from _cleanup_org_ids);

delete from public.locations
where organization_id in (select id from _cleanup_org_ids);

-- Level 7: customers. Blocked before by appointments, queue_entries,
-- package_usage, customer_memberships, customer_packages,
-- coupon_redemptions, loyalty_accounts, loyalty_transactions,
-- campaign_recipients, notification_jobs — every one cleared above.
delete from public.customers
where organization_id in (select id from _cleanup_org_ids);

-- Level 8: campaigns. campaign_recipients (its one referrer) cleared
-- above; notification_jobs.campaign_id cascades on its own.
delete from public.campaigns
where organization_id in (select id from _cleanup_org_ids);

-- Everything non-cascading is now cleared. organizations' own cascades
-- handle organization_members, audit_logs, device_tokens, and anything
-- else with a plain `on delete cascade` straight to organizations.
delete from public.organizations
where id in (select id from _cleanup_org_ids);
