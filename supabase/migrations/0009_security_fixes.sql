-- Bookly Business security + correctness fixes.
-- Run after 0001..0008.
--
-- Fixes, all verified against the current migration history:
-- 1) customer_segment() leaked customer IDs cross-tenant (no org/role check).
-- 2) award_loyalty_for_payment() was exploitable cross-tenant and non-idempotent,
--    and was never actually called from the payment flow.
-- 3) reverse_payment() referenced payments.notes, a column that has never existed,
--    so refunds crashed at runtime. Replaced the notes/LIKE tracking with a proper
--    reversed_payment_id column.
-- 4) change_appointment_status() let any staff member change any appointment in the
--    org, inconsistent with the appointments_select policy that scopes staff to their
--    own appointments.
-- 5) create_booking() did not schedule notification jobs atomically, unlike
--    create_public_booking().


-- -----------------------------------------------------------------------------
-- 1) Idempotent, traceable payment reversal.
-- -----------------------------------------------------------------------------

alter table public.payments
  add column if not exists reversed_payment_id uuid references public.payments(id);

create unique index if not exists payments_reversed_payment_id_unique
on public.payments (reversed_payment_id)
where reversed_payment_id is not null;


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

  select *
  into p
  from public.payments
  where id = p_original_payment
  for update;

  if p.id is null then
    raise exception 'PAYMENT_NOT_FOUND';
  end if;

  if not public.has_org_role(
    p.organization_id,
    array['owner', 'manager']
  ) then
    raise exception 'FORBIDDEN';
  end if;

  if p.status <> 'completed' then
    raise exception 'PAYMENT_NOT_COMPLETED';
  end if;

  select x.id
  into v_id
  from public.payments x
  where x.reversed_payment_id = p_original_payment
  limit 1;

  if v_id is not null then
    return v_id;
  end if;

  insert into public.payments (
    organization_id,
    appointment_id,
    amount_minor,
    method,
    type,
    status,
    idempotency_key,
    reversed_payment_id,
    created_by
  )
  values (
    p.organization_id,
    p.appointment_id,
    -abs(p.amount_minor),
    p.method,
    'refund',
    'completed',
    gen_random_uuid()::text,
    p_original_payment,
    auth.uid()
  )
  returning id into v_id;

  insert into public.audit_logs (
    organization_id,
    user_id,
    action,
    entity,
    entity_id,
    new_data
  )
  values (
    p.organization_id,
    auth.uid(),
    'refund',
    'payment',
    p_original_payment,
    jsonb_build_object(
      'refund_payment_id',
      v_id,
      'reason',
      p_reason
    )
  );

  return v_id;

end;
$$;

grant execute on function
public.reverse_payment(uuid, text)
to authenticated;


-- -----------------------------------------------------------------------------
-- 2) customer_segment(): require org membership. Previously any authenticated
--    user could pass an arbitrary organization_id and enumerate its customer IDs.
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
      when 'inactive_30' then coalesce(c.last_visit_at, '1900-01-01') < now() - interval '30 days'
      when 'vip' then c.total_spent_minor >= 100000
      when 'frequent_no_show' then c.no_show_count >= 3
      when 'first_visit' then c.last_visit_at is null
      else false
    end;
$$;

grant execute on function
public.customer_segment(uuid, text)
to authenticated;


-- -----------------------------------------------------------------------------
-- 3) award_loyalty_for_payment(): require org membership, make idempotent via
--    loyalty_transactions.source_payment_id, and call it automatically from
--    record_payment() so loyalty actually accrues during normal checkout.
-- -----------------------------------------------------------------------------

alter table public.loyalty_transactions
  add column if not exists source_payment_id uuid references public.payments(id);

create unique index if not exists loyalty_transactions_source_payment_unique
on public.loyalty_transactions (source_payment_id)
where source_payment_id is not null;


