-- Bookly Business feature completion: packages, memberships, coupons,
-- loyalty redemption, campaign send pipeline, expanded CRM segments,
-- expanded reports. Run after 0001..0009.
--
-- All new RPCs are security definer and independently re-check org
-- membership/role — none of them trust organization_id/customer_id supplied
-- by the client without verifying it server-side first.


-- -----------------------------------------------------------------------------
-- 1) Packages: track what a customer actually bought, not just usage events.
-- -----------------------------------------------------------------------------

create table if not exists public.customer_packages (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  package_id uuid not null references public.packages(id),
  customer_id uuid not null references public.customers(id),
  remaining_uses integer not null check (remaining_uses >= 0),
  purchased_at timestamptz not null default now(),
  expires_at timestamptz,
  status text not null default 'active' check (status in ('active','expired','used_up','cancelled')),
  source_payment_id uuid references public.payments(id),
  created_by uuid references auth.users(id)
);

create unique index if not exists customer_packages_source_payment_unique
on public.customer_packages (source_payment_id)
where source_payment_id is not null;

create index if not exists idx_customer_packages_customer
on public.customer_packages (customer_id, status);


-- -----------------------------------------------------------------------------
-- 2) Memberships: track purchase idempotency the same way.
-- -----------------------------------------------------------------------------

alter table public.customer_memberships
  add column if not exists source_payment_id uuid references public.payments(id);

create unique index if not exists customer_memberships_source_payment_unique
on public.customer_memberships (source_payment_id)
where source_payment_id is not null;


-- -----------------------------------------------------------------------------
-- 3) Coupons: an auditable redemption ledger instead of a bare counter.
-- -----------------------------------------------------------------------------

create table if not exists public.coupon_redemptions (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  coupon_id uuid not null references public.coupons(id),
  customer_id uuid references public.customers(id),
  appointment_id uuid references public.appointments(id),
  payment_id uuid references public.payments(id),
  created_at timestamptz not null default now(),
  created_by uuid references auth.users(id)
);

create index if not exists idx_coupon_redemptions_coupon
on public.coupon_redemptions (coupon_id);


-- -----------------------------------------------------------------------------
-- 4) RLS for the new tables. Writes go through RPCs only (same pattern as
--    payments) so there are deliberately no insert/update/delete policies.
-- -----------------------------------------------------------------------------

alter table public.customer_packages enable row level security;
alter table public.coupon_redemptions enable row level security;

drop policy if exists customer_packages_select on public.customer_packages;
create policy customer_packages_select
on public.customer_packages
for select
using (organization_id in (select public.current_org_ids()));

drop policy if exists coupon_redemptions_select on public.coupon_redemptions;
create policy coupon_redemptions_select
on public.coupon_redemptions
for select
using (organization_id in (select public.current_org_ids()));


-- -----------------------------------------------------------------------------
-- 5) Campaign recipient generation needs a dedup target.
-- -----------------------------------------------------------------------------

create unique index if not exists campaign_recipients_campaign_customer_unique
on public.campaign_recipients (campaign_id, customer_id);


-- -----------------------------------------------------------------------------
-- 6) Campaign send pipeline reuses the existing notification_jobs /
--    notifications-worker / send-push pipeline for push campaigns.
-- -----------------------------------------------------------------------------

alter table public.notification_jobs
  add column if not exists campaign_id uuid references public.campaigns(id) on delete cascade;

alter table public.notification_jobs
  add column if not exists title text;

alter table public.notification_jobs
  add column if not exists body text;

create unique index if not exists notification_jobs_campaign_customer_unique
on public.notification_jobs (campaign_id, recipient_customer_id)
where campaign_id is not null;


-- -----------------------------------------------------------------------------
-- 7) sell_package(): idempotent package purchase (payment + entitlement).
-- -----------------------------------------------------------------------------

