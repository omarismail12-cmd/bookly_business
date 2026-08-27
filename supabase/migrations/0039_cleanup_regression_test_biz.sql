-- Cleanup: "Regression Test Biz" (slug regtest-*, id
-- baffedb8-d1bd-4b37-8af3-e8e8893c0902) was a throwaway account created
-- during this session's live verification of the customer-login
-- organization_members regression fix and the dashboard-loading
-- investigation — including a full seed_demo_data_for_current_user() run,
-- so unlike 0038's targets this one has real staff/customers/appointments/
-- payments/loyalty data, not just a bare organizations row.
--
-- Same non-cascading-FK ordering problem as 0038
-- (0038_cleanup_test_organizations.sql's header has the full audit of
-- which staff_services/appointments/payments/etc. foreign keys don't
-- cascade from organizations) — reusing that exact ordering here rather
-- than a bare `delete from organizations`.
--
-- Run after 0001..0038.

delete from public.appointment_services
where appointment_id in (
  select id from public.appointments
  where organization_id = 'baffedb8-d1bd-4b37-8af3-e8e8893c0902'
);

delete from public.queue_entries
where organization_id = 'baffedb8-d1bd-4b37-8af3-e8e8893c0902';

delete from public.package_usage
where organization_id = 'baffedb8-d1bd-4b37-8af3-e8e8893c0902';

delete from public.customer_memberships
where organization_id = 'baffedb8-d1bd-4b37-8af3-e8e8893c0902';

delete from public.customer_packages
where organization_id = 'baffedb8-d1bd-4b37-8af3-e8e8893c0902';

delete from public.coupon_redemptions
where organization_id = 'baffedb8-d1bd-4b37-8af3-e8e8893c0902';

delete from public.loyalty_accounts
where organization_id = 'baffedb8-d1bd-4b37-8af3-e8e8893c0902';

delete from public.loyalty_transactions
where organization_id = 'baffedb8-d1bd-4b37-8af3-e8e8893c0902';

delete from public.campaign_recipients
where campaign_id in (
  select id from public.campaigns
  where organization_id = 'baffedb8-d1bd-4b37-8af3-e8e8893c0902'
);

delete from public.notification_jobs
where organization_id = 'baffedb8-d1bd-4b37-8af3-e8e8893c0902';

update public.payments
set reversed_payment_id = null
where organization_id = 'baffedb8-d1bd-4b37-8af3-e8e8893c0902';

delete from public.payments
where organization_id = 'baffedb8-d1bd-4b37-8af3-e8e8893c0902';

delete from public.appointments
where organization_id = 'baffedb8-d1bd-4b37-8af3-e8e8893c0902';

delete from public.packages
where organization_id = 'baffedb8-d1bd-4b37-8af3-e8e8893c0902';

delete from public.memberships
where organization_id = 'baffedb8-d1bd-4b37-8af3-e8e8893c0902';

delete from public.coupons
where organization_id = 'baffedb8-d1bd-4b37-8af3-e8e8893c0902';

delete from public.services
where organization_id = 'baffedb8-d1bd-4b37-8af3-e8e8893c0902';

delete from public.staff
where organization_id = 'baffedb8-d1bd-4b37-8af3-e8e8893c0902';

delete from public.locations
where organization_id = 'baffedb8-d1bd-4b37-8af3-e8e8893c0902';

delete from public.customers
where organization_id = 'baffedb8-d1bd-4b37-8af3-e8e8893c0902';

delete from public.campaigns
where organization_id = 'baffedb8-d1bd-4b37-8af3-e8e8893c0902';

delete from public.organizations
where id = 'baffedb8-d1bd-4b37-8af3-e8e8893c0902';
