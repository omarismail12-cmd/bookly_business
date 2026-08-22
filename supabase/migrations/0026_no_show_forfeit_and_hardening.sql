-- Two independent fixes, both additive:
--
-- 1) No-show deposit forfeiture. effective_deposit_minor() (0011) already
--    raises the REQUIRED deposit for risky customers, but nothing ever
--    forfeited an already-COLLECTED deposit when an appointment is marked
--    no_show — 'forfeit' has been a valid payments.type value since
--    0002_booking_operations.sql but was never inserted anywhere. Without
--    this, "no-show deposit policy" only discourages booking, it never
--    actually charges anything for the no-show itself.
--
-- 2) queue_appointment_notifications() is granted to anon (needed so
--    create_public_booking(), itself anon-callable, can queue confirmation
--    notifications for an anonymous booking) but its own FORBIDDEN check
--    (0007) is skipped whenever auth.uid() is null — which means any
--    unauthenticated caller who knows/guesses an appointment id in ANY
--    organization can call it directly and reset that appointment's
--    reminder schedule. Revoking anon's direct EXECUTE grant closes this
--    without touching the function body: SECURITY DEFINER callers like
--    create_public_booking() still reach it fine because the internal
--    call is privilege-checked against the *definer* role, not the
--    original anon caller.

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
  v_deposit_paid bigint;
begin

  if p_status not in ('pending','confirmed','checked_in','in_service','completed','cancelled','no_show') then
    raise exception 'INVALID_STATUS';
  end if;

  select organization_id, status, customer_id, staff_id, deposit_paid_minor
  into v_org, v_old, v_customer, v_staff, v_deposit_paid
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

    if v_deposit_paid > 0 then
      insert into public.payments(
        organization_id, appointment_id, amount_minor, method, type, status, idempotency_key, created_by
      )
      values (
        v_org, p_appointment, v_deposit_paid, 'other', 'forfeit', 'completed',
        'forfeit_' || p_appointment::text, auth.uid()
      )
      on conflict (idempotency_key) do nothing;
    end if;
  end if;

  if p_status = 'completed' then
    update public.customers set last_visit_at = now(), updated_at = now() where id = v_customer;
  end if;

  insert into public.audit_logs(organization_id, user_id, action, entity, entity_id, old_data, new_data)
  values (v_org, auth.uid(), 'status_change', 'appointment', p_appointment, jsonb_build_object('status', v_old), jsonb_build_object('status', p_status));

end;
$$;

grant execute on function public.change_appointment_status(uuid, text) to authenticated;

revoke execute on function public.queue_appointment_notifications(uuid) from anon;
