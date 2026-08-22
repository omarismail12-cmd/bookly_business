-- Bookly Business Phase 1 security + booking hardening.
-- Run after 0001..0007.
-- This migration is intentionally additive and idempotent where practical.


-- -----------------------------------------------------------------------------
-- 1) Buffer-aware appointment blocking
-- -----------------------------------------------------------------------------

alter table public.appointments
  add column if not exists blocking_ends_at timestamptz;


update public.appointments a
set blocking_ends_at = coalesce(
  a.starts_at
    + make_interval(
        mins => greatest(
          0,
          coalesce(
            s.duration_min,
            extract(epoch from (a.ends_at - a.starts_at)) / 60
          )::int
          + coalesce(s.buffer_min, 0)
        )
      ),
  a.ends_at
)
from public.appointment_services aps
join public.services s
  on s.id = aps.service_id
where aps.appointment_id = a.id
  and a.blocking_ends_at is null;


update public.appointments
set blocking_ends_at = ends_at
where blocking_ends_at is null;


alter table public.appointments
  alter column blocking_ends_at set not null;


-- -----------------------------------------------------------------------------
-- Calculate blocking end for appointment.
--
-- The appointment itself determines the base end time.
-- Service buffer is added when service information is available.
-- -----------------------------------------------------------------------------

create or replace function public.set_appointment_blocking_end()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_buffer int := 0;
begin

  /*
   * Try to obtain the maximum service buffer for this appointment.
   * This can be zero when appointment_services has not yet been inserted.
   */
  select coalesce(max(s.buffer_min), 0)
  into v_buffer
  from public.appointment_services aps
  join public.services s
    on s.id = aps.service_id
  where aps.appointment_id = new.id;


  new.blocking_ends_at := greatest(
    new.ends_at,
    new.ends_at + make_interval(mins => v_buffer)
  );

  return new;
end;
$$;


drop trigger if exists appointments_blocking_end
on public.appointments;


create trigger appointments_blocking_end
before insert or update of starts_at, ends_at
on public.appointments
for each row
execute function public.set_appointment_blocking_end();


-- -----------------------------------------------------------------------------
-- Refresh blocking end when appointment services change.
-- -----------------------------------------------------------------------------

create or replace function public.refresh_appointment_blocking_end()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_end timestamptz;
begin

  select
    a.ends_at
      + make_interval(
          mins => coalesce(max(s.buffer_min), 0)
        )
  into v_end
  from public.appointments a
  left join public.appointment_services aps
    on aps.appointment_id = a.id
  left join public.services s
    on s.id = aps.service_id
  where a.id = new.appointment_id
  group by a.id, a.ends_at;


  if v_end is not null then

    update public.appointments
    set blocking_ends_at = greatest(
      ends_at,
      v_end
    )
    where id = new.appointment_id;

  end if;


  return new;
end;
$$;


drop trigger if exists appointment_services_refresh_blocking
on public.appointment_services;


create trigger appointment_services_refresh_blocking
after insert or update
on public.appointment_services
for each row
execute function public.refresh_appointment_blocking_end();


-- -----------------------------------------------------------------------------
-- Prevent overlapping appointments for the same staff member.
-- -----------------------------------------------------------------------------

alter table public.appointments
  drop constraint if exists appointments_staff_no_overlap;


alter table public.appointments
  add constraint appointments_staff_no_overlap
  exclude using gist (
    staff_id with =,
    tstzrange(
      starts_at,
      blocking_ends_at,
      '[)'
    ) with &&
  )
  where (
    status in (
      'pending',
      'confirmed',
      'checked_in',
      'in_service'
    )
    and deleted_at is null
  );


-- -----------------------------------------------------------------------------
-- 2) Canonical slot calculation:
-- duration + buffer + breaks + blocked time + busy appointments
-- -----------------------------------------------------------------------------

