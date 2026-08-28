-- Consolidated cleanup for every throwaway org created during this
-- session's live verification work (customer-login regression testing,
-- dashboard error-handling testing, full role-by-role RPC/RLS
-- verification, demo-seed completeness testing, staff-scoping and
-- refund-sign fix verification).
--
-- "Regression Test Biz" (baffedb8-d1bd-4b37-8af3-e8e8893c0902) was
-- already deleted via 0039_cleanup_regression_test_biz.sql — not included
-- here. The two still-live ones:
--   - "Regression Test Biz 2" (7465b8ba-49c6-4dc6-8f7a-89247a240c6a,
--     slug regtest2-1787904393)
--   - "Regression Test Biz 3" (c9a6d3f5-6fc9-4b66-86a2-fd97586b0eb9,
--     slug regtest3-1787905310)
-- Both are fully demo-seeded (staff/services/customers/appointments/
-- payments/packages/memberships/coupons/campaigns/loyalty) plus extra
-- data from manager/receptionist/staff RPC and RLS testing (additional
-- staff_services/working_hours rows for throwaway staff logins, extra
-- appointments/queue status changes, reversed payments) — same shape of
-- problem as 0038/0039, reusing that exact ordering here rather than a
-- bare `delete from organizations`.
--
-- Auth accounts (organization owners and the manager/receptionist/staff
-- logins created against these orgs, plus the customer-only test
-- account used throughout) still need manual deletion from Supabase
-- Dashboard -> Authentication — no anon-key-reachable way to do this,
-- listed in full in this session's final summary.
--
-- Run after 0001..0043.

create temporary table _cleanup_org_ids on commit drop as
select id from public.organizations
where id in (
  '7465b8ba-49c6-4dc6-8f7a-89247a240c6a',
  'c9a6d3f5-6fc9-4b66-86a2-fd97586b0eb9'
);

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

update public.payments
set reversed_payment_id = null
where organization_id in (select id from _cleanup_org_ids);

delete from public.payments
where organization_id in (select id from _cleanup_org_ids);

delete from public.appointments
where organization_id in (select id from _cleanup_org_ids);

delete from public.packages
where organization_id in (select id from _cleanup_org_ids);

delete from public.memberships
where organization_id in (select id from _cleanup_org_ids);

delete from public.coupons
where organization_id in (select id from _cleanup_org_ids);

delete from public.services
where organization_id in (select id from _cleanup_org_ids);

delete from public.staff
where organization_id in (select id from _cleanup_org_ids);

delete from public.locations
where organization_id in (select id from _cleanup_org_ids);

delete from public.customers
where organization_id in (select id from _cleanup_org_ids);

delete from public.campaigns
where organization_id in (select id from _cleanup_org_ids);

delete from public.organizations
where id in (select id from _cleanup_org_ids);
