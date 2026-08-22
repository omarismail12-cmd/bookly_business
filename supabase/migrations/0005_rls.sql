-- Bookly tenant isolation and role-aware RLS.
-- Replace the old 0005_rls.sql with this version BEFORE running the migrations.

alter table public.profiles enable row level security;

do $$
declare
  t text;
begin
  foreach t in array array[
    'organizations',
    'organization_members',
    'locations',
    'service_categories',
    'services',
    'staff',
    'staff_services',
    'working_hours',
    'staff_breaks',
    'blocked_times',
    'customers',
    'appointments',
    'appointment_services',
    'queue_entries',
    'payments',
    'audit_logs',
    'packages',
    'package_usage',
    'memberships',
    'customer_memberships',
    'loyalty_accounts',
    'loyalty_transactions',
    'coupons',
    'campaigns',
    'campaign_recipients',
    'device_tokens',
    'notification_jobs'
  ]
  loop
    execute format(
      'alter table public.%I enable row level security',
      t
    );
  end loop;
end $$;


-- ============================================================
-- Helper: check whether the current user has one of the
-- specified roles inside an organization.
-- ============================================================

create or replace function public.has_org_role(
  p_org uuid,
  p_roles text[]
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.organization_members
    where organization_id = p_org
      and user_id = auth.uid()
      and status = 'active'
      and role = any(p_roles)
  );
$$;

grant execute on function public.has_org_role(uuid, text[])
to authenticated;


-- ============================================================
-- Drop old policies so this migration is safe to re-run
-- during development.
-- ============================================================

do $$
declare
  r record;
begin
  for r in
    select
      schemaname,
      tablename,
      policyname
    from pg_policies
    where schemaname = 'public'
  loop
    execute format(
      'drop policy if exists %I on public.%I',
      r.policyname,
      r.tablename
    );
  end loop;
end $$;


-- ============================================================
-- PROFILES
-- ============================================================

create policy profiles_select
on public.profiles
for select
using (
  id = auth.uid()
  or exists (
    select 1
    from public.organization_members m
    where m.user_id = profiles.id
      and m.organization_id in (
        select public.current_org_ids()
      )
      and m.status = 'active'
  )
);

create policy profiles_update
on public.profiles
for update
using (
  id = auth.uid()
)
with check (
  id = auth.uid()
);


-- ============================================================
-- ORGANIZATIONS
-- ============================================================

create policy organizations_select
on public.organizations
for select
using (
  id in (
    select public.current_org_ids()
  )
);

create policy organizations_update
on public.organizations
for update
using (
  public.has_org_role(
    id,
    array['owner']
  )
)
with check (
  public.has_org_role(
    id,
    array['owner']
  )
);


-- ============================================================
-- ORGANIZATION MEMBERS
-- ============================================================

create policy members_select
on public.organization_members
for select
using (
  organization_id in (
    select public.current_org_ids()
  )
);

create policy members_insert
on public.organization_members
for insert
with check (
  public.has_org_role(
    organization_id,
    array['owner', 'manager']
  )
);

create policy members_update
on public.organization_members
for update
using (
  public.has_org_role(
    organization_id,
    array['owner']
  )
)
with check (
  public.has_org_role(
    organization_id,
    array['owner']
  )
);

create policy members_delete
on public.organization_members
for delete
using (
  public.has_org_role(
    organization_id,
    array['owner']
  )
);


-- ============================================================
-- TABLES THAT HAVE organization_id DIRECTLY
-- ============================================================

do $$
declare
  t text;
begin
  foreach t in array array[
    'locations',
    'service_categories',
    'services',
    'staff',
    'customers',
    'appointments',
    'queue_entries',
    'payments',
    'audit_logs',
    'packages',
    'package_usage',
    'memberships',
    'customer_memberships',
    'loyalty_accounts',
    'loyalty_transactions',
    'coupons',
    'campaigns',
    'device_tokens',
    'notification_jobs'
  ]
  loop

    execute format(
      'create policy %I_select
       on public.%I
       for select
       using (
         organization_id in (
           select public.current_org_ids()
         )
       )',
      t,
      t
    );

    execute format(
      'create policy %I_insert
       on public.%I
       for insert
       with check (
         organization_id in (
           select public.current_org_ids()
         )
       )',
      t,
      t
    );

    execute format(
      'create policy %I_update
       on public.%I
       for update
       using (
         organization_id in (
           select public.current_org_ids()
         )
       )
       with check (
         organization_id in (
           select public.current_org_ids()
         )
       )',
      t,
      t
    );

    execute format(
      'create policy %I_delete
       on public.%I
       for delete
       using (
         organization_id in (
           select public.current_org_ids()
         )
       )',
      t,
      t
    );

  end loop;
