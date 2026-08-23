-- Phase 3: the customer app's "offers" screen needs to read active coupons
-- and the campaigns a customer was personally targeted by, at any business
-- they're a customer of. Neither table currently grants a customer any
-- access at all: coupons_select/campaigns_select (0005_rls.sql) and
-- campaign_recipients_select (0005_rls.sql) are org-member-scoped only
-- (organization_id in current_org_ids()), and a customer is never an
-- organization_member.
--
-- Same additive pattern as the customer self-select policies in
-- 0013_customer_portal.sql (RLS policies are OR'd together; every existing
-- policy — including the org-member ones above — is untouched). All three
-- are SELECT-only: a customer never writes to any of these tables.

-- Active, unexpired coupons at businesses this customer has a record with.
-- Matches "browse active coupons", not personalized targeting — that's
-- campaigns/campaign_recipients below.
create policy coupons_self_select
on public.coupons
for select
to authenticated
using (
  active = true
  and (expires_at is null or expires_at > now())
  and organization_id in (
    select organization_id from public.customers where profile_id = auth.uid()
  )
);

-- This customer's own recipient rows (opened_at/booked_at tracking is
-- business-side only — this policy grants no write access).
create policy campaign_recipients_self_select
on public.campaign_recipients
for select
to authenticated
using (
  exists (
    select 1 from public.customers c
    where c.id = campaign_recipients.customer_id and c.profile_id = auth.uid()
  )
);

-- The campaign content (name/message/channel) for campaigns this customer
-- was actually sent — not every campaign at a business they patronize.
create policy campaigns_self_select
on public.campaigns
for select
to authenticated
using (
  exists (
    select 1
    from public.campaign_recipients cr
    join public.customers c on c.id = cr.customer_id
    where cr.campaign_id = campaigns.id and c.profile_id = auth.uid()
  )
);
