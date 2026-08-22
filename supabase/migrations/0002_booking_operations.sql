create table if not exists public.queue_entries(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null references public.organizations(id) on delete cascade,customer_id uuid not null references public.customers(id),service_id uuid not null references public.services(id),staff_id uuid references public.staff(id),queue_number integer not null, status text not null default 'waiting' check(status in ('waiting','called','in_service','completed','cancelled')),checked_in_at timestamptz not null default now(),estimated_wait_min integer not null default 0,created_at timestamptz not null default now(),updated_at timestamptz not null default now()
);
create table if not exists public.payments(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null references public.organizations(id) on delete cascade,appointment_id uuid references public.appointments(id),amount_minor bigint not null check(amount_minor>0),method text not null check(method in ('cash','card','transfer','online','other')),type text not null default 'payment' check(type in ('deposit','payment','refund','forfeit','adjustment')),status text not null default 'completed' check(status in ('pending','completed','reversed')),provider_reference text,idempotency_key text unique,created_at timestamptz not null default now(),created_by uuid references auth.users(id)
);
create table if not exists public.audit_logs(
 id bigint generated always as identity primary key,organization_id uuid references public.organizations(id) on delete cascade,user_id uuid references auth.users(id),action text not null,entity text not null,entity_id uuid,old_data jsonb,new_data jsonb,created_at timestamptz not null default now()
);

create or replace function public.get_available_slots(p_staff uuid,p_service uuid,p_date date,p_location uuid default null)
returns table(starts_at timestamptz,ends_at timestamptz) language plpgsql stable security definer set search_path=public as $$
declare v_org uuid; v_duration int; v_buffer int; v_tz text; v_day int; h record; candidate timestamptz; finish timestamptz;
begin
 select organization_id,duration_min,buffer_min into v_org,v_duration,v_buffer from services where id=p_service and deleted_at is null;
 if v_org is null then raise exception 'SERVICE_NOT_FOUND'; end if;
 if not exists(select 1 from staff where id=p_staff and organization_id=v_org and status='active' and deleted_at is null) then raise exception 'STAFF_NOT_FOUND'; end if;
 if not exists(select 1 from staff_services where staff_id=p_staff and service_id=p_service) then raise exception 'STAFF_CANNOT_PERFORM_SERVICE'; end if;
 select timezone into v_tz from organizations where id=v_org; v_tz=coalesce(v_tz,'UTC'); v_day=extract(dow from p_date)::int;
 for h in select start_time,end_time from working_hours where staff_id=p_staff and weekday=v_day loop
   candidate=(p_date+h.start_time) at time zone v_tz;
   while candidate + make_interval(mins=>v_duration+v_buffer) <= (p_date+h.end_time) at time zone v_tz loop
     finish=candidate+make_interval(mins=>v_duration+v_buffer);
     if not exists(select 1 from staff_breaks b where b.staff_id=p_staff and b.weekday=v_day and candidate < ((p_date+b.end_time) at time zone v_tz) and finish > ((p_date+b.start_time) at time zone v_tz))
       and not exists(select 1 from blocked_times bt where bt.staff_id=p_staff and candidate < bt.ends_at and finish > bt.starts_at)
       and not exists(select 1 from appointments a where a.staff_id=p_staff and a.deleted_at is null and a.status in ('pending','confirmed','checked_in','in_service') and candidate < a.ends_at and finish > a.starts_at)
     then starts_at=candidate; ends_at=candidate+make_interval(mins=>v_duration); return next; end if;
     candidate=candidate+interval '15 minutes';
   end loop;
 end loop;
end $$;

