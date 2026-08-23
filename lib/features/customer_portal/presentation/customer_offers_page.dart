import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/localization/gen/app_localizations.dart';
import '../../../shared/formatters/currency.dart';
import '../../../shared/widgets/async_state.dart';

/// Active coupons and personalized campaign messages for the signed-in
/// customer, across every business — visible via the coupons_self_select /
/// campaign_recipients_self_select / campaigns_self_select RLS policies in
/// 0029_customer_offers_access.sql (same customers.profile_id = auth.uid()
/// pattern CustomerLoyaltyPage already relies on for loyalty/packages).
class CustomerOffersPage extends StatefulWidget {
  const CustomerOffersPage({super.key});

  @override
  State<CustomerOffersPage> createState() => _CustomerOffersPageState();
}

class _CustomerOffersPageState extends State<CustomerOffersPage> {
  List<Map<String, dynamic>> campaigns = [];
  List<Map<String, dynamic>> coupons = [];
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
      final recipients = await c
          .from('campaign_recipients')
          .select(
            'id,opened_at,booked_at,'
            'campaigns(name,message,channel,organizations(name))',
          );
      final activeCoupons = await c
          .from('coupons')
          .select(
            'code,discount_percent,discount_minor,expires_at,'
            'organizations(name,currency)',
          )
          .order('code');
      if (mounted) {
        setState(() {
          campaigns = List<Map<String, dynamic>>.from(recipients);
          coupons = List<Map<String, dynamic>>.from(activeCoupons);
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
    final empty = campaigns.isEmpty && coupons.isEmpty;
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: empty
            ? [
                Padding(
                  padding: const EdgeInsets.only(top: 48),
                  child: EmptyState(message: l10n.offersEmpty),
                ),
              ]
            : [
                if (campaigns.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      l10n.offersForYou,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  ...campaigns.map((x) {
                    final campaign = x['campaigns'] as Map?;
                    final org = (campaign?['organizations'] as Map?)?['name'];
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.campaign_outlined),
                        title: Text(campaign?['name']?.toString() ?? ''),
                        subtitle: Text(
                          '${campaign?['message'] ?? ''}'
                          '${org != null ? '\n$org' : ''}',
                        ),
                        isThreeLine: org != null,
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                ],
                if (coupons.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      l10n.offersActiveCoupons,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  ...coupons.map((x) {
                    final org = x['organizations'] as Map?;
                    final currency = (org?['currency'] as String?) ?? 'USD';
                    final pct = x['discount_percent'] as num?;
                    final minor = (x['discount_minor'] as num?)?.toInt();
                    final value = pct != null
                        ? '$pct%'
                        : formatMinor(minor ?? 0, currency: currency);
                    final expiresAt = x['expires_at'] as String?;
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.local_offer_outlined),
                        title: Text(x['code']?.toString() ?? ''),
                        subtitle: Text(
                          '${org?['name'] ?? ''}'
                          '${expiresAt != null ? ' • expires ${DateTime.parse(expiresAt).toLocal().toString().substring(0, 10)}' : ''}',
                        ),
                        trailing: Text(
                          value,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    );
                  }),
                ],
              ],
      ),
    );
  }
}
