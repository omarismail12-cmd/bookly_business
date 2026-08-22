create extension if not exists pgcrypto;
create extension if not exists btree_gist;

create table if not exists public.organizations (
 id uuid primary key default gen_random_uuid(), name text not null, slug text not null unique,
 logo_url text, plan text not null default 'starter', status text not null default 'active', timezone text not null default 'UTC',
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 created_by uuid references auth.users(id), updated_by uuid references auth.users(id), deleted_at timestamptz, version bigint not null default 1
);
create table if not exists public.profiles (
 id uuid primary key references auth.users(id) on delete cascade, full_name text, phone text, avatar_url text,
 language text not null default 'en', created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.organization_members (
 id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete cascade,
 user_id uuid not null references public.profiles(id) on delete cascade,
 role text not null check(role in ('owner','manager','receptionist','staff')), status text not null default 'active' check(status in ('active','invited','suspended')),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(), created_by uuid references auth.users(id), updated_by uuid references auth.users(id), version bigint not null default 1,
 unique(organization_id,user_id)
);
create or replace function public.handle_new_profile() returns trigger language plpgsql security definer set search_path=public as $$ begin insert into public.profiles(id) values(new.id) on conflict(id) do nothing; return new; end $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.handle_new_profile();

create or replace function public.current_org_ids() returns setof uuid language sql stable security definer set search_path=public as $$
 select organization_id from public.organization_members where user_id=auth.uid() and status='active'; $$;

create or replace function public.create_organization_for_current_user(p_name text,p_slug text,p_timezone text default 'UTC') returns uuid
language plpgsql security definer set search_path=public as $$
declare v_org uuid; begin
 if auth.uid() is null then raise exception 'NOT_AUTHENTICATED'; end if;
 insert into public.organizations(name,slug,timezone,created_by,updated_by) values(p_name,p_slug,p_timezone,auth.uid(),auth.uid()) returning id into v_org;
 insert into public.organization_members(organization_id,user_id,role,status,created_by,updated_by) values(v_org,auth.uid(),'owner','active',auth.uid(),auth.uid());
 update public.profiles set full_name=coalesce(full_name, split_part(coalesce((select email from auth.users where id=auth.uid()),''),'@',1)), updated_at=now() where id=auth.uid();
 return v_org;
end $$;

create table if not exists public.locations (
 id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete cascade,
 name text not null,address text,timezone text,created_at timestamptz not null default now(),updated_at timestamptz not null default now(),created_by uuid references auth.users(id),updated_by uuid references auth.users(id),deleted_at timestamptz,version bigint not null default 1
);
create table if not exists public.service_categories (
 id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete cascade,name text not null,created_at timestamptz not null default now(),updated_at timestamptz not null default now(),created_by uuid references auth.users(id),updated_by uuid references auth.users(id),deleted_at timestamptz,version bigint not null default 1
);
create table if not exists public.services (
 id uuid primary key default gen_random_uuid(),organization_id uuid not null references public.organizations(id) on delete cascade,category_id uuid references public.service_categories(id) on delete set null,name text not null,duration_min integer not null check(duration_min>0),buffer_min integer not null default 0 check(buffer_min>=0),price_minor bigint not null check(price_minor>=0),deposit_required_minor bigint not null default 0 check(deposit_required_minor>=0),cancellation_window_min integer not null default 120 check(cancellation_window_min>=0),created_at timestamptz not null default now(),updated_at timestamptz not null default now(),created_by uuid references auth.users(id),updated_by uuid references auth.users(id),deleted_at timestamptz,version bigint not null default 1
);
create table if not exists public.staff (
 id uuid primary key default gen_random_uuid(),organization_id uuid not null references public.organizations(id) on delete cascade,profile_id uuid references public.profiles(id) on delete set null,display_name text not null,status text not null default 'active' check(status in ('active','inactive')),created_at timestamptz not null default now(),updated_at timestamptz not null default now(),created_by uuid references auth.users(id),updated_by uuid references auth.users(id),deleted_at timestamptz,version bigint not null default 1
);
create table if not exists public.staff_services(staff_id uuid references public.staff(id) on delete cascade,service_id uuid references public.services(id) on delete cascade,primary key(staff_id,service_id));
create table if not exists public.working_hours(id uuid primary key default gen_random_uuid(),staff_id uuid references public.staff(id) on delete cascade,weekday integer not null check(weekday between 0 and 6),start_time time not null,end_time time not null,check(start_time<end_time));
create table if not exists public.staff_breaks(id uuid primary key default gen_random_uuid(),staff_id uuid references public.staff(id) on delete cascade,weekday integer not null check(weekday between 0 and 6),start_time time not null,end_time time not null,check(start_time<end_time));
create table if not exists public.blocked_times(id uuid primary key default gen_random_uuid(),staff_id uuid references public.staff(id) on delete cascade,starts_at timestamptz not null,ends_at timestamptz not null,reason text,created_at timestamptz not null default now(),check(starts_at<ends_at));

create table if not exists public.customers(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null references public.organizations(id) on delete cascade,name text not null,phone text,email text,birthday date,private_notes text,no_show_count integer not null default 0,total_spent_minor bigint not null default 0,last_visit_at timestamptz,created_at timestamptz not null default now(),updated_at timestamptz not null default now(),created_by uuid references auth.users(id),updated_by uuid references auth.users(id),deleted_at timestamptz,version bigint not null default 1
);
create table if not exists public.appointments(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null references public.organizations(id) on delete cascade,customer_id uuid not null references public.customers(id),staff_id uuid not null references public.staff(id),location_id uuid references public.locations(id),status text not null default 'pending' check(status in ('pending','confirmed','checked_in','in_service','completed','cancelled','no_show')),starts_at timestamptz not null,ends_at timestamptz not null,source text not null default 'online' check(source in ('online','reception','walk_in')),deposit_required_minor bigint not null default 0,deposit_paid_minor bigint not null default 0,notes text,created_at timestamptz not null default now(),updated_at timestamptz not null default now(),created_by uuid references auth.users(id),updated_by uuid references auth.users(id),deleted_at timestamptz,version bigint not null default 1,check(starts_at<ends_at)
);
create table if not exists public.appointment_services(id uuid primary key default gen_random_uuid(),appointment_id uuid references public.appointments(id) on delete cascade,service_id uuid references public.services(id),price_minor bigint not null,duration_min integer not null);
create index if not exists idx_appointments_org_start on public.appointments(organization_id,starts_at);
create index if not exists idx_customers_org_phone on public.customers(organization_id,phone);

alter table public.appointments drop constraint if exists appointments_staff_no_overlap;
alter table public.appointments add constraint appointments_staff_no_overlap exclude using gist(staff_id with =,tstzrange(starts_at,ends_at,'[)') with &&) where(status in ('pending','confirmed','checked_in','in_service') and deleted_at is null);

create or replace function public.set_updated_at() returns trigger language plpgsql as $$ begin new.updated_at=now(); new.version=old.version+1; return new; end $$;

-- Common update/version triggers
DO $$ DECLARE t text; BEGIN
FOREACH t IN ARRAY ARRAY['organizations','organization_members','locations','service_categories','services','staff','customers','appointments'] LOOP
  EXECUTE format('drop trigger if exists %I_updated_at on public.%I',t,t);
  EXECUTE format('create trigger %I_updated_at before update on public.%I for each row execute function public.set_updated_at()',t,t);
END LOOP; END $$;
