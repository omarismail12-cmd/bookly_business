-- No-show deposit policy (spec: "Require deposit after threshold").
-- Run after 0001..0010.
--
-- Previously deposit_required_minor on a new appointment was always exactly
-- the service's configured deposit — a customer's no-show history had no
-- effect on booking at all, despite being tracked (customers.no_show_count)
-- and surfaced in the CRM "No-show risk" segment. This migration makes that
-- data actually do something: once a customer crosses the same threshold
-- already used for the frequent_no_show segment (customer_segment(), 0003),
-- a deposit is required even for services that don't normally ask for one.
--
-- Policy (a defensible default, not something the schema lets an owner
-- configure yet): no_show_count >= 3 and the service's own deposit is 0
-- -> require 50% of the service price as a deposit. This does not block
-- booking creation (deposits are tracked-and-due, same as today, collected
-- via record_payment/the Payments screen) — it only raises what's due,
-- exactly like a service-level deposit already does.

create or replace function public.effective_deposit_minor(
  p_customer uuid,
  p_service_deposit_minor bigint,
  p_price_minor bigint
)
returns bigint
language sql
stable
security definer
set search_path = public
as $$
  select case
    when p_service_deposit_minor > 0 then p_service_deposit_minor
    when coalesce((select no_show_count from public.customers where id = p_customer), 0) >= 3
      then ceil(p_price_minor * 0.5)
    else 0
  end;
$$;


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

  v_deposit := public.effective_deposit_minor(p_customer, v_deposit, v_price);

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


create or replace function public.create_public_booking(
  p_slug text, p_customer_name text, p_customer_email text, p_customer_phone text,
  p_service uuid, p_staff uuid, p_starts_at timestamptz, p_location uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_org uuid;
  v_customer uuid;
  v_id uuid;
  v_duration int;
  v_price bigint;
  v_deposit bigint;
  v_end timestamptz;
  v_tz text;
begin

  select id, timezone into v_org, v_tz from public.organizations where slug = p_slug and status = 'active' and deleted_at is null;
  if v_org is null then raise exception 'BUSINESS_NOT_FOUND'; end if;
  if length(trim(coalesce(p_customer_name, ''))) < 2 then raise exception 'CUSTOMER_NAME_REQUIRED'; end if;
  if p_customer_email is null and p_customer_phone is null then raise exception 'CUSTOMER_CONTACT_REQUIRED'; end if;

  select organization_id, duration_min, price_minor, deposit_required_minor into v_org, v_duration, v_price, v_deposit
  from public.services where id = p_service and organization_id = v_org and deleted_at is null;
  if v_duration is null then raise exception 'SERVICE_NOT_FOUND'; end if;

  if not exists(select 1 from public.staff where id = p_staff and organization_id = v_org and status = 'active' and deleted_at is null) then
    raise exception 'STAFF_NOT_FOUND';
  end if;
  if not exists(select 1 from public.staff_services where staff_id = p_staff and service_id = p_service) then
    raise exception 'STAFF_CANNOT_PERFORM_SERVICE';
  end if;

  v_end := p_starts_at + make_interval(mins => v_duration);
  if not exists(select 1 from public.get_available_slots(p_staff, p_service, (p_starts_at at time zone coalesce(v_tz, 'UTC'))::date, p_location) s where s.starts_at = p_starts_at) then
    raise exception 'SLOT_NOT_AVAILABLE';
  end if;

  select id into v_customer from public.customers
  where organization_id = v_org and deleted_at is null
    and ((p_customer_email is not null and lower(email) = lower(trim(p_customer_email)))
      or (p_customer_phone is not null and phone = trim(p_customer_phone)))
  order by created_at limit 1;

  if v_customer is null then
    insert into public.customers(organization_id, name, phone, email)
    values (v_org, trim(p_customer_name), nullif(trim(p_customer_phone), ''), nullif(trim(p_customer_email), ''))
    returning id into v_customer;
  else
    update public.customers
    set name = trim(p_customer_name),
        phone = coalesce(nullif(trim(p_customer_phone), ''), phone),
        email = coalesce(nullif(trim(p_customer_email), ''), email),
        updated_at = now()
    where id = v_customer;
  end if;

  v_deposit := public.effective_deposit_minor(v_customer, v_deposit, v_price);

  insert into public.appointments(organization_id, customer_id, staff_id, location_id, status, starts_at, ends_at, source, deposit_required_minor, notes)
  values (v_org, v_customer, p_staff, p_location, 'confirmed', p_starts_at, v_end, 'online', v_deposit, 'PUBLIC_BOOKING')
  returning id into v_id;

  insert into public.appointment_services(appointment_id, service_id, price_minor, duration_min)
  values (v_id, p_service, v_price, v_duration);

  perform public.queue_appointment_notifications(v_id);

  return v_id;

exception when exclusion_violation then
  raise exception 'SLOT_ALREADY_BOOKED';
end;
$$;

grant execute on function public.create_public_booking(text, text, text, text, uuid, uuid, timestamptz, uuid) to anon, authenticated;
