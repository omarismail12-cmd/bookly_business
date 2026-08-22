-- Staff Today view: a short free-text field staff can leave for the next
-- visit ("add next recommendation"), separate from private_notes (general
-- customer notes) and appointments.notes (per-booking notes from the
-- booking flow). Readable/writable under the same RLS policies as
-- private_notes since it lives on the same customers row.
alter table public.customers add column if not exists next_recommendation text;