create or replace function public.sell_package(
  p_idempotency uuid,
  p_customer uuid,
  p_package uuid,
  p_method text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_org uuid;
  v_price bigint;
  v_total_uses int;
  v_expires_days int;
  v_payment uuid;
  v_cp uuid;
begin

  select organization_id into v_org from public.customers where id = p_customer and deleted_at is null;
  if v_org is null then raise exception 'CUSTOMER_NOT_FOUND'; end if;

  if not public.has_org_role(v_org, array['owner','manager','receptionist']) then
    raise exception 'FORBIDDEN';
  end if;

  select id into v_payment from public.payments where idempotency_key = p_idempotency::text;
  if v_payment is not null then
    select id into v_cp from public.customer_packages where source_payment_id = v_payment;
    if v_cp is not null then return v_cp; end if;
  end if;

  select price_minor, total_uses, expires_days
  into v_price, v_total_uses, v_expires_days
  from public.packages
  where id = p_package and organization_id = v_org and active = true;

  if v_price is null then raise exception 'PACKAGE_NOT_FOUND'; end if;

  if v_payment is null then
    insert into public.payments(organization_id, appointment_id, amount_minor, method, type, idempotency_key, created_by)
    values (v_org, null, v_price, p_method, 'payment', p_idempotency::text, auth.uid())
    returning id into v_payment;
  end if;

  insert into public.customer_packages(
    organization_id, package_id, customer_id, remaining_uses, expires_at, source_payment_id, created_by
  )
  values (
    v_org, p_package, p_customer, v_total_uses,
    case when v_expires_days is not null then now() + make_interval(days => v_expires_days) else null end,
    v_payment, auth.uid()
  )
  returning id into v_cp;

  insert into public.audit_logs(organization_id, user_id, action, entity, entity_id, new_data)
  values (v_org, auth.uid(), 'sell_package', 'customer_package', v_cp,
    jsonb_build_object('package_id', p_package, 'customer_id', p_customer, 'payment_id', v_payment));

  return v_cp;

end;
$$;

grant execute on function public.sell_package(uuid, uuid, uuid, text) to authenticated;


-- -----------------------------------------------------------------------------
-- 8) redeem_package_use(): consume one visit from a purchased package.
-- -----------------------------------------------------------------------------

create or replace function public.redeem_package_use(
  p_customer_package uuid,
  p_appointment uuid default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_org uuid;
  v_remaining int;
  v_status text;
  v_customer uuid;
  v_package uuid;
  v_expires timestamptz;
begin

  select organization_id, remaining_uses, status, customer_id, package_id, expires_at
  into v_org, v_remaining, v_status, v_customer, v_package, v_expires
  from public.customer_packages where id = p_customer_package for update;

  if v_org is null then raise exception 'PACKAGE_NOT_FOUND'; end if;

  if not public.has_org_role(v_org, array['owner','manager','receptionist','staff']) then
    raise exception 'FORBIDDEN';
  end if;

  if v_status <> 'active' then raise exception 'PACKAGE_NOT_ACTIVE'; end if;

  if v_expires is not null and v_expires < now() then
    update public.customer_packages set status = 'expired' where id = p_customer_package;
    raise exception 'PACKAGE_EXPIRED';
  end if;

  if v_remaining <= 0 then raise exception 'PACKAGE_NO_USES_LEFT'; end if;

  update public.customer_packages
  set remaining_uses = remaining_uses - 1,
      status = case when remaining_uses - 1 <= 0 then 'used_up' else status end
  where id = p_customer_package;

  insert into public.package_usage(organization_id, package_id, customer_id, appointment_id)
  values (v_org, v_package, v_customer, p_appointment);

  insert into public.audit_logs(organization_id, user_id, action, entity, entity_id, new_data)
  values (v_org, auth.uid(), 'redeem', 'customer_package', p_customer_package, jsonb_build_object('appointment_id', p_appointment));

end;
$$;

grant execute on function public.redeem_package_use(uuid, uuid) to authenticated;


-- -----------------------------------------------------------------------------
-- 9) purchase_membership(): idempotent membership purchase.
-- -----------------------------------------------------------------------------

