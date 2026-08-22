import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/security/org_context.dart';
import '../../../../shared/formatters/currency.dart';

class PaymentsPage extends ConsumerStatefulWidget {
  const PaymentsPage({super.key});

  @override
  ConsumerState<PaymentsPage> createState() => _PaymentsPageState();
}

class _PaymentsPageState extends ConsumerState<PaymentsPage> {
  List<Map<String, dynamic>> rows = [];
  List<dynamic> appointments = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(load);
  }

  Future<void> load() async {
    final organizationId = await ref.read(activeOrganizationProvider.future);
    if (organizationId == null) {
      return;
    }

    final client = Supabase.instance.client;
    final payments = await client
        .from('payments')
        .select('*,appointments(customers(name))')
        .eq('organization_id', organizationId)
        .order('created_at', ascending: false)
        .limit(100);

    final appointmentsList = await client
        .from('appointments')
        .select('id,starts_at,customers(name)')
        .eq('organization_id', organizationId)
        .inFilter('status', [
          'confirmed',
          'checked_in',
          'in_service',
          'completed',
        ])
        .order('starts_at', ascending: false)
        .limit(100);

    if (!mounted) return;

    setState(() {
      rows = List<Map<String, dynamic>>.from(payments);
      appointments = List<dynamic>.from(appointmentsList);
      loading = false;
    });
  }

  Future<void> addPayment() async {
    String? appointment;
    String method = 'cash';
    String type = 'payment';
    final amount = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocal) {
          return AlertDialog(
            title: const Text('Record payment'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: appointment,
                  decoration: const InputDecoration(labelText: 'Appointment'),
                  items: appointments.map((item) {
                    final customer =
                        (item['customers'] as Map?)?['name'] ?? 'Customer';
                    return DropdownMenuItem<String>(
                      value: item['id'],
                      child: Text(
                        '$customer • ${DateTime.parse(item['starts_at']).toLocal()}',
                      ),
                    );
                  }).toList(),
                  onChanged: (value) => setLocal(() => appointment = value),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amount,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Amount (minor units)',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: method,
                  decoration: const InputDecoration(labelText: 'Method'),
                  items: const [
                    DropdownMenuItem(value: 'cash', child: Text('Cash')),
                    DropdownMenuItem(value: 'card', child: Text('Card')),
                    DropdownMenuItem(
                      value: 'transfer',
                      child: Text('Transfer'),
                    ),
                    DropdownMenuItem(value: 'online', child: Text('Online')),
                  ],
                  onChanged: (value) =>
                      setLocal(() => method = value ?? 'cash'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: type,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: const [
                    DropdownMenuItem(value: 'payment', child: Text('Payment')),
                    DropdownMenuItem(value: 'deposit', child: Text('Deposit')),
                  ],
                  onChanged: (value) =>
                      setLocal(() => type = value ?? 'payment'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(
                  context,
                  appointment != null &&
                      int.tryParse(amount.text.trim()) != null,
                ),
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );

    if (ok != true) return;

    try {
      await Supabase.instance.client.rpc(
        'record_payment',
        params: {
          'p_idempotency': const Uuid().v4(),
          'p_appointment': appointment,
          'p_amount': int.parse(amount.text.trim()),
          'p_method': method,
          'p_type': type,
        },
      );
      await load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Payment failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: loading ? null : addPayment,
        icon: const Icon(Icons.add_card),
        label: const Text('Payment'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: load,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    'Payments',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  ...rows.map((row) {
                    final customer =
                        ((row['appointments'] as Map?)?['customers']
                            as Map?)?['name'] ??
                        'Customer';
                    return Card(
                      child: ListTile(
                        title: Text(customer.toString()),
                        subtitle: Text(
                          '${row['method']} • ${row['type']} • ${row['status']}',
                        ),
                        trailing: Text(
                          formatMinor((row['amount_minor'] as num).toInt()),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
    );
  }
}
