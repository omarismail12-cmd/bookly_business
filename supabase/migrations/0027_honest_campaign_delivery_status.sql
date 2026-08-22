-- send_campaign() (0010, patched 0018) marks EVERY channel 'sent' once
-- recipients are generated — including email/sms, which have no configured
-- delivery provider (supabase/functions has no email/SMS sender, only
-- notifications-worker/send-push for push via FCM). That means an
-- owner/manager sees "sent" for a campaign that was never actually
-- delivered to a single recipient. Only push campaigns are genuinely
-- delivered (real notification_jobs rows the notifications-worker cron
-- actually processes). This is a truthfulness fix, not a new integration:
-- email/sms recipients are still generated and audited, just never
-- reported as delivered when nothing was sent.
create or replace function public.send_campaign(p_campaign uuid)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  c record;
  v_queued int := 0;
begin

  select * into c from public.campaigns where id = p_campaign;

  if not found then
    raise exception 'CAMPAIGN_NOT_FOUND';
  end if;

  if not public.has_org_role(c.organization_id, array['owner','manager']) then
    raise exception 'FORBIDDEN';
  end if;

  if c.sent_at is not null then return 0; end if;

  if not exists(select 1 from public.campaign_recipients where campaign_id = p_campaign) then
    perform public.generate_campaign_recipients(p_campaign);
  end if;

  if c.channel = 'push' then
    insert into public.notification_jobs(organization_id, campaign_id, recipient_customer_id, kind, title, body, scheduled_for)
    select c.organization_id, p_campaign, cr.customer_id, 'campaign', c.name, c.message, now()
    from public.campaign_recipients cr
    where cr.campaign_id = p_campaign
    on conflict (campaign_id, recipient_customer_id) where campaign_id is not null do nothing;

    get diagnostics v_queued = row_count;

    update public.campaigns set status = 'sent', sent_at = now() where id = p_campaign;
  else
    select count(*) into v_queued from public.campaign_recipients where campaign_id = p_campaign;

    -- Recipients are generated and available for reporting, but nothing
    -- was actually delivered: no email/SMS provider is configured. Leave
    -- sent_at null (it is the "genuinely delivered" marker) so this never
    -- gets reported as sent.
    update public.campaigns set status = 'undeliverable' where id = p_campaign;
  end if;

  insert into public.audit_logs(organization_id, user_id, action, entity, entity_id, new_data)
  values (c.organization_id, auth.uid(), 'send', 'campaign', p_campaign, jsonb_build_object('channel', c.channel, 'queued', v_queued, 'status', case when c.channel = 'push' then 'sent' else 'undeliverable' end));

  return v_queued;

end;
$$;

grant execute on function public.send_campaign(uuid) to authenticated;
