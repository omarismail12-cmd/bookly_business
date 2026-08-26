-- Crash fix, verified against the actual schema: the customer portal's
-- Loyalty tab (customer_loyalty_page.dart) reads
--   loyalty_accounts.select('points,customers(name,organizations(name))')
-- which relies on PostgREST auto-detecting a foreign key from
-- loyalty_accounts.customer_id to customers.id to resolve the embedded
-- `customers(...)` join. That foreign key was never actually created:
-- 0003_crm_loyalty.sql defines
--   customer_id uuid not null unique
-- with no `references public.customers(id)` — unlike every sibling table
-- in the same migration (loyalty_transactions, customer_memberships,
-- package_usage all correctly reference customers(id)). PostgREST's
-- schema cache has nothing to find, so every request fails with
-- PGRST200 ("Could not find a relationship between 'loyalty_accounts'
-- and 'customers'").
--
-- Fix: add the missing foreign key, matching loyalty_transactions'
-- exact style (bare reference, no ON DELETE clause) since it's the
-- closest sibling table. The existing `unique` constraint on customer_id
-- is untouched — this only adds the relationship PostgREST needs.
-- Run after 0001..0036.

alter table public.loyalty_accounts
  add foreign key (customer_id) references public.customers(id);

-- Force PostgREST to pick up the new relationship immediately rather
-- than waiting for its next scheduled schema-cache reload.
NOTIFY pgrst, 'reload schema';
