// Throwaway diagnostic — NOT part of the test suite. Deleted immediately
// after use.
//
// Purpose: the first probe found that an anon client reading `staff`
// failed with "permission denied for function current_org_ids" instead of
// a clean RLS-filtered result. That's alarming because staff_public_select
// (0012_public_storefront_access.sql) is supposed to let anon read staff
// for the public booking page. This script:
//   1. Creates a real org/service/staff/location as a signed-in user (so
//      there's real data and a real slug to test against).
//   2. Signs that client back out (genuinely anonymous from then on).
//   3. Runs the exact query shapes booking_page.dart's public mode uses
//      against organizations/services/staff/locations, and separately
//      re-attempts the link_staff_to_user_by_email anon check now that a
//      real staff id exists.
import 'dart:io';
import 'dart:math';

import 'package:supabase/supabase.dart';

final _random = Random();

Future<void> main() async {
  final url = Platform.environment['SUPABASE_URL']!;
  final key = Platform.environment['SUPABASE_ANON_KEY']!;

  final client = SupabaseClient(
    url,
    key,
    // PKCE (the package default) needs an async code-verifier store not
    // available outside supabase_flutter — see test_helpers.dart's doc
    // comment. Implicit flow needs no such storage.
    authOptions: const AuthClientOptions(authFlowType: AuthFlowType.implicit),
  );

  final email = 'bookly-itest-probe-${DateTime.now().millisecondsSinceEpoch}-'
      '${_random.nextInt(999999)}@example.com';
  const password = 'Test1234!';
  await client.auth.signUp(email: email, password: password);

  final slug = 'itest-probe-${DateTime.now().millisecondsSinceEpoch}';
  final orgId = await client.rpc(
    'create_organization_for_current_user',
    params: {'p_name': 'Anon Probe Org', 'p_slug': slug, 'p_timezone': 'UTC'},
  ) as String;

  final service = await client
      .from('services')
      .insert({
        'organization_id': orgId,
        'name': 'Probe Service',
        'duration_min': 30,
        'price_minor': 1000,
      })
      .select()
      .single();

  final staff = await client
      .from('staff')
      .insert({'organization_id': orgId, 'display_name': 'Probe Staff'})
      .select()
      .single();

  await client.from('locations').insert({
    'organization_id': orgId,
    'name': 'Probe Location',
  });

  print('Created org=$orgId slug=$slug service=${service['id']} '
      'staff=${staff['id']}');

  await client.auth.signOut();
  print('\nSigned out. From here on this client is genuinely anonymous.\n');

  Future<void> probe(String label, Future<dynamic> Function() run) async {
    try {
      final result = await run();
      final n = result is List ? result.length : 1;
      print('OK   $label -> $n row(s)');
    } on PostgrestException catch (e) {
      print('FAIL $label -> PostgrestException: "${e.message}" '
          '(code: ${e.code})');
    } catch (e) {
      print('FAIL $label -> $e');
    }
  }

  // Exact shape booking_page.dart's public mode uses (org resolution by slug).
  await probe(
    'organizations by slug (booking_page.dart public-mode org lookup)',
    () => client
        .from('organizations')
        .select('id,name,timezone,currency')
        .eq('slug', slug)
        .eq('status', 'active')
        .limit(1),
  );

  await probe(
    'services for org (booking_page.dart)',
    () => client
        .from('services')
        .select()
        .eq('organization_id', orgId)
        .isFilter('deleted_at', null)
        .order('name'),
  );

  await probe(
    'staff for org, active only (booking_page.dart)',
    () => client
        .from('staff')
        .select()
        .eq('organization_id', orgId)
        .eq('status', 'active')
        .order('display_name'),
  );

  await probe(
    'locations for org (booking_page.dart)',
    () => client
        .from('locations')
        .select('id,name')
        .eq('organization_id', orgId)
        .isFilter('deleted_at', null)
        .order('name'),
  );

  await probe(
    'get_available_slots RPC (anon-granted per 0015)',
    () => client.rpc(
      'get_available_slots',
      params: {
        'p_staff': staff['id'],
        'p_service': service['id'],
        'p_date': DateTime.now().add(const Duration(days: 2)).toIso8601String().substring(0, 10),
      },
    ),
  );

  print('\n--- link_staff_to_user_by_email, now with a real staff id ---');
  try {
    final result = await client.rpc(
      'link_staff_to_user_by_email',
      params: {
        'p_staff': staff['id'],
        'p_email': 'anon-probe-nonexistent-user@example.com',
      },
    );
    print('UNEXPECTED SUCCESS -> $result');
  } on PostgrestException catch (e) {
    print('PostgrestException -> message: "${e.message}", code: ${e.code}');
    if (e.message.contains('FORBIDDEN')) {
      print('=> Blocked by has_org_role() as expected.');
    } else {
      print('=> NOT blocked by has_org_role() (or blocked by something '
          'else entirely — see message above).');
    }
  } catch (e) {
    print('Non-Postgrest error -> $e');
  }
}
