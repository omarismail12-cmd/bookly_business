import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Appointment detail for a staff member: read-only customer info, plus two
/// editable free-text fields staff are expected to keep current —
/// private_notes (general customer notes) and next_recommendation (what to
/// suggest at the customer's next visit).
class StaffAppointmentDetailPage extends StatefulWidget {
  final Map<String, dynamic> appointment;
  const StaffAppointmentDetailPage({super.key, required this.appointment});

  @override
  State<StaffAppointmentDetailPage> createState() =>
      _StaffAppointmentDetailPageState();
}

class _StaffAppointmentDetailPageState
    extends State<StaffAppointmentDetailPage> {
  final supabase = Supabase.instance.client;
  late final TextEditingController notes;
  late final TextEditingController recommendation;
  bool saving = false;

  Map<String, dynamic>? get customer =>
      widget.appointment['customers'] as Map<String, dynamic>?;
  String? get customerId => widget.appointment['customer_id'] as String?;

  @override
  void initState() {
    super.initState();
    notes = TextEditingController(
      text: (customer?['private_notes'] as String?) ?? '',
    );
    recommendation = TextEditingController(
      text: (customer?['next_recommendation'] as String?) ?? '',
    );
    _loadCustomerDetails();
  }

  @override
  void dispose() {
    notes.dispose();
    recommendation.dispose();
    super.dispose();
  }

  Future<void> _loadCustomerDetails() async {
    final id = customerId;
    if (id == null) return;
    try {
      final row = await supabase
          .from('customers')
          .select('private_notes,next_recommendation')
          .eq('id', id)
          .maybeSingle();
      if (row != null && mounted) {
        setState(() {
          notes.text = (row['private_notes'] as String?) ?? '';
          recommendation.text = (row['next_recommendation'] as String?) ?? '';
        });
      }
    } catch (_) {
      // Fields fall back to whatever the appointment payload already had.
    }
  }

  Future<void> save() async {
    final id = customerId;
    if (id == null) return;
    setState(() => saving = true);
    try {
      await supabase
          .from('customers')
          .update({
            'private_notes': notes.text.trim(),
            'next_recommendation': recommendation.text.trim(),
          })
          .eq('id', id);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Notes saved.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not save: $e')));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.appointment;
    final c = customer ?? const {};
    final start = DateTime.parse(a['starts_at']).toLocal();
    final services = List<Map<String, dynamic>>.from(
      a['appointment_services'] ?? [],
    )
        .map((s) => (s['services'] as Map?)?['name'])
        .whereType<String>()
        .join(', ');
    return Scaffold(
      appBar: AppBar(title: Text(c['name']?.toString() ?? 'Appointment')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat.yMMMd().add_jm().format(start),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (services.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(services),
                  ],
                  const SizedBox(height: 12),
                  if ((c['phone'] as String?)?.isNotEmpty == true)
                    _InfoRow(icon: Icons.phone_outlined, text: c['phone']),
                  if ((c['email'] as String?)?.isNotEmpty == true)
                    _InfoRow(icon: Icons.email_outlined, text: c['email']),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Private notes',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: notes,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Preferences, allergies, reminders…',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Next recommendation',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: recommendation,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'What to suggest at the next visit…',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: saving ? null : save,
              child: const Text('Save'),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey),
        const SizedBox(width: 8),
        Text(text),
      ],
    ),
  );
}