end $$;


-- ============================================================
-- STAFF_SERVICES
-- Inherits tenant through staff + service.
-- ============================================================

create policy staff_services_select
on public.staff_services
for select
using (
  exists (
    select 1
    from public.staff s
    where s.id = staff_id
      and s.organization_id in (
        select public.current_org_ids()
      )
  )
);

create policy staff_services_insert
on public.staff_services
for insert
with check (
  exists (
    select 1
    from public.staff s
    join public.services v
      on v.organization_id = s.organization_id
    where s.id = staff_id
      and v.id = service_id
      and s.organization_id in (
        select public.current_org_ids()
      )
  )
);

create policy staff_services_update
on public.staff_services
for update
using (
  exists (
    select 1
    from public.staff s
    where s.id = staff_id
      and s.organization_id in (
        select public.current_org_ids()
      )
  )
)
with check (
  exists (
    select 1
    from public.staff s
    join public.services v
      on v.organization_id = s.organization_id
    where s.id = staff_id
      and v.id = service_id
      and s.organization_id in (
        select public.current_org_ids()
      )
  )
);

create policy staff_services_delete
on public.staff_services
for delete
using (
  exists (
    select 1
    from public.staff s
    where s.id = staff_id
      and s.organization_id in (
        select public.current_org_ids()
      )
  )
);


-- ============================================================
-- WORKING HOURS
-- ============================================================

create policy working_hours_select
on public.working_hours
for select
using (
  exists (
    select 1
    from public.staff s
    where s.id = staff_id
      and s.organization_id in (
        select public.current_org_ids()
      )
  )
);

create policy working_hours_insert
on public.working_hours
for insert
with check (
  exists (
    select 1
    from public.staff s
    where s.id = staff_id
      and public.has_org_role(
        s.organization_id,
        array['owner', 'manager']
      )
  )
);

create policy working_hours_update
on public.working_hours
for update
using (
  exists (
    select 1
    from public.staff s
    where s.id = staff_id
      and public.has_org_role(
        s.organization_id,
        array['owner', 'manager']
      )
  )
)
with check (
  exists (
    select 1
    from public.staff s
    where s.id = staff_id
      and public.has_org_role(
        s.organization_id,
        array['owner', 'manager']
      )
  )
);

create policy working_hours_delete
on public.working_hours
for delete
using (
  exists (
    select 1
    from public.staff s
    where s.id = staff_id
      and public.has_org_role(
        s.organization_id,
        array['owner', 'manager']
      )
  )
);


-- ============================================================
-- STAFF BREAKS
-- ============================================================

create policy staff_breaks_select
on public.staff_breaks
for select
using (
  exists (
    select 1
    from public.staff s
    where s.id = staff_id
      and s.organization_id in (
        select public.current_org_ids()
      )
  )
);

create policy staff_breaks_insert
on public.staff_breaks
for insert
with check (
  exists (
    select 1
    from public.staff s
    where s.id = staff_id
      and public.has_org_role(
        s.organization_id,
        array['owner', 'manager']
      )
  )
);

create policy staff_breaks_update
on public.staff_breaks
for update
using (
  exists (
    select 1
    from public.staff s
    where s.id = staff_id
      and public.has_org_role(
        s.organization_id,
        array['owner', 'manager']
      )
  )
)
with check (
  exists (
    select 1
    from public.staff s
    where s.id = staff_id
      and public.has_org_role(
        s.organization_id,
        array['owner', 'manager']
      )
  )
);

