import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/localization/gen/app_localizations.dart';
import '../../../shared/widgets/sync_status_banner.dart';
import 'customer_loyalty_page.dart';
import 'find_business_page.dart';
import 'my_appointments_page.dart';

/// Customer portal shell — the customer-facing counterpart to
/// BusinessShell. Deliberately much simpler: no role gating (every signed
/// in customer sees the same three tabs), no organization concept (a
/// customer isn't a member of any organization; their data is scoped by
/// customers.profile_id via RLS).
class CustomerShell extends StatefulWidget {
  const CustomerShell({super.key});

  @override
  State<CustomerShell> createState() => _CustomerShellState();
}

class _CustomerShellState extends State<CustomerShell> {
  int index = 0;

  Future<void> logout() => Supabase.instance.client.auth.signOut();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final pages = [
      const MyAppointmentsPage(),
      const FindBusinessPage(),
      const CustomerLoyaltyPage(),
    ];
    final labels = [l10n.navMyAppointments, l10n.navFindBook, l10n.navLoyalty];
    final icons = [
      Icons.event_note_outlined,
      Icons.add_circle_outline,
      Icons.card_giftcard_outlined,
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(labels[index]),
        actions: [
          IconButton(onPressed: logout, icon: const Icon(Icons.logout)),
        ],
      ),
      body: Column(
        children: [
          const SyncStatusBanner(),
          Expanded(child: pages[index]),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (v) => setState(() => index = v),
        destinations: [
          for (var i = 0; i < labels.length; i++)
            NavigationDestination(icon: Icon(icons[i]), label: labels[i]),
        ],
      ),
    );
  }
}