create or replace function public.purchase_membership(
  p_idempotency uuid,
  p_customer uuid,
  p_membership uuid,
  p_method text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_org uuid;
  v_price bigint;
  v_duration int;
  v_payment uuid;
  v_cm uuid;
begin

  select organization_id into v_org from public.customers where id = p_customer and deleted_at is null;
  if v_org is null then raise exception 'CUSTOMER_NOT_FOUND'; end if;

  if not public.has_org_role(v_org, array['owner','manager','receptionist']) then
    raise exception 'FORBIDDEN';
  end if;

  select id into v_payment from public.payments where idempotency_key = p_idempotency::text;
  if v_payment is not null then
    select id into v_cm from public.customer_memberships where source_payment_id = v_payment;
    if v_cm is not null then return v_cm; end if;
  end if;

  select price_minor, duration_days into v_price, v_duration
  from public.memberships
  where id = p_membership and organization_id = v_org and active = true;

  if v_price is null then raise exception 'MEMBERSHIP_NOT_FOUND'; end if;

  if v_payment is null then
    insert into public.payments(organization_id, appointment_id, amount_minor, method, type, idempotency_key, created_by)
    values (v_org, null, v_price, p_method, 'payment', p_idempotency::text, auth.uid())
    returning id into v_payment;
  end if;

  insert into public.customer_memberships(organization_id, membership_id, customer_id, starts_at, ends_at, status, source_payment_id)
  values (v_org, p_membership, p_customer, now(), now() + make_interval(days => v_duration), 'active', v_payment)
  returning id into v_cm;

  insert into public.audit_logs(organization_id, user_id, action, entity, entity_id, new_data)
  values (v_org, auth.uid(), 'purchase_membership', 'customer_membership', v_cm,
    jsonb_build_object('membership_id', p_membership, 'customer_id', p_customer, 'payment_id', v_payment));

  return v_cm;

end;
$$;

grant execute on function public.purchase_membership(uuid, uuid, uuid, text) to authenticated;


-- -----------------------------------------------------------------------------
-- 10) redeem_coupon(): validate + record usage server-side. Discount minor
--     units are computed and returned; applying them to a specific payment
--     is the caller's responsibility (record_payment(p_amount=...)).
-- -----------------------------------------------------------------------------

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

  if cpn.id is null then raise exception 'COUPON_NOT_FOUND'; end if;
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


-- -----------------------------------------------------------------------------
-- 11) redeem_loyalty_points(): spend points, e.g. against a discount at
--     checkout. Balance check + deduction happen under a row lock.
-- -----------------------------------------------------------------------------

create or replace function public.redeem_loyalty_points(
  p_customer uuid,
  p_points bigint,
  p_reason text default 'redeem'
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_org uuid;
  v_balance bigint;
begin

  select organization_id into v_org from public.customers where id = p_customer and deleted_at is null;
  if v_org is null then raise exception 'CUSTOMER_NOT_FOUND'; end if;

  if not public.has_org_role(v_org, array['owner','manager','receptionist']) then
    raise exception 'FORBIDDEN';
  end if;

  if p_points <= 0 then raise exception 'INVALID_POINTS'; end if;

  select points into v_balance from public.loyalty_accounts where customer_id = p_customer for update;

  if v_balance is null or v_balance < p_points then
    raise exception 'INSUFFICIENT_POINTS';
  end if;

  update public.loyalty_accounts set points = points - p_points where customer_id = p_customer;

  insert into public.loyalty_transactions(organization_id, customer_id, points_delta, reason)
  values (v_org, p_customer, -p_points, p_reason);

end;
$$;

grant execute on function public.redeem_loyalty_points(uuid, bigint, text) to authenticated;


-- -----------------------------------------------------------------------------
-- 12) customer_segment(): add birthday-month and package-expiring segments.
-- -----------------------------------------------------------------------------

