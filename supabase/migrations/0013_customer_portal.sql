-- Customer portal: link an authenticated Supabase Auth user to their
-- customer record(s) so they can see their own appointments, loyalty
-- balance, packages and memberships across any business they've booked
-- with — without being an organization_member anywhere (spec slide 5:
-- "Customer app/page ... My appointments, Loyalty/rewards, Offers").
-- Run after 0001..0012.

alter table public.customers
  add column if not exists profile_id uuid references public.profiles(id);

create unique index if not exists customers_org_profile_unique
on public.customers (organization_id, profile_id)
where profile_id is not null;

create index if not exists idx_customers_profile
on public.customers (profile_id)
where profile_id is not null;


-- -----------------------------------------------------------------------------
-- claim_customer_identity(): called once a customer portal user has an
-- authenticated session, to link (or create) their customer record for a
-- given business. Idempotent: safe to call again, always returns the same
-- linked customer id for that (org, user) pair. Matches by email/phone the
-- same way create_public_booking() already does, so a customer who booked
-- anonymously first and signs up later is linked to their existing history
-- instead of getting a duplicate record.
-- -----------------------------------------------------------------------------

create or replace function public.claim_customer_identity(
  p_org uuid,
  p_name text,
  p_email text default null,
  p_phone text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_customer uuid;
begin

  if auth.uid() is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;

  if not exists (select 1 from public.organizations where id = p_org and status = 'active' and deleted_at is null) then
    raise exception 'BUSINESS_NOT_FOUND';
  end if;

  select id into v_customer
  from public.customers
  where organization_id = p_org and profile_id = auth.uid();

  if v_customer is not null then
    return v_customer;
  end if;

  if p_email is null and p_phone is null then
    raise exception 'CUSTOMER_CONTACT_REQUIRED';
  end if;

  select id into v_customer
  from public.customers
  where organization_id = p_org
    and deleted_at is null
    and profile_id is null
    and ((p_email is not null and lower(email) = lower(trim(p_email)))
      or (p_phone is not null and phone = trim(p_phone)))
  order by created_at
  limit 1;

  if v_customer is not null then
    update public.customers set profile_id = auth.uid(), updated_at = now() where id = v_customer;
    return v_customer;
  end if;

  insert into public.customers(organization_id, name, email, phone, profile_id)
  values (p_org, trim(p_name), nullif(trim(coalesce(p_email, '')), ''), nullif(trim(coalesce(p_phone, '')), ''), auth.uid())
  returning id into v_customer;

  return v_customer;

end;
$$;

grant execute on function public.claim_customer_identity(uuid, text, text, text) to authenticated;


-- -----------------------------------------------------------------------------
-- Also link on public booking: if a customer books while signed in (not
-- anonymously), attach their profile_id so it shows up in "My appointments"
-- without a separate claim step.
-- -----------------------------------------------------------------------------

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

  if auth.uid() is not null then
    select id into v_customer from public.customers where organization_id = v_org and profile_id = auth.uid();
  end if;

  if v_customer is null then
    select id into v_customer from public.customers
    where organization_id = v_org and deleted_at is null
      and ((p_customer_email is not null and lower(email) = lower(trim(p_customer_email)))
        or (p_customer_phone is not null and phone = trim(p_customer_phone)))
    order by created_at limit 1;
  end if;

  if v_customer is null then
    insert into public.customers(organization_id, name, phone, email, profile_id)
    values (v_org, trim(p_customer_name), nullif(trim(p_customer_phone), ''), nullif(trim(p_customer_email), ''), auth.uid())
    returning id into v_customer;
  else
    update public.customers
    set name = trim(p_customer_name),
        phone = coalesce(nullif(trim(p_customer_phone), ''), phone),
        email = coalesce(nullif(trim(p_customer_email), ''), email),
        profile_id = coalesce(profile_id, auth.uid()),
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


-- -----------------------------------------------------------------------------
-- RLS: let a customer read their own records, in any organization, purely
-- via customers.profile_id = auth.uid() — independent of organization
-- membership (a customer is never an organization_member). Existing
-- member-scoped policies are untouched; these are additive (RLS policies
-- are OR'd together).
-- -----------------------------------------------------------------------------

create policy customers_self_select
on public.customers
for select
to authenticated
using (profile_id = auth.uid());

create policy appointments_self_select
on public.appointments
for select
to authenticated
using (
  exists (
    select 1 from public.customers c
    where c.id = appointments.customer_id and c.profile_id = auth.uid()
  )
);

create policy appointment_services_self_select
on public.appointment_services
for select
to authenticated
using (
  exists (
    select 1 from public.appointments a
    join public.customers c on c.id = a.customer_id
    where a.id = appointment_services.appointment_id and c.profile_id = auth.uid()
  )
);

create policy loyalty_accounts_self_select
on public.loyalty_accounts
for select
to authenticated
using (
  exists (
    select 1 from public.customers c
    where c.id = loyalty_accounts.customer_id and c.profile_id = auth.uid()
  )
);

create policy loyalty_transactions_self_select
on public.loyalty_transactions
for select
to authenticated
using (
  exists (
    select 1 from public.customers c
    where c.id = loyalty_transactions.customer_id and c.profile_id = auth.uid()
  )
);

create policy customer_packages_self_select
on public.customer_packages
for select
to authenticated
using (
  exists (
    select 1 from public.customers c
    where c.id = customer_packages.customer_id and c.profile_id = auth.uid()
  )
);

create policy customer_memberships_self_select
on public.customer_memberships
for select
to authenticated
using (
  exists (
    select 1 from public.customers c
    where c.id = customer_memberships.customer_id and c.profile_id = auth.uid()
  )
);

create policy queue_entries_self_select
on public.queue_entries
for select
to authenticated
using (
  exists (
    select 1 from public.customers c
    where c.id = queue_entries.customer_id and c.profile_id = auth.uid()
  )
);