create or replace function public.create_booking(p_operation_id uuid,p_organization uuid,p_customer uuid,p_staff uuid,p_service uuid,p_starts_at timestamptz,p_source text default 'online',p_location uuid default null,p_notes text default null)
returns uuid language plpgsql security definer set search_path=public as $$
declare v_id uuid; v_end timestamptz; v_duration int; v_price bigint; v_deposit bigint; v_org uuid;
begin
 if auth.uid() is null then raise exception 'NOT_AUTHENTICATED'; end if;
 if not exists(select 1 from organization_members where organization_id=p_organization and user_id=auth.uid() and status='active') then raise exception 'FORBIDDEN'; end if;
 if exists(select 1 from audit_logs where entity='booking_operation' and entity_id=p_operation_id) then select new_data->>'appointment_id' into v_id from audit_logs where entity='booking_operation' and entity_id=p_operation_id limit 1; return v_id; end if;
 select organization_id,duration_min,price_minor,deposit_required_minor into v_org,v_duration,v_price,v_deposit from services where id=p_service and deleted_at is null;
 if v_org<>p_organization then raise exception 'SERVICE_NOT_FOUND'; end if;
 if not exists(select 1 from customers where id=p_customer and organization_id=p_organization and deleted_at is null) then raise exception 'CUSTOMER_NOT_FOUND'; end if;
 if not exists(select 1 from staff where id=p_staff and organization_id=p_organization and status='active' and deleted_at is null) then raise exception 'STAFF_NOT_FOUND'; end if;
 if not exists(select 1 from staff_services where staff_id=p_staff and service_id=p_service) then raise exception 'STAFF_CANNOT_PERFORM_SERVICE'; end if;
 v_end=p_starts_at+make_interval(mins=>v_duration);
 if not exists(select 1 from get_available_slots(p_staff,p_service,(p_starts_at at time zone coalesce((select timezone from organizations where id=p_organization),'UTC'))::date,p_location) s where s.starts_at=p_starts_at) then raise exception 'SLOT_NOT_AVAILABLE'; end if;
 insert into appointments(organization_id,customer_id,staff_id,location_id,status,starts_at,ends_at,source,deposit_required_minor,notes,created_by,updated_by) values(p_organization,p_customer,p_staff,p_location,'confirmed',p_starts_at,v_end,p_source,p_deposit,p_notes,auth.uid(),auth.uid()) returning id into v_id;
 insert into appointment_services(appointment_id,service_id,price_minor,duration_min) values(v_id,p_service,v_price,v_duration);
 insert into audit_logs(organization_id,user_id,action,entity,entity_id,new_data) values(p_organization,auth.uid(),'create','booking_operation',p_operation_id,jsonb_build_object('appointment_id',v_id));
 return v_id;
exception when exclusion_violation then raise exception 'SLOT_ALREADY_BOOKED';
end $$;

create or replace function public.change_appointment_status(p_appointment uuid,p_status text)
returns void language plpgsql security definer set search_path=public as $$
declare v_org uuid; v_old text;
begin select organization_id,status into v_org,v_old from appointments where id=p_appointment for update; if v_org is null then raise exception 'APPOINTMENT_NOT_FOUND'; end if; if not exists(select 1 from organization_members where organization_id=v_org and user_id=auth.uid() and status='active') then raise exception 'FORBIDDEN'; end if;
 update appointments set status=p_status,updated_by=auth.uid() where id=p_appointment;
 if p_status='no_show' then update customers set no_show_count=no_show_count+1,updated_at=now() where id=(select customer_id from appointments where id=p_appointment); end if;
 if p_status='completed' then update customers set last_visit_at=now(),updated_at=now() where id=(select customer_id from appointments where id=p_appointment); end if;
 insert into audit_logs(organization_id,user_id,action,entity,entity_id,old_data,new_data) values(v_org,auth.uid(),'status_change','appointment',p_appointment,jsonb_build_object('status',v_old),jsonb_build_object('status',p_status));
end $$;

create or replace function public.record_payment(p_idempotency uuid,p_appointment uuid,p_amount bigint,p_method text,p_type text default 'payment') returns uuid language plpgsql security definer set search_path=public as $$
declare v_payment uuid; v_org uuid; begin select organization_id into v_org from appointments where id=p_appointment; if not exists(select 1 from organization_members where organization_id=v_org and user_id=auth.uid() and status='active') then raise exception 'FORBIDDEN'; end if;
 select id into v_payment from payments where idempotency_key=p_idempotency::text; if v_payment is not null then return v_payment; end if;
 insert into payments(organization_id,appointment_id,amount_minor,method,type,idempotency_key,created_by) values(v_org,p_appointment,p_amount,p_method,p_type,p_idempotency::text,auth.uid()) returning id into v_payment;
 if p_type='deposit' then update appointments set deposit_paid_minor=deposit_paid_minor+p_amount where id=p_appointment; end if;
 insert into audit_logs(organization_id,user_id,action,entity,entity_id,new_data) values(v_org,auth.uid(),'payment','payment',v_payment,jsonb_build_object('amount_minor',p_amount,'type',p_type)); return v_payment; end $$;