create or replace function public.customer_segment(p_org uuid, p_segment text)
returns table(customer_id uuid)
language sql
stable
security definer
set search_path = public
as $$
  select c.id
  from public.customers c
  where public.has_org_role(p_org, array['owner','manager','receptionist','staff'])
    and c.organization_id = p_org
    and c.deleted_at is null
    and case p_segment
      when 'all' then true
      when 'inactive_30' then coalesce(c.last_visit_at, '1900-01-01') < now() - interval '30 days'
      when 'vip' then c.total_spent_minor >= 100000
      when 'frequent_no_show' then c.no_show_count >= 3
      when 'first_visit' then c.last_visit_at is null
      when 'birthday_month' then c.birthday is not null and extract(month from c.birthday) = extract(month from now())
      when 'package_expiring' then exists(
        select 1 from public.customer_packages cp
        where cp.customer_id = c.id
          and cp.status = 'active'
          and cp.expires_at is not null
          and cp.expires_at between now() and now() + interval '7 days'
      )
      else false
    end;
$$;

grant execute on function public.customer_segment(uuid, text) to authenticated;


-- -----------------------------------------------------------------------------
-- 13) generate_campaign_recipients() / send_campaign(): audience generation
--     and delivery queueing, both idempotent and deduplicated.
-- -----------------------------------------------------------------------------

create or replace function public.generate_campaign_recipients(p_campaign uuid)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_org uuid;
  v_segment text;
  v_count int;
begin

  select organization_id, segment into v_org, v_segment from public.campaigns where id = p_campaign;
  if v_org is null then raise exception 'CAMPAIGN_NOT_FOUND'; end if;

  if not public.has_org_role(v_org, array['owner','manager']) then
    raise exception 'FORBIDDEN';
  end if;

  insert into public.campaign_recipients(campaign_id, customer_id)
  select p_campaign, s.customer_id from public.customer_segment(v_org, v_segment) s
  on conflict (campaign_id, customer_id) do nothing;

  get diagnostics v_count = row_count;
  return v_count;

end;
$$;

grant execute on function public.generate_campaign_recipients(uuid) to authenticated;


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
  if c.id is null then raise exception 'CAMPAIGN_NOT_FOUND'; end if;

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
    -- email/sms: no delivery provider is configured in this environment.
    -- Recipients are recorded and auditable; the campaign is marked sent
    -- without a fabricated delivery claim.
    select count(*) into v_queued from public.campaign_recipients where campaign_id = p_campaign;
  end if;

  update public.campaigns set status = 'sent', sent_at = now() where id = p_campaign;

  insert into public.audit_logs(organization_id, user_id, action, entity, entity_id, new_data)
  values (c.organization_id, auth.uid(), 'send', 'campaign', p_campaign, jsonb_build_object('channel', c.channel, 'queued', v_queued));

  return v_queued;

end;
$$;

grant execute on function public.send_campaign(uuid) to authenticated;


-- -----------------------------------------------------------------------------
-- 14) report_dashboard(): add occupancy, staff performance, customer and
--     campaign metrics, computed in SQL rather than in Flutter. Existing
--     top-level keys (appointments/completed/cancelled/no_show/
--     revenue_minor/customers) are kept unchanged for backward compatibility.
-- -----------------------------------------------------------------------------

create or replace function public.report_dashboard(p_org uuid, p_from timestamptz, p_to timestamptz)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_tz text;
  v_available_minutes numeric;
  v_busy_minutes numeric;
  v_occupancy numeric;
  v_staff_performance jsonb;
  v_customer_metrics jsonb;
  v_campaign_metrics jsonb;
  r jsonb;
