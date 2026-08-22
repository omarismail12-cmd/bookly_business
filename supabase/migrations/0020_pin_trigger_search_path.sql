-- Minor hardening flagged by `supabase db advisors` (function_search_path_mutable):
-- set_updated_at() (0001) never pinned search_path, unlike every other
-- function in this schema. Low real risk (no dynamic SQL, no
-- schema-ambiguous references inside it) but free to fix and keeps the
-- schema consistent with the rest of the functions.
-- Run after 0001..0019.

create or replace function public.set_updated_at() returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = now();
  new.version = old.version + 1;
  return new;
end;
$$;