create or replace function public.get_available_slots(
  p_staff uuid,
  p_service uuid,
  p_date date,
  p_location uuid default null
)
returns table(
  starts_at timestamptz,
  ends_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_org uuid;
  v_duration int;
  v_buffer int;
  v_tz text;
  v_day int;
  h record;
  candidate timestamptz;
  blocking_end timestamptz;
begin

  select
    s.organization_id,
    s.duration_min,
    coalesce(s.buffer_min, 0)
  into
    v_org,
    v_duration,
    v_buffer
  from public.services s
  where s.id = p_service
    and s.deleted_at is null;


  if v_org is null then
    raise exception 'SERVICE_NOT_FOUND';
  end if;


  if not exists (
    select 1
    from public.staff st
    where st.id = p_staff
      and st.organization_id = v_org
      and st.status = 'active'
      and st.deleted_at is null
  ) then
    raise exception 'STAFF_NOT_FOUND';
  end if;


  if not exists (
    select 1
    from public.staff_services ss
    where ss.staff_id = p_staff
      and ss.service_id = p_service
  ) then
    raise exception 'STAFF_CANNOT_PERFORM_SERVICE';
  end if;


  select coalesce(
    o.timezone,
    'UTC'
  )
  into v_tz
  from public.organizations o
  where o.id = v_org;


  v_day := extract(
    dow from p_date
  )::int;


  for h in
    select
      wh.start_time,
      wh.end_time
    from public.working_hours wh
    where wh.staff_id = p_staff
      and wh.weekday = v_day
    order by wh.start_time
  loop

    candidate :=
      (p_date + h.start_time)
      at time zone v_tz;


    while candidate
      + make_interval(
          mins => v_duration + v_buffer
        )
      <= (p_date + h.end_time)
         at time zone v_tz
    loop

      blocking_end :=
        candidate
        + make_interval(
            mins => v_duration + v_buffer
          );


      -- Staff breaks
      if not exists (
        select 1
        from public.staff_breaks b
        where b.staff_id = p_staff
          and b.weekday = v_day
          and candidate
              < (
                (p_date + b.end_time)
                at time zone v_tz
              )
          and blocking_end
              > (
                (p_date + b.start_time)
                at time zone v_tz
              )
      )

      -- Blocked times
      and not exists (
        select 1
        from public.blocked_times bt
        where bt.staff_id = p_staff
          and candidate < bt.ends_at
          and blocking_end > bt.starts_at
      )

      -- Existing appointments
      and not exists (
        select 1
        from public.appointments a
        where a.staff_id = p_staff
          and a.deleted_at is null
          and a.status in (
            'pending',
            'confirmed',
            'checked_in',
            'in_service'
          )
          and candidate
              < coalesce(
                  a.blocking_ends_at,
                  a.ends_at
                )
          and blocking_end > a.starts_at
      )

      then

        starts_at := candidate;

        ends_at :=
          candidate
          + make_interval(
              mins => v_duration
            );

        return next;

      end if;


      candidate :=
        candidate + interval '15 minutes';

    end loop;

  end loop;

end;
$$;


grant execute on function
public.get_available_slots(
  uuid,
  uuid,
  date,
  uuid
)
to anon, authenticated;


-- -----------------------------------------------------------------------------
-- 3) Appointment writes go through booking/status/reschedule RPCs.
-- -----------------------------------------------------------------------------

drop policy if exists appointments_insert
on public.appointments;

drop policy if exists appointments_update
on public.appointments;


drop policy if exists appointment_services_insert
on public.appointment_services;

drop policy if exists appointment_services_update
on public.appointment_services;

drop policy if exists appointment_services_delete
on public.appointment_services;


-- -----------------------------------------------------------------------------
-- Appointment SELECT
-- -----------------------------------------------------------------------------

drop policy if exists appointments_select
on public.appointments;


create policy appointments_select
on public.appointments
for select
using (
  organization_id in (
    select public.current_org_ids()
  )
);


-- -----------------------------------------------------------------------------
-- Appointment services SELECT
--
-- IMPORTANT:
-- Drop it first because the previous RLS migration already created it.
-- -----------------------------------------------------------------------------

drop policy if exists appointment_services_select
on public.appointment_services;


create policy appointment_services_select
on public.appointment_services
for select
using (
  exists (
    select 1
    from public.appointments a
    where a.id = appointment_id
      and a.organization_id in (
        select public.current_org_ids()
      )
  )
);


-- -----------------------------------------------------------------------------
-- 4) Payment immutability
-- -----------------------------------------------------------------------------

drop policy if exists payments_update
on public.payments;

drop policy if exists payments_delete
on public.payments;


drop policy if exists payments_select
on public.payments;


create policy payments_select
on public.payments
for select
using (
  organization_id in (
    select public.current_org_ids()
  )
);


-- Payment inserts are performed through record_payment().
drop policy if exists payments_insert
on public.payments;


-- -----------------------------------------------------------------------------
-- Reversal-based finance operation.
-- -----------------------------------------------------------------------------

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


  if exists (
    select 1
    from public.payments x
    where x.organization_id = p.organization_id
      and x.type = 'refund'
      and x.notes like '%' || p_original_payment::text || '%'
  ) then

    select x.id
    into v_id
    from public.payments x
    where x.organization_id = p.organization_id
      and x.type = 'refund'
      and x.notes like '%' || p_original_payment::text || '%'
    order by x.created_at desc
    limit 1;

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
    notes,
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
    'reversal_of='
      || p_original_payment::text
      || '; '
      || coalesce(p_reason, ''),
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
-- 5) Reschedule uses canonical availability function.
-- -----------------------------------------------------------------------------

