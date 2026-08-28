-- Completes seed_demo_data_for_current_user() (0006_demo_seed.sql) so a
-- freshly seeded demo business is actually usable end-to-end, not just
-- populated enough to avoid empty-state screens.
--
-- Audited the live function (0006 is the only migration that has ever
-- defined it — checked every migration referencing the function name;
-- 0023_default_location_on_org_create.sql only mentions it in a comment)
-- against every screen in the app. Confirmed gaps, closed here:
--   - staff_breaks / blocked_times: only ever seeded for ONE of the four
--     staff members (Maya / Lina respectively) — now every staff member
--     gets at least one of each.
--   - Appointment status coverage: only ever produced confirmed/completed/
--     no_show — added pending, checked_in, cancelled so Calendar/Dashboard/
--     Reports show the full status spread immediately.
--   - Payments: never exercised the reversal path — added a second payment
--     + its reversal, mirroring reverse_payment()'s exact insert shape
--     (0009_security_fixes.sql: type='refund', status='completed',
--     amount_minor=-abs(original), reversed_payment_id set).
--   - customer_packages: packages/memberships were both created, but only
--     the membership side was ever assigned to a customer
--     (customer_memberships) — customer_packages had zero rows. Added one.
--   - campaign_recipients: the demo campaign was created as a bare draft
--     with no recipients ever generated. Added real recipients directly
--     (simpler and more reliable here than requiring customer_segment()
--     to match, which is a live query against data this same function
--     just inserted).
--
-- NOT actually a gap, contrary to what prompted this migration: staff_services
-- (every seeded service already gets a qualified staff member and vice versa
-- in the current function — verified by reading it and by live-testing this
-- session against a freshly seeded org, where staff_services came back fully
-- populated). The STAFF_CANNOT_PERFORM_SERVICE error hit earlier this session
-- was against a live production org whose staff/services were created
-- manually, never through this function — unrelated to seeding. Left
-- unchanged; noting it here so it isn't "fixed" a second time without cause.
--
-- Run after 0001..0039.

create or replace function public.seed_demo_data_for_current_user()
returns jsonb language plpgsql security definer set search_path=public as $$
declare
  v_uid uuid := auth.uid(); v_org uuid; v_location uuid; v_category uuid;
  v_hair uuid; v_color uuid; v_nails uuid;
  s1 uuid; s2 uuid; s3 uuid; s4 uuid;
  c1 uuid; c2 uuid; c3 uuid; c4 uuid; c5 uuid;
  a_today uuid; a_tomorrow uuid; a_no_show uuid;
  a_pending uuid; a_checked_in uuid; a_cancelled uuid;
  pkg uuid; mem uuid; camp uuid; n int;
  v_pay_to_reverse uuid;
  d date := (now() at time zone 'Asia/Beirut')::date;
  tz text := 'Asia/Beirut';
