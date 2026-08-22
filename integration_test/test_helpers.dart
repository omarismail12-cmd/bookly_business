import 'dart:io';
import 'dart:math';

import 'package:supabase/supabase.dart';

/// Shared setup for the integration test suite (integration_test/*_test.dart).
///
/// These tests exercise the real Supabase backend — RPCs, RLS policies and
/// the booking exclusion constraint — against a live project, not mocks.
///
/// They deliberately use `package:supabase` (the plain Dart client) rather
/// than `package:supabase_flutter`, and are run with plain `dart test`
/// rather than `flutter test`:
///   - `flutter test` always wraps the run in `TestWidgetsFlutterBinding`,
///     which installs `HttpOverrides` that fake every HTTP request with a
///     400 response — by design, to stop widget tests from silently
///     depending on the network. That makes it structurally impossible to
///     reach a real backend from under `flutter test`, integration_test
///     directory or not.
///   - `flutter test`'s real device-driven mode
///     (`IntegrationTestWidgetsFlutterBinding`, which *does* allow real
///     networking) needs an actual device/browser driver — unavailable in
///     this environment (no Visual Studio toolchain for Windows desktop, no
///     Android emulator, and `flutter test integration_test` doesn't support
///     web at all).
///   - `supabase_flutter`'s `Supabase.initialize` also needs a
///     `shared_preferences` platform channel for session persistence, which
///     doesn't exist outside a real Flutter engine either.
/// The plain `supabase` package has none of these problems — it's a
/// straight HTTP/websocket client with no Flutter dependency — so
/// `dart test integration_test` runs these for real, against the real
/// database, from a plain Dart VM.
///
/// `dart test` has no `--dart-define`/`--define` of its own (that's a
/// `flutter test`/`dart compile` thing, tied to `String.fromEnvironment`
/// compile-time constants) — so, unlike the app itself, these read real OS
/// environment variables at runtime instead:
///
///   # bash
///   SUPABASE_URL=https://xxxx.supabase.co SUPABASE_ANON_KEY=... \
///     dart test integration_test
///
///   # PowerShell
///   $env:SUPABASE_URL="https://xxxx.supabase.co"; $env:SUPABASE_ANON_KEY="..."; `
///     dart test integration_test
///
/// Point this at a disposable test/staging Supabase project with the
/// migrations in supabase/migrations applied, and with email confirmation
/// disabled for auth.users — these tests sign up throwaway accounts and use
/// them immediately, the same assumption any CI-run Supabase integration
/// suite makes. Test data (orgs, users) is not cleaned up afterward; use a
/// project that gets reset periodically, not production.
final supabaseTestUrl = Platform.environment['SUPABASE_URL'] ?? '';
final supabaseTestAnonKey = Platform.environment['SUPABASE_ANON_KEY'] ?? '';

final _random = Random();

String randomEmail() =>
    'bookly-itest-${DateTime.now().millisecondsSinceEpoch}-'
    '${_random.nextInt(999999)}@example.com';

String randomSlug() =>
    'itest-${DateTime.now().millisecondsSinceEpoch}-${_random.nextInt(999999)}';

SupabaseClient? _client;

/// Returns the shared test client, creating it on first call.
SupabaseClient ensureSupabaseInitialized() {
  if (supabaseTestUrl.isEmpty || supabaseTestAnonKey.isEmpty) {
    throw StateError(
      'Integration tests need --define=SUPABASE_URL=... '
      '--define=SUPABASE_ANON_KEY=... pointing at a disposable test '
      'project (see the doc comment at the top of test_helpers.dart).',
    );
  }
  return _client ??= SupabaseClient(
    supabaseTestUrl,
    supabaseTestAnonKey,
    // PKCE (the package default) needs an async code-verifier store, which
    // supabase_flutter normally backs with shared_preferences — not
    // available to the plain client used here. These tests only ever do
    // direct email/password sign-up and sign-in (no OAuth redirect), so
    // PKCE buys nothing; the implicit flow needs no such storage.
    authOptions: const AuthClientOptions(authFlowType: AuthFlowType.implicit),
  );
}

typedef TestUser = ({String email, String password, String userId});

/// Signs up a fresh throwaway user, leaving them signed in.
Future<TestUser> signUpTestUser() async {
  final client = ensureSupabaseInitialized();
  final email = randomEmail();
  const password = 'Test1234!';
  final res = await client.auth.signUp(email: email, password: password);
  final user = res.user;
  if (user == null || res.session == null) {
    throw StateError(
      'Sign-up did not return an active session — check that the test '
      'project has email confirmation disabled for auth.users.',
    );
  }
  return (email: email, password: password, userId: user.id);
}

Future<void> signIn(String email, String password) async {
  await ensureSupabaseInitialized().auth.signInWithPassword(
    email: email,
    password: password,
  );
}

typedef TestOrg = ({String orgId, String serviceId, String staffId});

/// Creates a fresh org (via the same RPC OrganizationSetupPage uses) with
/// one service and one staff member who can perform it, owned by whoever is
/// currently signed in. Working hours are opened for every weekday so a
/// booking slot is always available regardless of when the suite runs.
Future<TestOrg> createTestOrgWithService() async {
  final client = ensureSupabaseInitialized();
  final orgId =
      await client.rpc(
            'create_organization_for_current_user',
            params: {
              'p_name': 'Integration Test Salon ${randomSlug()}',
              'p_slug': randomSlug(),
              'p_timezone': 'UTC',
            },
          )
          as String;

  final service = await client
      .from('services')
      .insert({
        'organization_id': orgId,
        'name': 'Test Service',
        'duration_min': 30,
        'price_minor': 5000,
      })
      .select()
      .single();

  final staff = await client
      .from('staff')
      .insert({'organization_id': orgId, 'display_name': 'Test Staff'})
      .select()
      .single();

  await client.from('staff_services').insert({
    'staff_id': staff['id'],
    'service_id': service['id'],
  });

  for (var weekday = 0; weekday < 7; weekday++) {
    await client.from('working_hours').insert({
      'staff_id': staff['id'],
      'weekday': weekday,
      'start_time': '00:00:00',
      'end_time': '23:45:00',
    });
  }

  return (
    orgId: orgId,
    serviceId: service['id'] as String,
    staffId: staff['id'] as String,
  );
}

Future<String> createTestCustomer(
  String orgId, {
  String name = 'Test Customer',
}) async {
  final row = await ensureSupabaseInitialized()
      .from('customers')
      .insert({'organization_id': orgId, 'name': name})
      .select()
      .single();
  return row['id'] as String;
}

/// A booking date far enough in the future to be stable across timezones
/// and never collide with a previous run's bookings for the same fresh org.
DateTime testBookingDate() =>
    DateTime.now().toUtc().add(const Duration(days: 2));