create or replace function public.reschedule_appointment(
  p_appointment uuid,
  p_new_start timestamptz
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  a record;
  v_tz text;
  v_date date;
  v_slot_end timestamptz;
begin

  select
    a.*,
    aps.service_id,
    s.duration_min
  into a
  from public.appointments a
  join public.appointment_services aps
    on aps.appointment_id = a.id
  join public.services s
    on s.id = aps.service_id
  where a.id = p_appointment
  limit 1
  for update;


  if a.id is null then
    raise exception 'APPOINTMENT_NOT_FOUND';
  end if;


  if not public.has_org_role(
    a.organization_id,
    array[
      'owner',
      'manager',
      'receptionist',
      'staff'
    ]
  ) then
    raise exception 'FORBIDDEN';
  end if;


  if a.status in (
    'completed',
    'cancelled',
    'no_show'
  ) then
    raise exception 'INVALID_APPOINTMENT_STATUS';
  end if;


  select coalesce(
    timezone,
    'UTC'
  )
  into v_tz
  from public.organizations
  where id = a.organization_id;


  v_date :=
    (p_new_start at time zone v_tz)::date;


  if not exists (
    select 1
    from public.get_available_slots(
      a.staff_id,
      a.service_id,
      v_date,
      a.location_id
    ) s
    where s.starts_at = p_new_start
  ) then
    raise exception 'SLOT_NOT_AVAILABLE';
  end if;


  v_slot_end :=
    p_new_start
    + make_interval(
        mins => a.duration_min
      );


  update public.appointments
  set
    starts_at = p_new_start,
    ends_at = v_slot_end,
    updated_by = auth.uid()
  where id = p_appointment;


  insert into public.audit_logs (
    organization_id,
    user_id,
    action,
    entity,
    entity_id,
    new_data
  )
  values (
    a.organization_id,
    auth.uid(),
    'reschedule',
    'appointment',
    p_appointment,
    jsonb_build_object(
      'starts_at',
      p_new_start,
      'ends_at',
      v_slot_end
    )
  );

end;
$$;


grant execute on function
public.reschedule_appointment(
  uuid,
  timestamptz
)
to authenticated;


-- -----------------------------------------------------------------------------
-- 6) Storage bucket + tenant-scoped object policies.
-- -----------------------------------------------------------------------------

insert into storage.buckets (
  id,
  name,
  public
)
values (
  'business-assets',
  'business-assets',
  false
)
on conflict (id) do nothing;


drop policy if exists bookly_assets_select
on storage.objects;

drop policy if exists bookly_assets_insert
on storage.objects;

drop policy if exists bookly_assets_update
on storage.objects;

drop policy if exists bookly_assets_delete
on storage.objects;


create policy bookly_assets_select
on storage.objects
for select
to authenticated
using (
  bucket_id = 'business-assets'
  and (storage.foldername(name))[1]::uuid in (
    select public.current_org_ids()
  )
);


create policy bookly_assets_insert
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'business-assets'
  and (storage.foldername(name))[1]::uuid in (
    select public.current_org_ids()
  )
);


create policy bookly_assets_update
on storage.objects
for update
to authenticated
using (
  bucket_id = 'business-assets'
  and (storage.foldername(name))[1]::uuid in (
    select public.current_org_ids()
  )
)
with check (
  bucket_id = 'business-assets'
  and (storage.foldername(name))[1]::uuid in (
    select public.current_org_ids()
  )
);


create policy bookly_assets_delete
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'business-assets'
  and (storage.foldername(name))[1]::uuid in (
    select public.current_org_ids()
  )
);


-- -----------------------------------------------------------------------------
-- 7) Helpful indexes
-- -----------------------------------------------------------------------------

create index if not exists idx_appointments_staff_active_time
on public.appointments (
  staff_id,
  starts_at,
  blocking_ends_at
)
where deleted_at is null;


create index if not exists idx_queue_org_created
on public.queue_entries (
  organization_id,
  created_at
);


create index if not exists idx_customers_org_updated
on public.customers (
  organization_id,
  updated_at desc
)
where deleted_at is null;


-- -----------------------------------------------------------------------------
-- 8) Audit-sensitive operations are kept explicit in application/RPC layer.
-- -----------------------------------------------------------------------------