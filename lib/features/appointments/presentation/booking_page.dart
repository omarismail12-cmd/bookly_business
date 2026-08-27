import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/localization/gen/app_localizations.dart';
import '../../../core/security/org_context.dart';
import '../../../shared/formatters/currency.dart';
import '../../customers/data/customers_repository.dart';
import '../../customers/domain/customer.dart';
import '../../locations/data/locations_repository.dart';
import '../../services/data/services_repository.dart';
import '../../services/domain/service.dart';
import '../../staff/data/staff_repository.dart';
import '../data/appointments_repository.dart';

class BookingPage extends ConsumerStatefulWidget {
  final String? publicSlug;
  const BookingPage({super.key, this.publicSlug});
  @override
  ConsumerState<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends ConsumerState<BookingPage> {
  List<Service> services = [];
  List<Customer> customers = [];
  List<Map<String, dynamic>> staff = [], locations = [], slots = [];
  Map<String, List<String>> serviceStaffMap = {};
  String? serviceId, staffId, customerId, locationId;
  DateTime date = DateTime.now();
  bool loading = true, loadingSlots = false, booking = false;
  String? message;
  bool messageIsError = false;
  String? businessName;
  String? businessTimezone;
  String currency = 'USD';
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
      String? org;
      if (isPublic) {
        final row = await ref
            .read(appointmentsRepositoryProvider)
            .organizationBySlug(widget.publicSlug!);
        if (row == null) throw Exception('BUSINESS_NOT_FOUND');
        org = row['id'] as String;
        businessName = row['name'] as String?;
        businessTimezone = row['timezone'] as String?;
        currency = (row['currency'] as String?) ?? currency;
      } else {
        org = await ref.read(activeOrganizationProvider.future);
        currency = await ref.read(activeCurrencyProvider.future);
      }
      if (org == null) throw Exception('No active business found.');
      final s = await ref.read(servicesRepositoryProvider).listActive(org);
      final st = await ref
          .read(staffRepositoryProvider)
          .listIdNameActive(org);
      final ssMap = await ref
          .read(staffRepositoryProvider)
          .serviceIdsToStaffIds(org);
      final loc = await ref
          .read(locationsRepositoryProvider)
          .listIdNameActive(org);
      if (!isPublic) {
        customers = await ref
            .read(customersRepositoryProvider)
            .list(organizationId: org, paginate: false, limit: 100);
      }
      if (mounted) {
        setState(() {
          services = s;
          staff = st;
          serviceStaffMap = ssMap;
          locations = loc;
          locationId = locations.isNotEmpty
              ? locations.first['id'] as String
              : null;
          loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          message = e.toString();
          messageIsError = true;
          loading = false;
        });
      }
    }
  }

  Future<void> getSlots() async {
    if (serviceId == null || staffId == null) return;
    setState(() => loadingSlots = true);
    try {
      final r = await ref
          .read(appointmentsRepositoryProvider)
          .availableSlots(
            staffId: staffId!,
            serviceId: serviceId!,
            date: date,
            locationId: locationId,
          );
      if (mounted) setState(() => slots = r);
    } catch (e) {
      if (mounted) {
        setState(() {
          message = _friendly(e);
          messageIsError = true;
        });
      }
    } finally {
      if (mounted) setState(() => loadingSlots = false);
    }
  }

  Future<void> book(String start) async {
    if (serviceId == null || staffId == null) return;
    if (isPublic &&
        (name.text.trim().length < 2 ||
            (email.text.trim().isEmpty && phone.text.trim().isEmpty))) {
      setState(() {
        message = 'Enter your name and an email or phone number.';
        messageIsError = true;
      });
      return;
    }
    setState(() => booking = true);
    try {
      final repo = ref.read(appointmentsRepositoryProvider);
      String id;
      if (isPublic) {
        id = await repo.createPublicBooking(
          slug: widget.publicSlug!,
          customerName: name.text.trim(),
          customerEmail: email.text.trim().isEmpty ? null : email.text.trim(),
          customerPhone: phone.text.trim().isEmpty ? null : phone.text.trim(),
          serviceId: serviceId!,
          staffId: staffId!,
          startsAt: start,
          locationId: locationId,
        );
      } else {
        final o = await ref.read(activeOrganizationProvider.future);
        if (customerId == null) throw Exception('Select a customer.');
        id = await repo.createBooking(
          operationId: const Uuid().v4(),
          organizationId: o!,
          customerId: customerId!,
          staffId: staffId!,
          serviceId: serviceId!,
          startsAt: start,
          source: 'reception',
          locationId: locationId,
        );
      }
      if (mounted) {
        setState(() {
          message = AppLocalizations.of(
            context,
          ).bookingConfirmed(id.substring(0, 8));
          messageIsError = false;
        });
      }
      await getSlots();
    } catch (e) {
      if (mounted) {
        setState(() {
          message = _friendly(e);
          messageIsError = true;
        });
      }
    } finally {
      if (mounted) setState(() => booking = false);
    }
  }

  /// Staff qualified for the currently selected service (staff_services) —
  /// falls back to the full active-staff list once no service is picked
  /// yet, since there's nothing to filter against.
  List<Map<String, dynamic>> get qualifiedStaff {
    if (serviceId == null) return staff;
    final ids = serviceStaffMap[serviceId] ?? const [];
    return staff.where((s) => ids.contains(s['id'] as String)).toList();
  }

  String _friendly(Object e) {
    final s = e.toString();
    if (s.contains('SLOT_ALREADY_BOOKED') || s.contains('SLOT_NOT_AVAILABLE')) {
      return 'This slot is no longer available. Please choose another time.';
    }
    if (s.contains('BUSINESS_NOT_FOUND')) return 'Business not found.';
    if (s.contains('STAFF_CANNOT_PERFORM_SERVICE')) {
      return AppLocalizations.of(context).bookingStaffCannotPerformService;
    }
    return s.replaceFirst('Exception: ', '');
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: isPublic ? AppBar(title: Text(businessName ?? 'Bookly')) : null,
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            isPublic ? l10n.bookingTitlePublic : l10n.bookingTitleNew,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          if (isPublic)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(l10n.bookingChooseServiceStaffTime),
            ),
          if (isPublic) ...[
            const SizedBox(height: 20),
            TextField(
              controller: name,
              decoration: InputDecoration(labelText: l10n.bookingFullName),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(labelText: l10n.bookingEmail),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phone,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(labelText: l10n.bookingPhone),
            ),
          ],
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            initialValue: serviceId,
            decoration: InputDecoration(labelText: l10n.bookingService),
            items: services
                .map(
                  (x) => DropdownMenuItem<String>(
                    value: x.id,
                    child: Text(
                      '${x.name} • ${formatMinor(x.priceMinor, currency: currency)}',
                    ),
                  ),
                )
                .toList(),
            onChanged: (v) {
              setState(() {
                serviceId = v;
                if (staffId != null &&
                    !qualifiedStaff.any((s) => s['id'] == staffId)) {
                  staffId = null;
                }
              });
              getSlots();
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: staffId,
            decoration: InputDecoration(labelText: l10n.bookingStaff),
            items: qualifiedStaff
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
          if (serviceId != null && qualifiedStaff.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                l10n.bookingNoQualifiedStaff,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (!isPublic) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: customerId,
              decoration: InputDecoration(labelText: l10n.bookingCustomer),
              items: customers
                  .map(
                    (x) => DropdownMenuItem<String>(
                      value: x.id,
                      child: Text(x.name),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => customerId = v),
            ),
          ],
          if (locations.length > 1) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: locationId,
              decoration: InputDecoration(labelText: l10n.bookingLocation),
              items: locations
                  .map(
                    (x) => DropdownMenuItem<String>(
                      value: (x['id'] as String),
                      child: Text(x['name'] as String),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                setState(() => locationId = v);
                getSlots();
              },
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
                  color: messageIsError
                      ? Theme.of(context).colorScheme.error
                      : Colors.green,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
