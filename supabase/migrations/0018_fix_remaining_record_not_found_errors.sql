-- Same latent bug as 0017 (RECORD variable stays "unassigned" rather than
-- null on a zero-row SELECT INTO, so `if x.id is null` raises Postgres
-- error 55000 instead of the intended clean exception), found by
-- systematically grepping every `<name> record;` declaration across all
-- migrations after finding it live in cancel_appointment/
-- reschedule_appointment. Three more functions have the identical pattern:
-- reverse_payment (nonexistent payment id), redeem_coupon (nonexistent/
-- inactive code), send_campaign (nonexistent campaign id). Fixed the same
-- way: check PL/pgSQL's `FOUND` immediately after the SELECT INTO.
-- Run after 0001..0017.

create or replace function public.reverse_payment(
  p_original_payment uuid,
  p_reason text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  p record;
  v_id uuid;
begin

  select * into p from public.payments where id = p_original_payment for update;

  if not found then
    raise exception 'PAYMENT_NOT_FOUND';
  end if;

  if not public.has_org_role(p.organization_id, array['owner', 'manager']) then
    raise exception 'FORBIDDEN';
  end if;

  if p.status <> 'completed' then
    raise exception 'PAYMENT_NOT_COMPLETED';
  end if;

  select x.id into v_id from public.payments x where x.reversed_payment_id = p_original_payment limit 1;

  if v_id is not null then
    return v_id;
  end if;

  insert into public.payments (
    organization_id, appointment_id, amount_minor, method, type, status, idempotency_key, reversed_payment_id, created_by
  )
  values (
    p.organization_id, p.appointment_id, -abs(p.amount_minor), p.method, 'refund', 'completed',
    gen_random_uuid()::text, p_original_payment, auth.uid()
  )
  returning id into v_id;

  insert into public.audit_logs (organization_id, user_id, action, entity, entity_id, new_data)
  values (p.organization_id, auth.uid(), 'refund', 'payment', p_original_payment, jsonb_build_object('refund_payment_id', v_id, 'reason', p_reason));

  return v_id;

end;
$$;

grant execute on function public.reverse_payment(uuid, text) to authenticated;


create or replace function public.redeem_coupon(
  p_org uuid,
  p_code text,
  p_customer uuid default null,
  p_appointment uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  cpn record;
  v_redemption uuid;
begin

  if not public.has_org_role(p_org, array['owner','manager','receptionist']) then
    raise exception 'FORBIDDEN';
  end if;

  select * into cpn
  from public.coupons
  where organization_id = p_org and code = upper(trim(p_code)) and active = true
  for update;

  if not found then
    raise exception 'COUPON_NOT_FOUND';
  end if;

  if cpn.expires_at is not null and cpn.expires_at < now() then raise exception 'COUPON_EXPIRED'; end if;
  if cpn.usage_limit is not null and cpn.usage_count >= cpn.usage_limit then raise exception 'COUPON_LIMIT_REACHED'; end if;

  update public.coupons set usage_count = usage_count + 1 where id = cpn.id;

  insert into public.coupon_redemptions(organization_id, coupon_id, customer_id, appointment_id, created_by)
  values (p_org, cpn.id, p_customer, p_appointment, auth.uid())
  returning id into v_redemption;

  insert into public.audit_logs(organization_id, user_id, action, entity, entity_id, new_data)
  values (p_org, auth.uid(), 'redeem', 'coupon', cpn.id, jsonb_build_object('redemption_id', v_redemption, 'customer_id', p_customer));

  return jsonb_build_object(
    'redemption_id', v_redemption,
    'coupon_id', cpn.id,
    'discount_percent', cpn.discount_percent,
    'discount_minor', cpn.discount_minor
  );

end;
$$;

grant execute on function public.redeem_coupon(uuid, text, uuid, uuid) to authenticated;


create or replace function public.send_campaign(p_campaign uuid)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  c record;
  v_queued int := 0;
begin

  select * into c from public.campaigns where id = p_campaign;

  if not found then
    raise exception 'CAMPAIGN_NOT_FOUND';
  end if;

  if not public.has_org_role(c.organization_id, array['owner','manager']) then
    raise exception 'FORBIDDEN';
  end if;

  if c.sent_at is not null then return 0; end if;

  if not exists(select 1 from public.campaign_recipients where campaign_id = p_campaign) then
    perform public.generate_campaign_recipients(p_campaign);
  end if;

  if c.channel = 'push' then
    insert into public.notification_jobs(organization_id, campaign_id, recipient_customer_id, kind, title, body, scheduled_for)
    select c.organization_id, p_campaign, cr.customer_id, 'campaign', c.name, c.message, now()
    from public.campaign_recipients cr
    where cr.campaign_id = p_campaign
    on conflict (campaign_id, recipient_customer_id) where campaign_id is not null do nothing;

    get diagnostics v_queued = row_count;
  else
    select count(*) into v_queued from public.campaign_recipients where campaign_id = p_campaign;
  end if;

  update public.campaigns set status = 'sent', sent_at = now() where id = p_campaign;

  insert into public.audit_logs(organization_id, user_id, action, entity, entity_id, new_data)
  values (c.organization_id, auth.uid(), 'send', 'campaign', p_campaign, jsonb_build_object('channel', c.channel, 'queued', v_queued));

  return v_queued;

end;
$$;

grant execute on function public.send_campaign(uuid) to authenticated;
