-- 0015 revoked EXECUTE from the PUBLIC pseudo-role, but that didn't fix
-- anything: verified live that `anon` still has a *direct* EXECUTE grant on
-- every function in the schema, including record_payment, set_member_role,
-- reverse_payment, etc. This isn't from any migration in this project —
-- it's Supabase's own platform-level default privileges for the `public`
-- schema (grants EXECUTE on every new function straight to `anon` and
-- `authenticated` at creation time, so PostgREST works out of the box).
-- ALTER DEFAULT PRIVILEGES only affects objects created after it runs, and
-- these ~30 functions already exist, so the only fix for what's live today
-- is an explicit per-function REVOKE. Verified before this migration (via
-- `information_schema.role_routine_grants`) that anon really did hold
-- EXECUTE on all of these; re-verify after with the same query.
-- Run after 0001..0015.

revoke execute on function public.add_walk_in(uuid, uuid, uuid) from anon;
revoke execute on function public.award_loyalty_for_payment(uuid) from anon;
revoke execute on function public.cancel_appointment(uuid) from anon;
revoke execute on function public.change_appointment_status(uuid, text) from anon;
revoke execute on function public.change_queue_status(uuid, text) from anon;
revoke execute on function public.claim_customer_identity(uuid, text, text, text) from anon;
revoke execute on function public.create_booking(uuid, uuid, uuid, uuid, uuid, timestamptz, text, uuid, text) from anon;
revoke execute on function public.create_organization_for_current_user(text, text, text) from anon;
revoke execute on function public.current_org_ids() from anon;
revoke execute on function public.customer_segment(uuid, text) from anon;
revoke execute on function public.effective_deposit_minor(uuid, bigint, bigint) from anon;
revoke execute on function public.generate_campaign_recipients(uuid) from anon;
revoke execute on function public.get_my_memberships() from anon;
revoke execute on function public.has_org_role(uuid, text[]) from anon;
revoke execute on function public.purchase_membership(uuid, uuid, uuid, text) from anon;
revoke execute on function public.recalculate_queue_wait(uuid) from anon;
revoke execute on function public.record_payment(uuid, uuid, bigint, text, text) from anon;
revoke execute on function public.redeem_coupon(uuid, text, uuid, uuid) from anon;
revoke execute on function public.redeem_loyalty_points(uuid, bigint, text) from anon;
revoke execute on function public.redeem_package_use(uuid, uuid) from anon;
revoke execute on function public.report_dashboard(uuid, timestamptz, timestamptz) from anon;
revoke execute on function public.reschedule_appointment(uuid, timestamptz) from anon;
revoke execute on function public.reverse_payment(uuid, text) from anon;
revoke execute on function public.seed_demo_data_for_current_user() from anon;
revoke execute on function public.sell_package(uuid, uuid, uuid, text) from anon;
revoke execute on function public.send_campaign(uuid) from anon;
revoke execute on function public.set_member_role(uuid, uuid, text) from anon;
revoke execute on function public.set_member_role_by_email(uuid, text, text) from anon;

-- Trigger functions: not practically callable outside a trigger context
-- anyway (Postgres refuses direct invocation), revoked for cleanliness.
revoke execute on function public.handle_new_profile() from anon;
revoke execute on function public.set_updated_at() from anon;
revoke execute on function public.set_appointment_blocking_end() from anon;
revoke execute on function public.refresh_appointment_blocking_end() from anon;
