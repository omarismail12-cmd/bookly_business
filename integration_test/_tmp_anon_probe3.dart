// Throwaway diagnostic — NOT part of the test suite. Deleted immediately
// after use.
//
// Purpose: re-verify, post-0035_fix_anon_storefront_rls.sql, that the
// public booking flow's anon reads (organizations/services/staff/locations)
// now return real data instead of "permission denied for function
// current_org_ids". Same shape as the pre-fix probe that found the bug.
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

  await client.from('staff_services').insert({
    'staff_id': staff['id'],
    'service_id': service['id'],
  });

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
      print('OK   $label -> $n row(s): $result');
    } on PostgrestException catch (e) {
      print('FAIL $label -> PostgrestException: "${e.message}" '
          '(code: ${e.code})');
    } catch (e) {
      print('FAIL $label -> $e');
    }
  }

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
    'staff_services for org (booking_page.dart eligibility filter)',
    () => client
        .from('staff_services')
        .select()
        .eq('staff_id', staff['id']),
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
}