create or replace function public.award_loyalty_for_payment(p_payment uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_org uuid;
  v_customer uuid;
  v_amount bigint;
  v_points bigint;
begin

  select p.organization_id, a.customer_id, p.amount_minor
  into v_org, v_customer, v_amount
  from public.payments p
  join public.appointments a on a.id = p.appointment_id
  where p.id = p_payment
    and p.type = 'payment'
    and p.status = 'completed';

  if v_org is null then
    return;
  end if;

  if not public.has_org_role(v_org, array['owner','manager','receptionist']) then
    raise exception 'FORBIDDEN';
  end if;

  if exists (
    select 1 from public.loyalty_transactions where source_payment_id = p_payment
  ) then
    return;
  end if;

  v_points := floor(v_amount / 100);

  insert into public.loyalty_accounts(organization_id, customer_id, points)
  values (v_org, v_customer, v_points)
  on conflict(customer_id) do update set points = loyalty_accounts.points + excluded.points;

  insert into public.loyalty_transactions(
    organization_id, customer_id, points_delta, reason, appointment_id, source_payment_id
  )
  select v_org, v_customer, v_points, 'spend', appointment_id, p_payment
  from public.payments
  where id = p_payment;

end;
$$;

grant execute on function
public.award_loyalty_for_payment(uuid)
to authenticated;


create or replace function public.record_payment(
  p_idempotency uuid,
  p_appointment uuid,
  p_amount bigint,
  p_method text,
  p_type text default 'payment'
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_payment uuid;
  v_org uuid;
begin

  if p_amount <= 0 then
    raise exception 'INVALID_AMOUNT';
  end if;

  select organization_id into v_org from public.appointments where id = p_appointment;

  if v_org is null then
    raise exception 'APPOINTMENT_NOT_FOUND';
  end if;

  if not public.has_org_role(v_org, array['owner','manager','receptionist']) then
    raise exception 'FORBIDDEN';
  end if;

  select id into v_payment from public.payments where idempotency_key = p_idempotency::text;

  if v_payment is not null then
    return v_payment;
  end if;

  insert into public.payments(
    organization_id, appointment_id, amount_minor, method, type, idempotency_key, created_by
  )
  values (v_org, p_appointment, p_amount, p_method, p_type, p_idempotency::text, auth.uid())
  returning id into v_payment;

  if p_type = 'deposit' then
    update public.appointments set deposit_paid_minor = deposit_paid_minor + p_amount where id = p_appointment;
  end if;

  if p_type = 'payment' then
    perform public.award_loyalty_for_payment(v_payment);
  end if;

  insert into public.audit_logs(organization_id, user_id, action, entity, entity_id, new_data)
  values (v_org, auth.uid(), 'payment', 'payment', v_payment, jsonb_build_object('amount_minor', p_amount, 'type', p_type));

  return v_payment;

end;
$$;

grant execute on function
public.record_payment(uuid, uuid, bigint, text, text)
to authenticated;


-- -----------------------------------------------------------------------------
-- 4) change_appointment_status(): staff may only transition their own
--    appointments. owner/manager/receptionist are unrestricted, matching the
--    appointments_select policy already scoped this way (0007).
-- -----------------------------------------------------------------------------

create or replace function public.change_appointment_status(p_appointment uuid, p_status text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_org uuid;
  v_old text;
  v_customer uuid;
  v_staff uuid;
begin

  if p_status not in ('pending','confirmed','checked_in','in_service','completed','cancelled','no_show') then
    raise exception 'INVALID_STATUS';
  end if;

  select organization_id, status, customer_id, staff_id
  into v_org, v_old, v_customer, v_staff
  from public.appointments where id = p_appointment for update;

  if v_org is null then
    raise exception 'APPOINTMENT_NOT_FOUND';
  end if;

  if public.has_org_role(v_org, array['owner','manager','receptionist']) then
    -- full access
  elsif public.has_org_role(v_org, array['staff'])
    and exists(select 1 from public.staff s where s.id = v_staff and s.profile_id = auth.uid())
  then
    -- staff may only manage their own appointments
  else
    raise exception 'FORBIDDEN';
  end if;

  if v_old = p_status then
    return;
  end if;

  update public.appointments set status = p_status, updated_by = auth.uid() where id = p_appointment;

  if p_status = 'no_show' then
    update public.customers set no_show_count = no_show_count + 1, updated_at = now() where id = v_customer;
  end if;

  if p_status = 'completed' then
    update public.customers set last_visit_at = now(), updated_at = now() where id = v_customer;
  end if;

  insert into public.audit_logs(organization_id, user_id, action, entity, entity_id, old_data, new_data)
  values (v_org, auth.uid(), 'status_change', 'appointment', p_appointment, jsonb_build_object('status', v_old), jsonb_build_object('status', p_status));

end;
$$;

grant execute on function
public.change_appointment_status(uuid, text)
to authenticated;


-- -----------------------------------------------------------------------------
-- 5) create_booking(): schedule notification jobs atomically, matching
--    create_public_booking()'s pattern, instead of relying on a second
--    client-side RPC call that can fail independently.
-- -----------------------------------------------------------------------------

create or replace function public.create_booking(
  p_operation_id uuid,
  p_organization uuid,
  p_customer uuid,
  p_staff uuid,
  p_service uuid,
  p_starts_at timestamptz,
  p_source text default 'online',
  p_location uuid default null,
  p_notes text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
  v_end timestamptz;
  v_duration int;
  v_price bigint;
  v_deposit bigint;
  v_org uuid;
begin

  if auth.uid() is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;

  if not exists(select 1 from public.organization_members where organization_id = p_organization and user_id = auth.uid() and status = 'active') then
    raise exception 'FORBIDDEN';
  end if;

  if exists(select 1 from public.audit_logs where entity = 'booking_operation' and entity_id = p_operation_id) then
    select new_data->>'appointment_id' into v_id from public.audit_logs where entity = 'booking_operation' and entity_id = p_operation_id limit 1;
    return v_id;
  end if;

  select organization_id, duration_min, price_minor, deposit_required_minor
  into v_org, v_duration, v_price, v_deposit
  from public.services where id = p_service and deleted_at is null;

  if v_org <> p_organization then
    raise exception 'SERVICE_NOT_FOUND';
  end if;

  if not exists(select 1 from public.customers where id = p_customer and organization_id = p_organization and deleted_at is null) then
    raise exception 'CUSTOMER_NOT_FOUND';
  end if;

  if not exists(select 1 from public.staff where id = p_staff and organization_id = p_organization and status = 'active' and deleted_at is null) then
    raise exception 'STAFF_NOT_FOUND';
  end if;

  if not exists(select 1 from public.staff_services where staff_id = p_staff and service_id = p_service) then
    raise exception 'STAFF_CANNOT_PERFORM_SERVICE';
  end if;

  v_end := p_starts_at + make_interval(mins => v_duration);

  if not exists(
    select 1 from public.get_available_slots(
      p_staff, p_service,
      (p_starts_at at time zone coalesce((select timezone from public.organizations where id = p_organization), 'UTC'))::date,
      p_location
    ) s where s.starts_at = p_starts_at
  ) then
    raise exception 'SLOT_NOT_AVAILABLE';
  end if;

  insert into public.appointments(organization_id, customer_id, staff_id, location_id, status, starts_at, ends_at, source, deposit_required_minor, notes, created_by, updated_by)
  values (p_organization, p_customer, p_staff, p_location, 'confirmed', p_starts_at, v_end, p_source, v_deposit, p_notes, auth.uid(), auth.uid())
  returning id into v_id;

  insert into public.appointment_services(appointment_id, service_id, price_minor, duration_min)
  values (v_id, p_service, v_price, v_duration);

  perform public.queue_appointment_notifications(v_id);

  insert into public.audit_logs(organization_id, user_id, action, entity, entity_id, new_data)
  values (p_organization, auth.uid(), 'create', 'booking_operation', p_operation_id, jsonb_build_object('appointment_id', v_id));

  return v_id;

exception when exclusion_violation then
  raise exception 'SLOT_ALREADY_BOOKED';
end;
$$;

grant execute on function
public.create_booking(uuid, uuid, uuid, uuid, uuid, timestamptz, text, uuid, text)
to authenticated;