create or replace function public.cancel_appointment(p_appointment uuid) returns void language plpgsql security definer set search_path=public as $$
declare a record; v_window int; begin select a.*,s.cancellation_window_min into a from appointments a join appointment_services aps on aps.appointment_id=a.id join services s on s.id=aps.service_id where a.id=p_appointment limit 1; if a.id is null then raise exception 'APPOINTMENT_NOT_FOUND'; end if; if not exists(select 1 from organization_members where organization_id=a.organization_id and user_id=auth.uid() and status='active') then raise exception 'FORBIDDEN'; end if; if a.starts_at-now() < make_interval(mins=>coalesce(a.cancellation_window_min,120)) then raise exception 'CANCELLATION_WINDOW_PASSED'; end if; update appointments set status='cancelled',updated_by=auth.uid() where id=p_appointment; insert into audit_logs(organization_id,user_id,action,entity,entity_id,new_data) values(a.organization_id,auth.uid(),'cancel','appointment',p_appointment,jsonb_build_object('status','cancelled')); end $$;

create or replace function public.reschedule_appointment(p_appointment uuid,p_new_start timestamptz) returns void language plpgsql security definer set search_path=public as $$
declare a record; v_duration int; v_end timestamptz; begin select a.*,aps.service_id,s.duration_min into a from appointments a join appointment_services aps on aps.appointment_id=a.id join services s on s.id=aps.service_id where a.id=p_appointment limit 1; if a.id is null then raise exception 'APPOINTMENT_NOT_FOUND'; end if; if not exists(select 1 from organization_members where organization_id=a.organization_id and user_id=auth.uid() and status='active') then raise exception 'FORBIDDEN'; end if; v_end=p_new_start+make_interval(mins=>a.duration_min); if exists(select 1 from appointments x where x.id<>p_appointment and x.staff_id=a.staff_id and x.deleted_at is null and x.status in ('pending','confirmed','checked_in','in_service') and p_new_start<x.ends_at and v_end>x.starts_at) then raise exception 'SLOT_ALREADY_BOOKED'; end if; update appointments set starts_at=p_new_start,ends_at=v_end,version=version+1,updated_by=auth.uid() where id=p_appointment; insert into audit_logs(organization_id,user_id,action,entity,entity_id,new_data) values(a.organization_id,auth.uid(),'reschedule','appointment',p_appointment,jsonb_build_object('starts_at',p_new_start,'ends_at',v_end)); end $$;

create or replace function public.add_walk_in(p_customer uuid,p_service uuid,p_staff uuid default null) returns uuid language plpgsql security definer set search_path=public as $$
declare v_org uuid; v_number int; v_id uuid; begin select organization_id into v_org from customers where id=p_customer; if v_org is null then raise exception 'CUSTOMER_NOT_FOUND'; end if; if not exists(select 1 from organization_members where organization_id=v_org and user_id=auth.uid() and status='active') then raise exception 'FORBIDDEN'; end if; select coalesce(max(queue_number),0)+1 into v_number from queue_entries where organization_id=v_org and created_at::date=current_date; insert into queue_entries(organization_id,customer_id,service_id,staff_id,queue_number,estimated_wait_min) values(v_org,p_customer,p_service,p_staff,v_number,0) returning id into v_id; return v_id; end $$;

grant execute on function public.cancel_appointment(uuid) to authenticated;
grant execute on function public.reschedule_appointment(uuid,timestamptz) to authenticated;
grant execute on function public.add_walk_in(uuid,uuid,uuid) to authenticated;