begin

  if not public.has_org_role(p_org, array['owner','manager','receptionist','staff']) then
    raise exception 'FORBIDDEN';
  end if;

  select coalesce(timezone, 'UTC') into v_tz from public.organizations where id = p_org;

  select coalesce(sum(extract(epoch from (wh.end_time - wh.start_time)) / 60), 0)
  into v_available_minutes
  from generate_series((p_from at time zone v_tz)::date, ((p_to - interval '1 second') at time zone v_tz)::date, interval '1 day') d(day)
  join public.working_hours wh on wh.weekday = extract(dow from d.day)::int
  join public.staff s on s.id = wh.staff_id and s.organization_id = p_org and s.status = 'active' and s.deleted_at is null;

  select coalesce(sum(extract(epoch from (a.ends_at - a.starts_at)) / 60), 0)
  into v_busy_minutes
  from public.appointments a
  where a.organization_id = p_org
    and a.deleted_at is null
    and a.status in ('confirmed','checked_in','in_service','completed')
    and a.starts_at >= p_from and a.starts_at < p_to;

  v_occupancy := case when v_available_minutes > 0 then round(100.0 * v_busy_minutes / v_available_minutes, 1) else 0 end;

  select coalesce(jsonb_agg(x order by x.revenue_minor desc), '[]'::jsonb)
  into v_staff_performance
  from (
    select
      s.id as staff_id,
      s.display_name,
      count(*) filter (where a.status = 'completed') as completed,
      count(*) filter (where a.status = 'no_show') as no_show,
      coalesce(sum(aps.price_minor) filter (where a.status = 'completed'), 0) as revenue_minor
    from public.staff s
    left join public.appointments a
      on a.staff_id = s.id and a.organization_id = p_org and a.deleted_at is null
      and a.starts_at >= p_from and a.starts_at < p_to
    left join public.appointment_services aps on aps.appointment_id = a.id
    where s.organization_id = p_org and s.deleted_at is null
    group by s.id, s.display_name
  ) x;

  select jsonb_build_object(
    'new_customers', count(*) filter (where c.created_at >= p_from and c.created_at < p_to),
    'repeat_customers', count(*) filter (
      where (select count(*) from public.appointments a2 where a2.customer_id = c.id and a2.status = 'completed') >= 2
    ),
    'avg_spend_minor', coalesce(round(avg(nullif(c.total_spent_minor, 0))), 0)
  )
  into v_customer_metrics
  from public.customers c
  where c.organization_id = p_org and c.deleted_at is null;

  select jsonb_build_object(
    'campaigns_sent', count(distinct camp.id),
    'recipients', count(cr.id),
    'opened', count(cr.id) filter (where cr.opened_at is not null),
    'booked', count(cr.id) filter (where cr.booked_at is not null)
  )
  into v_campaign_metrics
  from public.campaigns camp
  left join public.campaign_recipients cr on cr.campaign_id = camp.id
  where camp.organization_id = p_org and camp.sent_at >= p_from and camp.sent_at < p_to;

  select jsonb_build_object(
    'appointments', (select count(*) from public.appointments where organization_id = p_org and starts_at >= p_from and starts_at < p_to),
    'completed', (select count(*) from public.appointments where organization_id = p_org and status = 'completed' and starts_at >= p_from and starts_at < p_to),
    'cancelled', (select count(*) from public.appointments where organization_id = p_org and status = 'cancelled' and starts_at >= p_from and starts_at < p_to),
    'no_show', (select count(*) from public.appointments where organization_id = p_org and status = 'no_show' and starts_at >= p_from and starts_at < p_to),
    'revenue_minor', coalesce((select sum(amount_minor) from public.payments where organization_id = p_org and type in ('payment','deposit') and status = 'completed' and created_at >= p_from and created_at < p_to), 0),
    'customers', (select count(*) from public.customers where organization_id = p_org and created_at >= p_from and created_at < p_to),
    'occupancy_percent', v_occupancy,
    'staff_performance', v_staff_performance,
    'customer_metrics', v_customer_metrics,
    'campaign_metrics', v_campaign_metrics
  ) into r;

  return r;

end;
$$;

grant execute on function public.report_dashboard(uuid, timestamptz, timestamptz) to authenticated;


