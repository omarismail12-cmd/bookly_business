// Throwaway diagnostic — NOT part of the test suite. Deleted immediately
// after use. Purpose: make a genuinely anonymous (unauthenticated)
// link_staff_to_user_by_email call against the live project and print
// exactly what comes back, so we know for certain rather than guessing
// whether has_org_role() actually blocks an anon caller.
import 'dart:io';

import 'package:supabase/supabase.dart';

Future<void> main() async {
  final url = Platform.environment['SUPABASE_URL']!;
  final key = Platform.environment['SUPABASE_ANON_KEY']!;

  // No sign-in at all — this client has never authenticated. auth.uid()
  // inside any SECURITY DEFINER function called through it will be null,
  // exactly like a real anonymous website visitor.
  final anon = SupabaseClient(url, key);

  print('--- Step 1: find a real staff id via the public storefront read '
      'policy (staff_public_select, 0012_public_storefront_access.sql) ---');
  Object? staffId;
  try {
    final rows = await anon.from('staff').select('id').limit(1);
    final list = List<Map<String, dynamic>>.from(rows);
    if (list.isEmpty) {
      print('No staff rows visible to anon at all — cannot run the real '
          'probe below. (Unexpected: earlier test runs should have left '
          'staff rows behind.)');
      return;
    }
    staffId = list.first['id'];
    print('Using real staff id: $staffId');
  } catch (e) {
    print('Could not read any staff row as anon: $e');
    return;
  }

  print('\n--- Step 2: call link_staff_to_user_by_email as this anon '
      'client (no session) ---');
  try {
    final result = await anon.rpc(
      'link_staff_to_user_by_email',
      params: {
        'p_staff': staffId,
        'p_email': 'anon-probe-nonexistent-user@example.com',
      },
    );
    print('UNEXPECTED SUCCESS — RPC returned: $result');
    print('This means the anon call was NOT blocked at all.');
  } on PostgrestException catch (e) {
    print('PostgrestException — message: "${e.message}", code: ${e.code}');
    if (e.message.contains('FORBIDDEN')) {
      print('=> Blocked by has_org_role() as expected (FORBIDDEN raised '
          'before USER_NOT_FOUND would ever be reached).');
    } else if (e.message.contains('USER_NOT_FOUND') ||
        e.message.contains('STAFF_NOT_FOUND')) {
      print('=> NOT blocked by has_org_role() — the anon call got PAST '
          'the role check and failed on a later, unrelated check instead '
          '(${e.message}). This means an anon caller CAN reach and pass '
          'has_org_role() here.');
    } else {
      print('=> Got a different error than expected — see above, needs '
          'manual interpretation.');
    }
  } catch (e) {
    print('Non-Postgrest error: $e');
  }
}
