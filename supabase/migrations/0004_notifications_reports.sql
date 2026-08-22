create table if not exists public.device_tokens(id uuid primary key default gen_random_uuid(),organization_id uuid references public.organizations(id) on delete cascade,user_id uuid references auth.users(id) on delete cascade,customer_id uuid references public.customers(id) on delete cascade,token text not null unique,platform text,created_at timestamptz not null default now(),updated_at timestamptz not null default now());
create table if not exists public.notification_jobs(id uuid primary key default gen_random_uuid(),organization_id uuid references public.organizations(id) on delete cascade,appointment_id uuid references public.appointments(id) on delete cascade,recipient_user_id uuid references auth.users(id),recipient_customer_id uuid references public.customers(id),kind text not null,scheduled_for timestamptz not null,sent_at timestamptz,status text not null default 'pending',error text);
create index if not exists idx_notification_jobs_due on public.notification_jobs(status,scheduled_for);

create or replace function public.queue_appointment_notifications(p_appointment uuid) returns void language plpgsql security definer set search_path=public as $$
declare a record; begin select * into a from appointments where id=p_appointment; if a.id is null then return; end if;
 insert into notification_jobs(organization_id,appointment_id,recipient_customer_id,kind,scheduled_for) values(a.organization_id,a.id,a.customer_id,'confirmation',now()) on conflict do nothing;
 insert into notification_jobs(organization_id,appointment_id,recipient_customer_id,kind,scheduled_for) values(a.organization_id,a.id,a.customer_id,'reminder_24h',a.starts_at-interval '24 hours');
 insert into notification_jobs(organization_id,appointment_id,recipient_customer_id,kind,scheduled_for) values(a.organization_id,a.id,a.customer_id,'reminder_2h',a.starts_at-interval '2 hours');
end $$;

create or replace function public.report_dashboard(p_org uuid,p_from timestamptz,p_to timestamptz) returns jsonb language sql stable security definer set search_path=public as $$
select jsonb_build_object(
 'appointments', (select count(*) from appointments where organization_id=p_org and starts_at>=p_from and starts_at<p_to),
 'completed', (select count(*) from appointments where organization_id=p_org and status='completed' and starts_at>=p_from and starts_at<p_to),
 'cancelled', (select count(*) from appointments where organization_id=p_org and status='cancelled' and starts_at>=p_from and starts_at<p_to),
 'no_show', (select count(*) from appointments where organization_id=p_org and status='no_show' and starts_at>=p_from and starts_at<p_to),
 'revenue_minor', coalesce((select sum(amount_minor) from payments where organization_id=p_org and type in ('payment','deposit') and status='completed' and created_at>=p_from and created_at<p_to),0),
 'customers', (select count(*) from customers where organization_id=p_org and created_at>=p_from and created_at<p_to)
);
$$;