create policy staff_breaks_delete
on public.staff_breaks
for delete
using (
  exists (
    select 1
    from public.staff s
    where s.id = staff_id
      and public.has_org_role(
        s.organization_id,
        array['owner', 'manager']
      )
  )
);


-- ============================================================
-- BLOCKED TIMES
-- ============================================================

create policy blocked_times_select
on public.blocked_times
for select
using (
  exists (
    select 1
    from public.staff s
    where s.id = staff_id
      and s.organization_id in (
        select public.current_org_ids()
      )
  )
);

create policy blocked_times_insert
on public.blocked_times
for insert
with check (
  exists (
    select 1
    from public.staff s
    where s.id = staff_id
      and public.has_org_role(
        s.organization_id,
        array[
          'owner',
          'manager',
          'receptionist',
          'staff'
        ]
      )
  )
);

create policy blocked_times_update
on public.blocked_times
for update
using (
  exists (
    select 1
    from public.staff s
    where s.id = staff_id
      and public.has_org_role(
        s.organization_id,
        array[
          'owner',
          'manager',
          'receptionist',
          'staff'
        ]
      )
  )
)
with check (
  exists (
    select 1
    from public.staff s
    where s.id = staff_id
      and public.has_org_role(
        s.organization_id,
        array[
          'owner',
          'manager',
          'receptionist',
          'staff'
        ]
      )
  )
);

create policy blocked_times_delete
on public.blocked_times
for delete
using (
  exists (
    select 1
    from public.staff s
    where s.id = staff_id
      and public.has_org_role(
        s.organization_id,
        array['owner', 'manager']
      )
  )
);


-- ============================================================
-- APPOINTMENT_SERVICES
-- Inherits tenant through appointments.
-- ============================================================

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

create policy appointment_services_insert
on public.appointment_services
for insert
with check (
  exists (
    select 1
    from public.appointments a
    where a.id = appointment_id
      and a.organization_id in (
        select public.current_org_ids()
      )
  )
);

create policy appointment_services_update
on public.appointment_services
for update
using (
  exists (
    select 1
    from public.appointments a
    where a.id = appointment_id
      and a.organization_id in (
        select public.current_org_ids()
      )
  )
)
with check (
  exists (
    select 1
    from public.appointments a
    where a.id = appointment_id
      and a.organization_id in (
        select public.current_org_ids()
      )
  )
);

create policy appointment_services_delete
on public.appointment_services
for delete
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


-- ============================================================
-- CAMPAIGN_RECIPIENTS
-- IMPORTANT:
-- This table does NOT have organization_id.
-- Tenant isolation is inherited through campaign_id.
-- ============================================================

create policy campaign_recipients_select
on public.campaign_recipients
for select
using (
  exists (
    select 1
    from public.campaigns c
    where c.id = campaign_id
      and c.organization_id in (
        select public.current_org_ids()
      )
  )
);

create policy campaign_recipients_insert
on public.campaign_recipients
for insert
with check (
  exists (
    select 1
    from public.campaigns c
    where c.id = campaign_id
      and c.organization_id in (
        select public.current_org_ids()
      )
  )
);

create policy campaign_recipients_update
on public.campaign_recipients
for update
using (
  exists (
    select 1
    from public.campaigns c
    where c.id = campaign_id
      and c.organization_id in (
        select public.current_org_ids()
      )
  )
)
with check (
  exists (
    select 1
    from public.campaigns c
    where c.id = campaign_id
      and c.organization_id in (
        select public.current_org_ids()
      )
  )
);

create policy campaign_recipients_delete
on public.campaign_recipients
for delete
using (
  exists (
    select 1
    from public.campaigns c
    where c.id = campaign_id
      and c.organization_id in (
        select public.current_org_ids()
      )
  )
);


-- ============================================================
-- ROLE-AWARE WRITES
-- ============================================================

do $$
declare
  t text;
