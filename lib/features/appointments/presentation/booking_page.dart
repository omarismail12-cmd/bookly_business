import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../core/security/org_context.dart';
import '../../../shared/formatters/currency.dart';

class BookingPage extends ConsumerStatefulWidget {
  final String? publicSlug;
  const BookingPage({super.key, this.publicSlug});
  @override
  ConsumerState<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends ConsumerState<BookingPage> {
  List<Map<String, dynamic>> services = [],
      staff = [],
      customers = [],
      slots = [];
  String? serviceId, staffId, customerId, locationId;
  DateTime date = DateTime.now();
  bool loading = true, loadingSlots = false, booking = false;
  String? message;
  String? businessName;
  String? businessTimezone;
  final name = TextEditingController(),
      email = TextEditingController(),
      phone = TextEditingController();
  bool get isPublic => widget.publicSlug != null;
  @override
  void initState() {
    super.initState();
    Future.microtask(load);
  }

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    phone.dispose();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final c = Supabase.instance.client;
      String? org;
      if (isPublic) {
        final rows = await c
            .from('organizations')
            .select('id,name,timezone')
            .eq('slug', widget.publicSlug!)
            .eq('status', 'active')
            .limit(1);
        if (rows.isEmpty) throw Exception('BUSINESS_NOT_FOUND');
        org = rows.first['id'];
        businessName = rows.first['name'];
        businessTimezone = rows.first['timezone'];
      } else {
        org = await ref.read(activeOrganizationProvider.future);
      }
      if (org == null) throw Exception('No active business found.');
      final s = await c
          .from('services')
          .select()
          .eq('organization_id', org)
          .isFilter('deleted_at', null)
          .order('name');
      final st = await c
          .from('staff')
          .select()
          .eq('organization_id', org)
          .eq('status', 'active')
          .order('display_name');
      if (!isPublic) {
        final cu = await c
            .from('customers')
            .select()
            .eq('organization_id', org)
            .isFilter('deleted_at', null)
            .order('name')
            .limit(100);
        customers = List<Map<String, dynamic>>.from(cu);
      }
      if (mounted)
        setState(() {
          services = List<Map<String, dynamic>>.from(s);
          staff = List<Map<String, dynamic>>.from(st);
          loading = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          message = e.toString();
          loading = false;
        });
    }
  }

  Future<void> getSlots() async {
    if (serviceId == null || staffId == null) return;
    setState(() => loadingSlots = true);
    try {
      final r = await Supabase.instance.client.rpc(
        'get_available_slots',
        params: {
          'p_staff': staffId,
          'p_service': serviceId,
          'p_date': date.toIso8601String().substring(0, 10),
          'p_location': locationId,
        },
      );
      if (mounted) setState(() => slots = List<Map<String, dynamic>>.from(r));
    } catch (e) {
      if (mounted) setState(() => message = _friendly(e));
    } finally {
      if (mounted) setState(() => loadingSlots = false);
    }
  }

  Future<void> book(String start) async {
    if (serviceId == null || staffId == null) return;
    if (isPublic &&
        (name.text.trim().length < 2 ||
            (email.text.trim().isEmpty && phone.text.trim().isEmpty))) {
      setState(() => message = 'Enter your name and an email or phone number.');
      return;
    }
    setState(() => booking = true);
    try {
      final c = Supabase.instance.client;
      String id;
      if (isPublic) {
        id = await c.rpc(
          'create_public_booking',
          params: {
            'p_slug': widget.publicSlug,
            'p_customer_name': name.text.trim(),
            'p_customer_email': email.text.trim().isEmpty
                ? null
                : email.text.trim(),
            'p_customer_phone': phone.text.trim().isEmpty
                ? null
                : phone.text.trim(),
            'p_service': serviceId,
            'p_staff': staffId,
            'p_starts_at': start,
            'p_location': locationId,
          },
        );
      } else {
        final o = await ref.read(activeOrganizationProvider.future);
        if (customerId == null) throw Exception('Select a customer.');
        id = await c.rpc(
          'create_booking',
          params: {
            'p_operation_id': const Uuid().v4(),
            'p_organization': o,
            'p_customer': customerId,
            'p_staff': staffId,
            'p_service': serviceId,
            'p_starts_at': start,
            'p_source': 'reception',
            'p_location': locationId,
            'p_notes': null,
          },
        );
        await c.rpc(
          'queue_appointment_notifications',
          params: {'p_appointment': id},
        );
      }
      if (mounted)
        setState(
          () => message = 'Booking confirmed. Reference: ${id.substring(0, 8)}',
        );
      await getSlots();
    } catch (e) {
      if (mounted) setState(() => message = _friendly(e));
    } finally {
      if (mounted) setState(() => booking = false);
    }
  }

  String _friendly(Object e) {
    final s = e.toString();
    if (s.contains('SLOT_ALREADY_BOOKED') || s.contains('SLOT_NOT_AVAILABLE'))
      return 'This slot is no longer available. Please choose another time.';
    if (s.contains('BUSINESS_NOT_FOUND')) return 'Business not found.';
    return s.replaceFirst('Exception: ', '');
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    return Scaffold(
      appBar: isPublic ? AppBar(title: Text(businessName ?? 'Bookly')) : null,
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            isPublic ? 'Book an appointment' : 'New Booking',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          if (isPublic)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('Choose a service, staff member and available time.'),
            ),
          if (isPublic) ...[
            const SizedBox(height: 20),
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Full name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone'),
            ),
          ],
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            value: serviceId,
            decoration: const InputDecoration(labelText: 'Service'),
            items: services
                .map(
                  (x) => DropdownMenuItem<String>(
                    value: (x['id'] as String),
                    child: Text(
                      '${x['name']} • ${formatMinor((x['price_minor'] as num).toInt())}',
                    ),
                  ),
                )
                .toList(),
            onChanged: (v) {
              setState(() => serviceId = v);
              getSlots();
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: staffId,
            decoration: const InputDecoration(labelText: 'Staff'),
            items: staff
                .map(
                  (x) => DropdownMenuItem<String>(
                    value: (x['id'] as String),
                    child: Text(x['display_name'] as String),
                  ),
                )
                .toList(),
            onChanged: (v) {
              setState(() => staffId = v);
              getSlots();
            },
          ),
          if (!isPublic) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: customerId,
              decoration: const InputDecoration(labelText: 'Customer'),
              items: customers
                  .map(
                    (x) => DropdownMenuItem<String>(
                      value: (x['id'] as String),
                      child: Text(x['name'] as String),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => customerId = v),
            ),
          ],
          const SizedBox(height: 12),
          ListTile(
            title: Text(
              'Date: ${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
            ),
            trailing: const Icon(Icons.calendar_month),
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
                initialDate: date,
              );
              if (d != null) {
                setState(() => date = d);
                getSlots();
              }
            },
          ),
          if (loadingSlots) const LinearProgressIndicator(),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: slots.map((s) {
              final dt = DateTime.parse(s['starts_at']).toLocal();
              return FilledButton.tonal(
                onPressed: booking ? null : () => book(s['starts_at']),
                child: Text(
                  '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}',
                ),
              );
            }).toList(),
          ),
          if (message != null)
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Text(
                message!,
                style: TextStyle(
                  color: message!.startsWith('Booking confirmed')
                      ? Colors.green
                      : Theme.of(context).colorScheme.error,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
