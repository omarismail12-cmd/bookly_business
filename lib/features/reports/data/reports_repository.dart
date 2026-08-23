import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_provider.dart';
import '../domain/report_dashboard.dart';

/// Wraps the `report_dashboard` RPC — the only Supabase call the reports
/// feature makes. All aggregation happens server-side (see
/// supabase/migrations/0010_features_completion.sql); this repository never
/// queries appointments/payments/etc. directly, so reports stay off the
/// realtime path per the architecture contract.
class ReportsRepository {
  final SupabaseClient client;
  ReportsRepository(this.client);

  Future<ReportDashboard> dashboard({
    required String organizationId,
    required DateTime from,
    required DateTime to,
  }) async {
    final result = await client.rpc(
      'report_dashboard',
      params: {
        'p_org': organizationId,
        'p_from': from.toUtc().toIso8601String(),
        'p_to': to.toUtc().toIso8601String(),
      },
    );
    return ReportDashboard.fromMap(Map<String, dynamic>.from(result as Map));
  }
}

final reportsRepositoryProvider = Provider<ReportsRepository>(
  (ref) => ReportsRepository(ref.watch(supabaseProvider)),
);
