-- Performance hardening flagged by `supabase db advisors` (auth_rls_initplan):
-- the *_self_select policies added in 0013_customer_portal.sql call
-- auth.uid() directly inside their EXISTS subquery. Postgres re-evaluates
-- a bare auth.uid() call per row; wrapping it as (select auth.uid())
-- lets the planner cache it once per query (a well-known Supabase RLS
-- performance pattern). Purely a perf fix — same access rules, verified
-- unchanged in effect. (Note: PostgreSQL has no CREATE OR REPLACE POLICY —
-- policies must be dropped and recreated, same pattern used throughout
-- this project.)
-- Run after 0001..0020.

drop policy if exists customers_self_select on public.customers;
create policy customers_self_select
on public.customers
for select
to authenticated
using (profile_id = (select auth.uid()));

drop policy if exists appointments_self_select on public.appointments;
create policy appointments_self_select
on public.appointments
for select
to authenticated
using (
  exists (
    select 1 from public.customers c
    where c.id = appointments.customer_id and c.profile_id = (select auth.uid())
  )
);

drop policy if exists appointment_services_self_select on public.appointment_services;
create policy appointment_services_self_select
on public.appointment_services
for select
to authenticated
using (
  exists (
    select 1 from public.appointments a
    join public.customers c on c.id = a.customer_id
    where a.id = appointment_services.appointment_id and c.profile_id = (select auth.uid())
  )
);

drop policy if exists loyalty_accounts_self_select on public.loyalty_accounts;
create policy loyalty_accounts_self_select
on public.loyalty_accounts
for select
to authenticated
using (
  exists (
    select 1 from public.customers c
    where c.id = loyalty_accounts.customer_id and c.profile_id = (select auth.uid())
  )
);

drop policy if exists loyalty_transactions_self_select on public.loyalty_transactions;
create policy loyalty_transactions_self_select
on public.loyalty_transactions
for select
to authenticated
using (
  exists (
    select 1 from public.customers c
    where c.id = loyalty_transactions.customer_id and c.profile_id = (select auth.uid())
  )
);

drop policy if exists customer_packages_self_select on public.customer_packages;
create policy customer_packages_self_select
on public.customer_packages
for select
to authenticated
using (
  exists (
    select 1 from public.customers c
    where c.id = customer_packages.customer_id and c.profile_id = (select auth.uid())
  )
);

drop policy if exists customer_memberships_self_select on public.customer_memberships;
create policy customer_memberships_self_select
on public.customer_memberships
for select
to authenticated
using (
  exists (
    select 1 from public.customers c
    where c.id = customer_memberships.customer_id and c.profile_id = (select auth.uid())
  )
);

drop policy if exists queue_entries_self_select on public.queue_entries;
create policy queue_entries_self_select
on public.queue_entries
for select
to authenticated
using (
  exists (
    select 1 from public.customers c
    where c.id = queue_entries.customer_id and c.profile_id = (select auth.uid())
  )
);
