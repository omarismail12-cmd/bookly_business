# Bookly Business

A multi-tenant booking, queue, CRM and loyalty SaaS for service businesses
(salons, barbers, spas, clinics), built with Flutter + Riverpod + go_router
on a Supabase (PostgreSQL, Auth, Storage, Edge Functions) backend.

## Architecture

```
lib/
  app/            router, root widget
  core/           config, errors, security, permissions, localization, sync, theme
  features/       feature-first: auth, organisations (incl. locations management),
                   dashboard, appointments (booking + calendar), queue, customers
                   (incl. customers/loyalty for CRM/loyalty/campaigns), services,
                   staff (incl. breaks/blocked time), staff_portal (staff "Today"
                   view), payments, packages (packages/memberships/coupons
                   catalog), reports
  shared/         formatters, validators, widgets (incl. skeleton loading)
supabase/
  migrations/     numbered, additive SQL migrations (run in order, 0001..0022)
  functions/      Edge Functions (notifications-worker, send-push)
```

Feature folders follow `data` (Supabase/local data sources) / `domain` (models) /
`presentation` (widgets, pages) where the feature needs all three; simple
CRUD-over-RLS screens (e.g. `organisations/presentation`, `locations/presentation`)
talk to Supabase directly from `presentation` without a separate data/domain
layer.

Business logic and authorization live in the database (RPCs + RLS), not in
the Flutter client — the client calls `security definer` RPCs for every
state-changing operation (bookings, payments, status changes, redemptions),
and Postgres enforces tenant isolation and role permissions independently of
what the UI shows.

## Running locally

```
flutter pub get
flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
```

Without `SUPABASE_URL`/`SUPABASE_ANON_KEY` the app shows a configuration
placeholder instead of failing to boot.

## Database

Apply `supabase/migrations/*.sql` to a Supabase project, in numeric order, via
`supabase db push` or the SQL editor. Then call the
`seed_demo_data_for_current_user()` RPC as a signed-in user to populate a demo
salon (4 staff, services, customers, appointments, queue, payments, loyalty).

## Localization

English and Arabic (RTL) via `flutter_localizations` + generated
`AppLocalizations` (`lib/l10n/*.arb`, `l10n.yaml`). Run `flutter gen-l10n`
after editing the ARB files.

## Notifications

`supabase/functions/notifications-worker` reads due `notification_jobs` and
calls `supabase/functions/send-push` (FCM) — both are service-role-only Edge
Functions, never called with client credentials. The Flutter client's FCM
adapter (`lib/core/notifications/firebase_notification_service.dart`) is a
safe no-op until a real Firebase project (`google-services.json` /
`GoogleService-Info.plist`) is added to the platform projects.
