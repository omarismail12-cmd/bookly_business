import 'package:supabase_flutter/supabase_flutter.dart';

class OrganizationRepository {
  final SupabaseClient client;
  OrganizationRepository(this.client);
  Future<List<Map<String, dynamic>>> myOrganizations() async =>
      List<Map<String, dynamic>>.from(
        await client
            .from('organization_members')
            .select('organization_id, role, organizations(*)')
            .eq('user_id', client.auth.currentUser!.id)
            .eq('status', 'active'),
      );
  Future<String> create(String name, String slug, String timezone) =>
      client.rpc(
        'create_organization_for_current_user',
        params: {'p_name': name, 'p_slug': slug, 'p_timezone': timezone},
      );
}
