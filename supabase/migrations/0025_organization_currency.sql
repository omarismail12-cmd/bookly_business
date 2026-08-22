-- Businesses outside the US need their own currency, not a hardcoded "USD"
-- literal in the client (lib/shared/formatters/currency.dart). All monetary
-- amounts already store minor units without a currency code, so this is
-- purely a display-formatting concern.
alter table public.organizations add column if not exists currency text not null default 'USD';
