import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/localization/gen/app_localizations.dart';
import '../../../../core/pdf/pdf_document_service.dart';
import '../../../../core/security/org_context.dart';
import '../../../../shared/formatters/currency.dart';
import '../../../../shared/widgets/skeleton.dart';
import '../data/payments_repository.dart';
import '../domain/payment.dart';

final _pdfService = PdfDocumentService();

class PaymentsPage extends ConsumerStatefulWidget {
  const PaymentsPage({super.key});

  @override
  ConsumerState<PaymentsPage> createState() => _PaymentsPageState();
}

class _PaymentsPageState extends ConsumerState<PaymentsPage> {
  List<Payment> rows = [];
  List<dynamic> appointments = [];
  bool loading = true;
  String businessName = 'Bookly Business';
  String currency = 'USD';
  int page = 0;
  bool hasMore = false;

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
    final membership = await ref.read(activeMembershipProvider.future);

    final repo = ref.read(paymentsRepositoryProvider);
    final payments = await repo.listPage(organizationId, page: page);
    final appointmentsList = await repo.listBookableAppointments(
      organizationId,
    );

    if (!mounted) return;

    setState(() {
      rows = payments;
      hasMore = rows.length == paymentsPageSize;
      appointments = List<dynamic>.from(appointmentsList);
      businessName = membership?.organizationName ?? businessName;
      currency = membership?.currency ?? currency;
      loading = false;
    });
  }

  Future<void> printReceipt(Payment row) async {
    final customer = row.customerName ?? 'Customer';
    final createdAt = row.createdAt.toLocal();
    await Printing.layoutPdf(
      onLayout: (_) async => Uint8List.fromList(
        await _pdfService.createReceipt(
          data: {
            'businessName': businessName,
            'reference': row.id.substring(0, 8),
            'date': DateFormat.yMMMd().add_jm().format(createdAt),
            'customerName': customer,
            'method': row.method,
            'type': row.type,
            'amount': formatMinor(row.amountMinor, currency: currency),
          },
        ),
      ),
    );
  }

  /// Active membership discount for a customer, or null if they have none.
  /// membership_discount_percent (0011/0010) is stored on the row but
  /// nothing applies it automatically — this is the one place a staff
  /// member can pull it in before recording a payment.
  Future<num?> _activeMembershipDiscount(String customerId) =>
      ref.read(paymentsRepositoryProvider).activeMembershipDiscount(customerId);

  Future<void> addPayment() async {
    String? appointment;
    String method = 'cash';
    String type = 'payment';
    final amount = TextEditingController();
    final couponCode = TextEditingController();
    num? membershipDiscountPercent;
    bool applyMembershipDiscount = false;
    bool saving = false;
    String? error;

    await showDialog<void>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocal) {
          Future<void> onAppointmentChanged(String? value) async {
            setLocal(() {
              appointment = value;
              membershipDiscountPercent = null;
              applyMembershipDiscount = false;
            });
            final customerId = appointments.firstWhere(
              (a) => a['id'] == value,
            )['customer_id'] as String?;
            if (customerId == null) return;
            final discount = await _activeMembershipDiscount(customerId);
            if (context.mounted) {
              setLocal(() => membershipDiscountPercent = discount);
            }
          }

          Future<void> save() async {
            final baseAmount = int.tryParse(amount.text.trim());
            if (appointment == null || baseAmount == null || baseAmount <= 0) {
              setLocal(() => error = 'Choose an appointment and a valid amount.');
              return;
            }
            setLocal(() {
              saving = true;
              error = null;
            });
            try {
              var finalAmount = baseAmount;
              final repo = ref.read(paymentsRepositoryProvider);

              if (couponCode.text.trim().isNotEmpty) {
                final customerId = appointments.firstWhere(
                  (a) => a['id'] == appointment,
                )['customer_id'] as String?;
                final org = await ref.read(activeOrganizationProvider.future);
                final data = await repo.redeemCoupon(
                  organizationId: org!,
                  code: couponCode.text.trim(),
                  customerId: customerId,
                  appointmentId: appointment!,
                );
                final pct = data['discount_percent'] as num?;
                final minor = data['discount_minor'] as num?;
                if (pct != null) {
                  finalAmount -= (finalAmount * pct / 100).round();
                } else if (minor != null) {
                  finalAmount -= minor.toInt();
                }
              }

              if (applyMembershipDiscount && membershipDiscountPercent != null) {
                finalAmount -=
                    (finalAmount * membershipDiscountPercent! / 100).round();
              }

              finalAmount = finalAmount < 0 ? 0 : finalAmount;
              if (finalAmount <= 0) {
                throw Exception('Discounted amount must be greater than zero.');
              }

              await repo.recordPayment(
                idempotencyKey: const Uuid().v4(),
                appointmentId: appointment!,
                amountMinor: finalAmount,
                method: method,
                type: type,
              );
              if (context.mounted) Navigator.pop(context);
            } catch (e) {
              setLocal(() {
                saving = false;
                error = '$e';
              });
            }
          }

          return AlertDialog(
            title: const Text('Record payment'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: appointment,
                    decoration: const InputDecoration(
                      labelText: 'Appointment',
                    ),
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
                    onChanged: onAppointmentChanged,
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
                    initialValue: method,
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
                    initialValue: type,
                    decoration: const InputDecoration(labelText: 'Type'),
                    items: const [
                      DropdownMenuItem(
                        value: 'payment',
                        child: Text('Payment'),
                      ),
                      DropdownMenuItem(
                        value: 'deposit',
                        child: Text('Deposit'),
                      ),
                    ],
                    onChanged: (value) =>
                        setLocal(() => type = value ?? 'payment'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: couponCode,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Coupon code (optional)',
                    ),
                  ),
                  if (membershipDiscountPercent != null)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: applyMembershipDiscount,
                      onChanged: (v) =>
                          setLocal(() => applyMembershipDiscount = v ?? false),
                      title: Text(
                        'Apply active membership discount '
                        '($membershipDiscountPercent% off)',
                      ),
                    ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: saving ? null : save,
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );

    await load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: loading ? null : addPayment,
        icon: const Icon(Icons.add_card),
        label: Text(l10n.paymentsAddPayment),
      ),
      body: loading
          ? SkeletonList(
              itemCount: 6,
              leadingCircle: false,
              header: Text(
                l10n.pageTitlePayments,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            )
          : RefreshIndicator(
              onRefresh: load,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    l10n.pageTitlePayments,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  ...rows.map((row) {
                    final customer = row.customerName ?? 'Customer';
                    return Card(
                      child: ListTile(
                        title: Text(customer),
                        subtitle: Text(
                          '${row.method} • ${row.type} • ${row.status}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              formatMinor(
                                row.amountMinor,
                                currency: currency,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Print / share receipt',
                              onPressed: () => printReceipt(row),
                              icon: const Icon(Icons.receipt_long_outlined),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  if (page > 0 || hasMore)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton(
                            onPressed: page > 0
                                ? () {
                                    setState(() => page--);
                                    load();
                                  }
                                : null,
                            child: Text(l10n.commonPrevious),
                          ),
                          const SizedBox(width: 16),
                          Text('Page ${page + 1}'),
                          const SizedBox(width: 16),
                          TextButton(
                            onPressed: hasMore
                                ? () {
                                    setState(() => page++);
                                    load();
                                  }
                                : null,
                            child: Text(l10n.commonNext),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
