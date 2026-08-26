-- Crash fix, verified live: an owner logging into a demo-seeded business
-- hit `PostgrestException(message: infinite recursion detected in policy
-- for relation "campaigns", code: 42P17)` on the home dashboard, which
-- reads `campaigns` (crm_page.dart's campaign list / report_dashboard's
-- campaign_metrics).
--
-- Root cause: two RLS policies on two different tables each inline-
-- subquery the other, so Postgres's RLS evaluator recurses forever:
--   - campaign_recipients_select (0005_rls.sql) subqueries `campaigns`
--     directly to check organization_id in current_org_ids().
--   - campaigns_self_select (0029_customer_offers_access.sql) subqueries
--     `campaign_recipients` directly to check whether the current customer
--     is a recipient.
-- Evaluating either table's SELECT re-triggers RLS on the other table,
-- which re-triggers RLS on the first, forever.
--
-- Every other RLS policy across 0001..0035 was audited for the same
-- pattern (a policy inline-subquerying a second table whose own policy
-- inline-subqueries back) — this is the only cycle found. Every other
-- cross-table policy reference is one-directional (e.g.
-- appointment_services_select subqueries appointments, but no appointments
-- policy subqueries appointment_services back).
--
-- Fix: same pattern already used successfully for current_org_ids() and
-- has_org_role() — move the cross-table check into a SECURITY DEFINER
-- function. Being security definer, it runs as the migration-owning role
-- (which has BYPASSRLS in this project, same reason current_org_ids()
-- never recurses into organization_members' own RLS-protected read), so
-- its internal read of campaign_recipients/customers never re-triggers
-- RLS — breaking the cycle in both directions. Only campaigns_self_select
-- needs to change; campaign_recipients_select is left as-is since it no
-- longer round-trips back into campaign_recipients' RLS.
-- Run after 0001..0035.

create or replace function public.customer_is_campaign_recipient(p_campaign uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.campaign_recipients cr
    join public.customers c on c.id = cr.customer_id
    where cr.campaign_id = p_campaign and c.profile_id = auth.uid()
  );
$$;

revoke execute on function public.customer_is_campaign_recipient(uuid) from public;
grant execute on function public.customer_is_campaign_recipient(uuid) to authenticated;
revoke execute on function public.customer_is_campaign_recipient(uuid) from anon;

drop policy if exists campaigns_self_select on public.campaigns;
create policy campaigns_self_select
on public.campaigns
for select
to authenticated
using (public.customer_is_campaign_recipient(id));