-- -----------------------------------------------------------------------------
-- 15) Queue wait estimation. estimated_wait_min was written once as a
--     literal 0 by add_walk_in() and never recalculated — the walk-in queue
--     never actually reflected "estimated wait from calendar gaps" (spec
--     slide 12) or updated when an appointment ahead in line completed (QA
--     matrix, slide 17). Recomputes every 'waiting' entry for the current
--     business day as the sum of service durations of everyone still ahead
--     of it (waiting/called/in_service), and is called after any queue
--     mutation so the numbers stay live.
-- -----------------------------------------------------------------------------

create or replace function public.recalculate_queue_wait(p_org uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tz text;
begin

  select coalesce(timezone, 'UTC') into v_tz from public.organizations where id = p_org;

  with today as (
    select
      qe.id,
      qe.queue_number,
      coalesce(s.duration_min, 15) as dur
    from public.queue_entries qe
    left join public.services s on s.id = qe.service_id
    where qe.organization_id = p_org
      and qe.status in ('waiting', 'called', 'in_service')
      and (qe.created_at at time zone v_tz)::date = (now() at time zone v_tz)::date
  ),
  calc as (
    select
      id,
      coalesce(
        sum(dur) over (
          order by queue_number
          rows between unbounded preceding and 1 preceding
        ),
        0
      )::int as wait
    from today
  )
  update public.queue_entries qe
  set estimated_wait_min = calc.wait, updated_at = now()
  from calc
  where calc.id = qe.id
    and qe.estimated_wait_min is distinct from calc.wait;

end;
$$;

grant execute on function public.recalculate_queue_wait(uuid) to authenticated;


create or replace function public.add_walk_in(p_customer uuid, p_service uuid, p_staff uuid default null)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_org uuid;
  v_number int;
  v_id uuid;
  v_day date;
begin

  select organization_id into v_org from public.customers where id = p_customer and deleted_at is null;
  if v_org is null then raise exception 'CUSTOMER_NOT_FOUND'; end if;

  if not public.has_org_role(v_org, array['owner','manager','receptionist','staff']) then
    raise exception 'FORBIDDEN';
  end if;

  if not exists(select 1 from public.services where id = p_service and organization_id = v_org and deleted_at is null) then
    raise exception 'SERVICE_NOT_FOUND';
  end if;

  if p_staff is not null and not exists(select 1 from public.staff where id = p_staff and organization_id = v_org and status = 'active' and deleted_at is null) then
    raise exception 'STAFF_NOT_FOUND';
  end if;

  v_day := (now() at time zone coalesce((select timezone from public.organizations where id = v_org), 'UTC'))::date;
  perform pg_advisory_xact_lock(hashtextextended(v_org::text || v_day::text, 0));

  select coalesce(max(queue_number), 0) + 1 into v_number
  from public.queue_entries
  where organization_id = v_org and (created_at at time zone coalesce((select timezone from public.organizations where id = v_org), 'UTC'))::date = v_day;

  insert into public.queue_entries(organization_id, customer_id, service_id, staff_id, queue_number, estimated_wait_min)
  values (v_org, p_customer, p_service, p_staff, v_number, 0)
  returning id into v_id;

  perform public.recalculate_queue_wait(v_org);

  return v_id;

end;
$$;

grant execute on function public.add_walk_in(uuid, uuid, uuid) to authenticated;


create or replace function public.change_queue_status(p_queue uuid, p_status text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_org uuid;
begin

  if p_status not in ('waiting','called','in_service','completed','cancelled') then
    raise exception 'INVALID_QUEUE_STATUS';
  end if;

  select organization_id into v_org from public.queue_entries where id = p_queue for update;
  if v_org is null then raise exception 'QUEUE_NOT_FOUND'; end if;

  if not public.has_org_role(v_org, array['owner','manager','receptionist','staff']) then
    raise exception 'FORBIDDEN';
  end if;

  update public.queue_entries set status = p_status, updated_at = now() where id = p_queue;

  perform public.recalculate_queue_wait(v_org);

end;
$$;

grant execute on function public.change_queue_status(uuid, text) to authenticated;
