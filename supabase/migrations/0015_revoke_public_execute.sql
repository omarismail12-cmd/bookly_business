-- Defense-in-depth: PostgreSQL grants EXECUTE to the PUBLIC pseudo-role on
-- every function by default at CREATE FUNCTION time. None of migrations
-- 0001-0014 ever revoked it, so — verified live via `supabase db advisors`
-- and confirmed by direct anon-key RPC calls — every SECURITY DEFINER
-- function in this schema (record_payment, reverse_payment, set_member_role,
-- change_appointment_status, redeem_coupon, sell_package, ... ~30 total) is
-- technically callable by the anon role today, not just by `authenticated`.
--
-- Tested and confirmed NOT currently exploitable: every one of these
-- functions independently checks auth.uid()/has_org_role() before doing
-- anything, so an anon caller hits FORBIDDEN/NOT_AUTHENTICATED every time
-- (has_org_role() looks up organization_members by user_id = auth.uid(),
-- which is null for anon, so it always returns false). But relying on every
-- function remembering that check, forever, is fragile — a future function
-- that forgets it would be silently exploitable by anyone with the
-- public/anon key (which is not a secret). Fix it at the grant level
-- instead: strip the blanket PUBLIC grant, keep only the explicit `to
-- authenticated` grants already made across prior migrations (untouched by
-- this — revoking FROM PUBLIC does not touch separate grants to other
-- roles), and re-grant exactly the two functions meant to be public.
-- Run after 0001..0014.

revoke execute on all functions in schema public from public;

-- Applies to functions created by future migrations too, so this doesn't
-- silently regress the next time someone adds a SECURITY DEFINER function.
alter default privileges in schema public revoke execute on functions from public;

-- The only two RPCs genuinely meant to be called by a signed-out visitor
-- (public storefront browsing + booking).
grant execute on function public.get_available_slots(uuid, uuid, date, uuid) to anon, authenticated;
grant execute on function public.create_public_booking(text, text, text, text, uuid, uuid, timestamptz, uuid) to anon, authenticated;

-- queue_appointment_notifications is called internally by
-- create_public_booking() while it may still be running as an anon caller
-- (SECURITY DEFINER doesn't change auth.uid() from the original caller's
-- JWT), so it needs the same anon grant it already had from 0007/0014.
grant execute on function public.queue_appointment_notifications(uuid) to anon, authenticated;
