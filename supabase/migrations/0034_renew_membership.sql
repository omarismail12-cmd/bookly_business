-- renew_membership(): extends an existing customer_memberships row in
-- place (carrying over any remaining time), instead of creating a new row
-- the way purchase_membership() does for a first-time sale.
--
-- new ends_at = greatest(now(), current ends_at) + duration_days
--   — renewing before expiry adds the full new term on top of what's
--     left; renewing after expiry starts the new term from today instead
--     of backdating it onto the already-passed end date.
--
-- There is no distinct "expired" status in this schema — customer_memberships
-- only ever has status 'active' or 'cancelled' (see 0003_crm_loyalty.sql /
-- purchase_membership()); an expired-but-not-cancelled membership is still
-- 'active' with an ends_at in the past. So the only state this function
-- refuses to renew is 'cancelled' — a cancelled membership must go through
-- purchase_membership() again (Sell membership) for a fresh start, not a
-- silent reactivation via renew.
--
-- Idempotent the same way sell_package()/purchase_membership() are: a
-- retried call with the same p_idempotency reuses the existing payment
-- row, and — since renew_membership updates a row in place rather than
-- creating a new one to key an idempotency check off of the way those two
-- functions do — checks audit_logs for a prior renew_membership entry tied
-- to that same payment before applying the ends_at extension again.

create or replace function public.renew_membership(
  p_idempotency uuid,
  p_customer_membership uuid,
  p_method text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_org uuid;
  v_membership uuid;
  v_customer uuid;
  v_status text;
  v_current_ends timestamptz;
  v_price bigint;
  v_duration int;
  v_payment uuid;
  v_new_ends timestamptz;
begin

  select organization_id, membership_id, customer_id, status, ends_at
  into v_org, v_membership, v_customer, v_status, v_current_ends
  from public.customer_memberships
  where id = p_customer_membership
  for update;

  if v_org is null then raise exception 'MEMBERSHIP_NOT_FOUND'; end if;

  if not public.has_org_role(v_org, array['owner','manager','receptionist']) then
    raise exception 'FORBIDDEN';
  end if;

  if v_status = 'cancelled' then
    raise exception 'MEMBERSHIP_CANCELLED';
  end if;

  select id into v_payment from public.payments where idempotency_key = p_idempotency::text;
  if v_payment is not null then
    if exists (
      select 1 from public.audit_logs
      where organization_id = v_org
        and action = 'renew_membership'
        and entity = 'customer_membership'
        and entity_id = p_customer_membership
        and (new_data->>'payment_id')::uuid = v_payment
    ) then
      return p_customer_membership;
    end if;
  end if;

  select price_minor, duration_days into v_price, v_duration
  from public.memberships
  where id = v_membership and organization_id = v_org and active = true;

  if v_price is null then raise exception 'MEMBERSHIP_NOT_FOUND'; end if;

  if v_payment is null then
    insert into public.payments(organization_id, appointment_id, amount_minor, method, type, idempotency_key, created_by)
    values (v_org, null, v_price, p_method, 'payment', p_idempotency::text, auth.uid())
    returning id into v_payment;
  end if;

  v_new_ends := greatest(now(), v_current_ends) + make_interval(days => v_duration);

  update public.customer_memberships
  set ends_at = v_new_ends,
      status = 'active'
  where id = p_customer_membership;

  insert into public.audit_logs(organization_id, user_id, action, entity, entity_id, new_data)
  values (v_org, auth.uid(), 'renew_membership', 'customer_membership', p_customer_membership,
    jsonb_build_object(
      'membership_id', v_membership,
      'customer_id', v_customer,
      'payment_id', v_payment,
      'new_ends_at', v_new_ends
    ));

  return p_customer_membership;

end;
$$;

grant execute on function public.renew_membership(uuid, uuid, text) to authenticated;

-- Supabase's platform grants EXECUTE on every new function straight to
-- anon at creation time (see 0016_revoke_anon_from_business_functions.sql
-- for the full explanation) — ALTER DEFAULT PRIVILEGES from 0015 only
-- covers the PUBLIC pseudo-role, not this. Not currently exploitable
-- either way (has_org_role() rejects an anon caller before this function
-- does anything, same as every other business RPC), but this writes a
-- payment and mutates membership state, so it gets the explicit revoke
-- rather than relying on that check forever.
revoke execute on function public.renew_membership(uuid, uuid, text) from anon;