begin
  foreach t in array array[
    'locations',
    'service_categories',
    'services',
    'staff',
    'packages',
    'memberships',
    'coupons',
    'campaigns'
  ]
  loop

    execute format(
      'drop policy if exists %I_insert on public.%I',
      t,
      t
    );

    execute format(
      'drop policy if exists %I_update on public.%I',
      t,
      t
    );

    execute format(
      'create policy %I_insert
       on public.%I
       for insert
       with check (
         public.has_org_role(
           organization_id,
           array[''owner'', ''manager'']
         )
       )',
      t,
      t
    );

    execute format(
      'create policy %I_update
       on public.%I
       for update
       using (
         public.has_org_role(
           organization_id,
           array[''owner'', ''manager'']
         )
       )
       with check (
         public.has_org_role(
           organization_id,
           array[''owner'', ''manager'']
         )
       )',
      t,
      t
    );

  end loop;
end $$;


-- ============================================================
-- CUSTOMERS
-- ============================================================

drop policy if exists customers_insert
on public.customers;

drop policy if exists customers_update
on public.customers;

create policy customers_insert
on public.customers
for insert
with check (
  public.has_org_role(
    organization_id,
    array[
      'owner',
      'manager',
      'receptionist',
      'staff'
    ]
  )
);

create policy customers_update
on public.customers
for update
using (
  public.has_org_role(
    organization_id,
    array[
      'owner',
      'manager',
      'receptionist',
      'staff'
    ]
  )
)
with check (
  public.has_org_role(
    organization_id,
    array[
      'owner',
      'manager',
      'receptionist',
      'staff'
    ]
  )
);


-- ============================================================
-- APPOINTMENTS
-- ============================================================

drop policy if exists appointments_insert
on public.appointments;

drop policy if exists appointments_update
on public.appointments;

create policy appointments_insert
on public.appointments
for insert
with check (
  public.has_org_role(
    organization_id,
    array[
      'owner',
      'manager',
      'receptionist',
      'staff'
    ]
  )
);

create policy appointments_update
on public.appointments
for update
using (
  public.has_org_role(
    organization_id,
    array[
      'owner',
      'manager',
      'receptionist',
      'staff'
    ]
  )
)
with check (
  public.has_org_role(
    organization_id,
    array[
      'owner',
      'manager',
      'receptionist',
      'staff'
    ]
  )
);


-- ============================================================
-- PAYMENTS
-- ============================================================

drop policy if exists payments_insert
on public.payments;

drop policy if exists payments_update
on public.payments;

create policy payments_insert
on public.payments
for insert
with check (
  public.has_org_role(
    organization_id,
    array[
      'owner',
      'manager',
      'receptionist'
    ]
  )
);

create policy payments_update
on public.payments
for update
using (
  public.has_org_role(
    organization_id,
    array[
      'owner',
      'manager'
    ]
  )
)
with check (
  public.has_org_role(
    organization_id,
    array[
      'owner',
      'manager'
    ]
  )
);


-- ============================================================
-- FINANCE ROWS SHOULD NOT BE DELETED BY NORMAL CLIENTS.
-- ============================================================

drop policy if exists payments_delete
on public.payments;


-- ============================================================
-- RPC EXECUTION RIGHTS
-- ============================================================

grant execute on function
public.create_organization_for_current_user(text, text, text)
to authenticated;

grant execute on function
public.get_available_slots(uuid, uuid, date, uuid)
to anon, authenticated;

grant execute on function
public.create_booking(
  uuid,
  uuid,
  uuid,
  uuid,
  uuid,
  timestamptz,
  text,
  uuid,
  text
)
to authenticated;

grant execute on function
public.change_appointment_status(uuid, text)
to authenticated;

grant execute on function
public.record_payment(
  uuid,
  uuid,
  bigint,
  text,
  text
)
to authenticated;

grant execute on function
public.cancel_appointment(uuid)
to authenticated;

grant execute on function
public.reschedule_appointment(
  uuid,
  timestamptz
)
to authenticated;

grant execute on function
public.add_walk_in(
  uuid,
  uuid,
  uuid
)
to authenticated;

grant execute on function
public.award_loyalty_for_payment(uuid)
to authenticated;

grant execute on function
public.customer_segment(
  uuid,
  text
)
to authenticated;

grant execute on function
public.queue_appointment_notifications(uuid)
to authenticated;

grant execute on function
public.report_dashboard(
  uuid,
  timestamptz,
  timestamptz
)
to authenticated;