import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/localization/gen/app_localizations.dart';
import '../../../shared/widgets/async_state.dart';

/// Loyalty points, packages and memberships for the signed-in customer,
/// across every business — visible via the *_self_select RLS policies in
/// 0013_customer_portal.sql (customers.profile_id = auth.uid()).
class CustomerLoyaltyPage extends StatefulWidget {
  const CustomerLoyaltyPage({super.key});

  @override
  State<CustomerLoyaltyPage> createState() => _CustomerLoyaltyPageState();
}

class _CustomerLoyaltyPageState extends State<CustomerLoyaltyPage> {
  List<Map<String, dynamic>> loyalty = [];
  List<Map<String, dynamic>> packages = [];
  List<Map<String, dynamic>> memberships = [];
  bool loading = true;
  Object? error;

  @override
  void initState() {
    super.initState();
    Future.microtask(load);
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final c = Supabase.instance.client;
      final l = await c
          .from('loyalty_accounts')
          .select('points,customers(name,organizations(name))');
      final p = await c
          .from('customer_packages')
          .select('remaining_uses,status,expires_at,packages(name)')
          .eq('status', 'active');
      final m = await c
          .from('customer_memberships')
          .select('status,ends_at,memberships(name)')
          .eq('status', 'active');
      if (mounted) {
        setState(() {
          loyalty = List<Map<String, dynamic>>.from(l);
          packages = List<Map<String, dynamic>>.from(p);
          memberships = List<Map<String, dynamic>>.from(m);
          loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e;
          loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) return AsyncErrorView(error: error!, onRetry: load);
    final empty = loyalty.isEmpty && packages.isEmpty && memberships.isEmpty;
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: empty
            ? [
                Padding(
                  padding: const EdgeInsets.only(top: 48),
                  child: EmptyState(message: l10n.loyaltyEmpty),
                ),
              ]
            : [
                ...loyalty.map((x) {
                  final org =
                      (x['customers'] as Map?)?['organizations'] as Map?;
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.card_giftcard),
                      title: Text(org?['name'] ?? ''),
                      trailing: Text(
                        l10n.loyaltyPoints('${x['points'] ?? 0}'),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  );
                }),
                ...packages.map(
                  (x) => Card(
                    child: ListTile(
                      leading: const Icon(Icons.confirmation_number_outlined),
                      title: Text((x['packages'] as Map?)?['name'] ?? ''),
                      subtitle: Text('${x['remaining_uses']} uses left'),
                    ),
                  ),
                ),
                ...memberships.map(
                  (x) => Card(
                    child: ListTile(
                      leading: const Icon(Icons.workspace_premium_outlined),
                      title: Text((x['memberships'] as Map?)?['name'] ?? ''),
                      subtitle: Text(
                        'Until ${DateTime.parse(x['ends_at']).toLocal().toString().substring(0, 10)}',
                      ),
                    ),
                  ),
                ),
              ],
      ),
    );
  }
}
