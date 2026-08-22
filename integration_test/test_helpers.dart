import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Shared setup for the integration test suite (integration_test/*_test.dart).
///
/// These tests exercise the real Supabase backend — RPCs, RLS policies and
/// the booking exclusion constraint — against a live project, not mocks.
/// Run them the same way the app itself is configured (see
/// lib/core/config/app_config.dart):
///
///   flutter test integration_test \
///     --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///     --dart-define=SUPABASE_ANON_KEY=...
///
/// Point this at a disposable test/staging Supabase project with the
/// migrations in supabase/migrations applied, and with email confirmation
/// disabled for auth.users — these tests sign up throwaway accounts and use
/// them immediately, the same assumption any CI-run Supabase integration
/// suite makes. Test data (orgs, users) is not cleaned up afterward; use a
/// project that gets reset periodically, not production.
const supabaseTestUrl = String.fromEnvironment('SUPABASE_URL');
const supabaseTestAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

final _random = Random();

String randomEmail() =>
    'bookly-itest-${DateTime.now().millisecondsSinceEpoch}-'
    '${_random.nextInt(999999)}@example.com';

String randomSlug() =>
    'itest-${DateTime.now().millisecondsSinceEpoch}-${_random.nextInt(999999)}';

Future<void> ensureSupabaseInitialized() async {
  if (supabaseTestUrl.isEmpty || supabaseTestAnonKey.isEmpty) {
    throw StateError(
      'Integration tests need --dart-define=SUPABASE_URL=... '
      '--dart-define=SUPABASE_ANON_KEY=... pointing at a disposable test '
      'project (see the doc comment at the top of test_helpers.dart).',
    );
  }
  try {
    // Already initialized by an earlier test in this isolate.
    // ignore: unnecessary_statements
    Supabase.instance;
  } catch (_) {
    await Supabase.initialize(
      url: supabaseTestUrl,
      anonKey: supabaseTestAnonKey,
    );
  }
}

typedef TestUser = ({String email, String password, String userId});

/// Signs up a fresh throwaway user, leaving them signed in.
Future<TestUser> signUpTestUser() async {
  final client = Supabase.instance.client;
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
  await Supabase.instance.client.auth.signInWithPassword(
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
  final client = Supabase.instance.client;
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
  final row = await Supabase.instance.client
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