begin
  if v_uid is null then raise exception 'NOT_AUTHENTICATED'; end if;
  select organization_id into v_org from organization_members where user_id=v_uid and status='active' order by created_at limit 1;
  if v_org is null then
    v_org := public.create_organization_for_current_user('Bookly Demo Salon','demo-'||replace(v_uid::text,'-',''),tz);
  else
    update organizations set timezone=tz where id=v_org;
  end if;

  insert into locations(organization_id,name,address,timezone,created_by,updated_by)
  select v_org,'Main Branch','Demo Street 1, Tripoli',tz,v_uid,v_uid
  where not exists(select 1 from locations where organization_id=v_org and name='Main Branch');
  select id into v_location from locations where organization_id=v_org and name='Main Branch' limit 1;

  insert into service_categories(organization_id,name,created_by,updated_by)
  select v_org,'Hair & Beauty',v_uid,v_uid where not exists(select 1 from service_categories where organization_id=v_org and name='Hair & Beauty');
  select id into v_category from service_categories where organization_id=v_org and name='Hair & Beauty' limit 1;

  insert into services(organization_id,category_id,name,duration_min,buffer_min,price_minor,deposit_required_minor,cancellation_window_min,created_by,updated_by)
  select v_org,v_category,'Haircut',30,10,2500,0,120,v_uid,v_uid where not exists(select 1 from services where organization_id=v_org and name='Haircut');
  select id into v_hair from services where organization_id=v_org and name='Haircut' limit 1;
  insert into services(organization_id,category_id,name,duration_min,buffer_min,price_minor,deposit_required_minor,cancellation_window_min,created_by,updated_by)
  select v_org,v_category,'Hair Coloring',90,15,6500,1500,240,v_uid,v_uid where not exists(select 1 from services where organization_id=v_org and name='Hair Coloring');
  select id into v_color from services where organization_id=v_org and name='Hair Coloring' limit 1;
  insert into services(organization_id,category_id,name,duration_min,buffer_min,price_minor,deposit_required_minor,cancellation_window_min,created_by,updated_by)
  select v_org,v_category,'Manicure',45,10,3000,500,120,v_uid,v_uid where not exists(select 1 from services where organization_id=v_org and name='Manicure');
  select id into v_nails from services where organization_id=v_org and name='Manicure' limit 1;

  insert into staff(organization_id,display_name,status,created_by,updated_by)
  select v_org,'Maya Stylist','active',v_uid,v_uid where not exists(select 1 from staff where organization_id=v_org and display_name='Maya Stylist');
  insert into staff(organization_id,display_name,status,created_by,updated_by)
  select v_org,'Lina Colorist','active',v_uid,v_uid where not exists(select 1 from staff where organization_id=v_org and display_name='Lina Colorist');
  insert into staff(organization_id,display_name,status,created_by,updated_by)
  select v_org,'Omar Barber','active',v_uid,v_uid where not exists(select 1 from staff where organization_id=v_org and display_name='Omar Barber');
  insert into staff(organization_id,display_name,status,created_by,updated_by)
  select v_org,'Nour Assistant','active',v_uid,v_uid where not exists(select 1 from staff where organization_id=v_org and display_name='Nour Assistant');
  select id into s1 from staff where organization_id=v_org and display_name='Maya Stylist';
  select id into s2 from staff where organization_id=v_org and display_name='Lina Colorist';
  select id into s3 from staff where organization_id=v_org and display_name='Omar Barber';
  select id into s4 from staff where organization_id=v_org and display_name='Nour Assistant';
  insert into staff_services values(s1,v_hair) on conflict do nothing; insert into staff_services values(s1,v_color) on conflict do nothing; insert into staff_services values(s1,v_nails) on conflict do nothing;
  insert into staff_services values(s2,v_color) on conflict do nothing; insert into staff_services values(s2,v_nails) on conflict do nothing;
  insert into staff_services values(s3,v_hair) on conflict do nothing;
  insert into staff_services values(s4,v_hair) on conflict do nothing; insert into staff_services values(s4,v_nails) on conflict do nothing;
  for x in 1..4 loop
    insert into working_hours(staff_id,weekday,start_time,end_time) select case x when 1 then s1 when 2 then s2 when 3 then s3 else s4 end,g,'09:00','17:00' from generate_series(1,5) g
    where not exists(select 1 from working_hours w where w.staff_id=case x when 1 then s1 when 2 then s2 when 3 then s3 else s4 end and w.weekday=g);
  end loop;

  -- Every staff member gets at least one break and one blocked-time entry
  -- (previously only Maya had a break, only Lina had blocked time).
  for x in 1..4 loop
    insert into staff_breaks(staff_id,weekday,start_time,end_time)
    select case x when 1 then s1 when 2 then s2 when 3 then s3 else s4 end,g,'13:00','14:00' from generate_series(1,5) g
    where not exists(select 1 from staff_breaks b where b.staff_id=case x when 1 then s1 when 2 then s2 when 3 then s3 else s4 end and b.weekday=g);
  end loop;
  for x in 1..4 loop
    insert into blocked_times(staff_id,starts_at,ends_at,reason)
    select case x when 1 then s1 when 2 then s2 when 3 then s3 else s4 end,(d+time '15:00') at time zone tz,(d+time '16:00') at time zone tz,'Demo blocked time'
    where not exists(select 1 from blocked_times where staff_id=case x when 1 then s1 when 2 then s2 when 3 then s3 else s4 end and reason='Demo blocked time');
  end loop;

  insert into customers(organization_id,name,phone,email,last_visit_at,total_spent_minor,created_by,updated_by) select v_org,'John Demo','+96170000001','john.demo@example.com',now()-interval '2 days',32000,v_uid,v_uid where not exists(select 1 from customers where organization_id=v_org and email='john.demo@example.com');
  insert into customers(organization_id,name,phone,email,last_visit_at,total_spent_minor,created_by,updated_by) select v_org,'Sarah Inactive','+96170000002','sarah.inactive@example.com',now()-interval '45 days',18000,v_uid,v_uid where not exists(select 1 from customers where organization_id=v_org and email='sarah.inactive@example.com');
  insert into customers(organization_id,name,phone,email,no_show_count,total_spent_minor,created_by,updated_by) select v_org,'Daniel NoShow','+96170000003','daniel.noshow@example.com',3,12000,v_uid,v_uid where not exists(select 1 from customers where organization_id=v_org and email='daniel.noshow@example.com');
  insert into customers(organization_id,name,phone,email,last_visit_at,total_spent_minor,created_by,updated_by) select v_org,'Maya VIP','+96170000004','maya.vip@example.com',now()-interval '1 day',250000,v_uid,v_uid where not exists(select 1 from customers where organization_id=v_org and email='maya.vip@example.com');
  insert into customers(organization_id,name,phone,email,created_by,updated_by) select v_org,'New Customer','+96170000005','new.customer@example.com',v_uid,v_uid where not exists(select 1 from customers where organization_id=v_org and email='new.customer@example.com');
  select id into c1 from customers where organization_id=v_org and email='john.demo@example.com'; select id into c2 from customers where organization_id=v_org and email='sarah.inactive@example.com'; select id into c3 from customers where organization_id=v_org and email='daniel.noshow@example.com'; select id into c4 from customers where organization_id=v_org and email='maya.vip@example.com'; select id into c5 from customers where organization_id=v_org and email='new.customer@example.com';

  -- Current-day demo appointments in the business timezone.
  if not exists(select 1 from appointments where organization_id=v_org and notes='BOOKLY_DEMO_TODAY_1') then
    insert into appointments(organization_id,customer_id,staff_id,location_id,status,starts_at,ends_at,source,notes,created_by,updated_by) values(v_org,c1,s1,v_location,'confirmed',(d+time '10:00') at time zone tz,(d+time '10:30') at time zone tz,'reception','BOOKLY_DEMO_TODAY_1',v_uid,v_uid) returning id into a_today;
    insert into appointment_services(appointment_id,service_id,price_minor,duration_min) values(a_today,v_hair,2500,30);
  end if;
  if not exists(select 1 from appointments where organization_id=v_org and notes='BOOKLY_DEMO_TODAY_2') then
    insert into appointments(organization_id,customer_id,staff_id,location_id,status,starts_at,ends_at,source,notes,created_by,updated_by) values(v_org,c4,s2,v_location,'completed',(d+time '11:00') at time zone tz,(d+time '12:30') at time zone tz,'online','BOOKLY_DEMO_TODAY_2',v_uid,v_uid) returning id into a_tomorrow;
    insert into appointment_services(appointment_id,service_id,price_minor,duration_min) values(a_tomorrow,v_color,6500,90);
  end if;
  if not exists(select 1 from appointments where organization_id=v_org and notes='BOOKLY_DEMO_NO_SHOW') then
    insert into appointments(organization_id,customer_id,staff_id,location_id,status,starts_at,ends_at,source,notes,created_by,updated_by) values(v_org,c3,s3,v_location,'no_show',(d+time '13:00') at time zone tz,(d+time '13:30') at time zone tz,'reception','BOOKLY_DEMO_NO_SHOW',v_uid,v_uid) returning id into a_no_show;
    insert into appointment_services(appointment_id,service_id,price_minor,duration_min) values(a_no_show,v_hair,2500,30);
  end if;
  if not exists(select 1 from appointments where organization_id=v_org and notes='BOOKLY_DEMO_TOMORROW') then
    insert into appointments(organization_id,customer_id,staff_id,location_id,status,starts_at,ends_at,source,notes,created_by,updated_by) values(v_org,c5,s4,v_location,'confirmed',((d+1)+time '14:00') at time zone tz,((d+1)+time '14:45') at time zone tz,'online','BOOKLY_DEMO_TOMORROW',v_uid,v_uid) returning id into a_tomorrow;
    insert into appointment_services(appointment_id,service_id,price_minor,duration_min) values(a_tomorrow,v_nails,3000,45);
  end if;

  -- Fills out the status spread: pending, checked_in, cancelled. Times
  -- chosen not to overlap any staff member's existing demo appointment.
  if not exists(select 1 from appointments where organization_id=v_org and notes='BOOKLY_DEMO_PENDING') then
    insert into appointments(organization_id,customer_id,staff_id,location_id,status,starts_at,ends_at,source,notes,created_by,updated_by) values(v_org,c2,s2,v_location,'pending',(d+time '16:00') at time zone tz,(d+time '17:30') at time zone tz,'online','BOOKLY_DEMO_PENDING',v_uid,v_uid) returning id into a_pending;
    insert into appointment_services(appointment_id,service_id,price_minor,duration_min) values(a_pending,v_color,6500,90);
  end if;
  if not exists(select 1 from appointments where organization_id=v_org and notes='BOOKLY_DEMO_CHECKED_IN') then
    insert into appointments(organization_id,customer_id,staff_id,location_id,status,starts_at,ends_at,source,notes,created_by,updated_by) values(v_org,c1,s4,v_location,'checked_in',(d+time '09:00') at time zone tz,(d+time '09:45') at time zone tz,'reception','BOOKLY_DEMO_CHECKED_IN',v_uid,v_uid) returning id into a_checked_in;
    insert into appointment_services(appointment_id,service_id,price_minor,duration_min) values(a_checked_in,v_nails,3000,45);
  end if;
  if not exists(select 1 from appointments where organization_id=v_org and notes='BOOKLY_DEMO_CANCELLED') then
    insert into appointments(organization_id,customer_id,staff_id,location_id,status,starts_at,ends_at,source,notes,created_by,updated_by) values(v_org,c2,s1,v_location,'cancelled',(d+time '12:00') at time zone tz,(d+time '12:30') at time zone tz,'online','BOOKLY_DEMO_CANCELLED',v_uid,v_uid) returning id into a_cancelled;
    insert into appointment_services(appointment_id,service_id,price_minor,duration_min) values(a_cancelled,v_hair,2500,30);
  end if;

  if not exists(select 1 from queue_entries where organization_id=v_org and customer_id=c5 and status='waiting') then
    insert into queue_entries(organization_id,customer_id,service_id,staff_id,queue_number,estimated_wait_min)
    select v_org,c5,v_hair,s3,coalesce(max(queue_number),0)+1,15 from queue_entries where organization_id=v_org and (created_at at time zone tz)::date=d;
  end if;
  insert into payments(organization_id,appointment_id,amount_minor,method,type,status,idempotency_key,created_by)
  select v_org,id,2500,'cash','payment','completed','BOOKLY-DEMO-PAY-'||id::text,v_uid from appointments where organization_id=v_org and notes='BOOKLY_DEMO_TODAY_1' and not exists(select 1 from payments p where p.idempotency_key='BOOKLY-DEMO-PAY-'||appointments.id::text);
  insert into payments(organization_id,appointment_id,amount_minor,method,type,status,idempotency_key,created_by)
  select v_org,id,1500,'card','deposit','completed','BOOKLY-DEMO-DEP-'||id::text,v_uid from appointments where organization_id=v_org and notes='BOOKLY_DEMO_TOMORROW' and not exists(select 1 from payments p where p.idempotency_key='BOOKLY-DEMO-DEP-'||appointments.id::text);

  -- Reversed payment: a completed payment against the checked-in
  -- appointment, then its reversal — mirrors reverse_payment()'s own
  -- insert shape exactly (0009_security_fixes.sql) rather than guessing.
  insert into payments(organization_id,appointment_id,amount_minor,method,type,status,idempotency_key,created_by)
  select v_org,id,3000,'card','payment','completed','BOOKLY-DEMO-PAY3-'||id::text,v_uid from appointments where organization_id=v_org and notes='BOOKLY_DEMO_CHECKED_IN' and not exists(select 1 from payments p where p.idempotency_key='BOOKLY-DEMO-PAY3-'||appointments.id::text);
  select id into v_pay_to_reverse from payments where organization_id=v_org and idempotency_key like 'BOOKLY-DEMO-PAY3-%';
  if v_pay_to_reverse is not null and not exists(select 1 from payments where reversed_payment_id=v_pay_to_reverse) then
    insert into payments(organization_id,appointment_id,amount_minor,method,type,status,idempotency_key,reversed_payment_id,created_by)
    select organization_id,appointment_id,-abs(amount_minor),method,'refund','completed',gen_random_uuid()::text,id,v_uid
    from payments where id=v_pay_to_reverse;
  end if;

  insert into loyalty_accounts(organization_id,customer_id,points) values(v_org,c4,320) on conflict(customer_id) do update set points=greatest(loyalty_accounts.points,320);
  insert into loyalty_accounts(organization_id,customer_id,points) values(v_org,c1,100) on conflict(customer_id) do update set points=greatest(loyalty_accounts.points,100);
  insert into packages(organization_id,name,price_minor,service_id,total_uses,expires_days) select v_org,'Demo 5 Haircuts',10000,v_hair,5,90 where not exists(select 1 from packages where organization_id=v_org and name='Demo 5 Haircuts');
  select id into pkg from packages where organization_id=v_org and name='Demo 5 Haircuts';
  insert into memberships(organization_id,name,price_minor,discount_percent,duration_days) select v_org,'Demo Gold',5000,10,30 where not exists(select 1 from memberships where organization_id=v_org and name='Demo Gold');
  select id into mem from memberships where organization_id=v_org and name='Demo Gold';
  insert into customer_memberships(organization_id,membership_id,customer_id,starts_at,ends_at,status) select v_org,mem,c4,now(),now()+interval '30 days','active' where not exists(select 1 from customer_memberships where organization_id=v_org and membership_id=mem and customer_id=c4 and status='active');

  -- customer_packages had zero rows before this migration — packages
  -- existed in the catalog but nobody owned one.
  insert into customer_packages(organization_id,package_id,customer_id,remaining_uses,status,expires_at,created_by)
  select v_org,pkg,c1,5,'active',now()+interval '90 days',v_uid
  where not exists(select 1 from customer_packages where organization_id=v_org and package_id=pkg and customer_id=c1);

  insert into coupons(organization_id,code,discount_percent,expires_at,usage_limit,active) select v_org,'DEMO20',20,now()+interval '30 days',100,true where not exists(select 1 from coupons where organization_id=v_org and code='DEMO20');
  insert into campaigns(organization_id,name,segment,channel,message,status) select v_org,'Win Back Demo','inactive_30','email','We miss you! Enjoy 20% off your next visit.','draft' where not exists(select 1 from campaigns where organization_id=v_org and name='Win Back Demo');
  select id into camp from campaigns where organization_id=v_org and name='Win Back Demo';

  -- campaign_recipients had zero rows before this migration — the demo
  -- campaign existed as a draft nobody was ever targeted by. Direct insert
  -- rather than generate_campaign_recipients(), which depends on
  -- customer_segment() matching data this same function just wrote.
  insert into campaign_recipients(campaign_id,customer_id,opened_at)
  select camp,c2,now()-interval '1 hour' where not exists(select 1 from campaign_recipients where campaign_id=camp and customer_id=c2);
  insert into campaign_recipients(campaign_id,customer_id)
  select camp,c4 where not exists(select 1 from campaign_recipients where campaign_id=camp and customer_id=c4);

  select count(*) into n from customers where organization_id=v_org;
  return jsonb_build_object('organization_id',v_org,'customers',n,'staff',4,'demo',true,'timezone',tz);
end $$;
grant execute on function public.seed_demo_data_for_current_user() to authenticated;
