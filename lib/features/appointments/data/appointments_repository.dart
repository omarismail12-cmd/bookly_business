import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_provider.dart';
import '../../../core/local/local_store.dart';
import '../../../core/local/local_store_provider.dart';

const appointmentsPageSize = 20;

/// Wraps every Supabase call for `appointments`: paginated, joined reads for
/// the calendar, the booking-flow's picker queries and slot/booking RPCs,
/// and the appointment-status RPCs (change status, cancel, reschedule).
/// Presentation code must go through this instead of calling
/// `Supabase.instance.client` directly, so RLS-respecting query shape lives
/// in one place per feature.
///
/// `appointments` is one of the tables [WorkspaceMirror] keeps warm for
/// offline reading (spec slide 9) — [listForRange] falls back to that cache
/// when the live fetch fails, same as calendar_page.dart did before this
/// refactor. The cache has no join, so a cache-fallback row has none of the
/// `customers`/`staff`/`appointment_services` nested data.
class AppointmentsRepository {
  final SupabaseClient client;
  final LocalStore localStore;
  AppointmentsRepository(this.client, this.localStore);

  Future<List<Map<String, dynamic>>> listForRange({
    required String organizationId,
    required DateTime from,
    required DateTime to,
    int page = 0,
  }) async {
    try {
      final rows = await client
          .from('appointments')
          .select(
            '*,customers(name,phone),staff(display_name),appointment_services(*,services(name))',
          )
          .eq('organization_id', organizationId)
          .gte('starts_at', from.toUtc().toIso8601String())
          .lt('starts_at', to.toUtc().toIso8601String())
          .order('starts_at')
          .range(
            page * appointmentsPageSize,
            page * appointmentsPageSize + appointmentsPageSize - 1,
          );
      return List<Map<String, dynamic>>.from(rows);
    } catch (_) {
      final cached = await localStore.list('appointments');
      final filtered =
          cached
              .where(
                (r) =>
                    r['organization_id'] == organizationId &&
                    r['deleted_at'] == null &&
                    !DateTime.parse(r['starts_at'] as String).isBefore(from) &&
                    DateTime.parse(r['starts_at'] as String).isBefore(to),
              )
              .toList()
            ..sort(
              (a, b) => (a['starts_at'] as String).compareTo(
                b['starts_at'] as String,
              ),
            );
      return filtered
          .skip(page * appointmentsPageSize)
          .take(appointmentsPageSize)
          .toList();
    }
  }

  /// Opens a Realtime channel on `appointments` for [organizationId],
  /// invoking [onChange] for any insert/update/delete. Caller owns the
  /// returned channel's lifecycle (unsubscribe/remove on dispose).
  RealtimeChannel subscribe(String organizationId, void Function() onChange) {
    return client
        .channel('calendar-$organizationId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'appointments',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'organization_id',
            value: organizationId,
          ),
          callback: (_) => onChange(),
        )
        .subscribe();
  }

  Future<void> changeStatus({
    required String appointmentId,
    required String status,
  }) => client.rpc(
    'change_appointment_status',
    params: {'p_appointment': appointmentId, 'p_status': status},
  );

  /// Cancellation goes through the dedicated cancel_appointment() RPC (not
  /// change_appointment_status) so the service's cancellation window is
  /// actually enforced server-side.
  Future<void> cancel(String appointmentId) => client.rpc(
    'cancel_appointment',
    params: {'p_appointment': appointmentId},
  );

  Future<void> reschedule({
    required String appointmentId,
    required DateTime newStart,
  }) => client.rpc(
    'reschedule_appointment',
    params: {
      'p_appointment': appointmentId,
      'p_new_start': newStart.toUtc().toIso8601String(),
    },
  );

  /// Public-storefront org lookup by slug (booking_page.dart's public
  /// mode) — anon-readable per supabase/migrations/0012 and 0035.
  Future<Map<String, dynamic>?> organizationBySlug(String slug) async {
    final rows = await client
        .from('organizations')
        .select('id,name,timezone,currency')
        .eq('slug', slug)
        .eq('status', 'active')
        .limit(1);
    return rows.isEmpty ? null : rows.first;
  }

  Future<List<Map<String, dynamic>>> availableSlots({
    required String staffId,
    required String serviceId,
    required DateTime date,
    String? locationId,
  }) async {
    final rows = await client.rpc(
      'get_available_slots',
      params: {
        'p_staff': staffId,
        'p_service': serviceId,
        'p_date': date.toIso8601String().substring(0, 10),
        'p_location': locationId,
      },
    );
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<String> createPublicBooking({
    required String slug,
    required String customerName,
    String? customerEmail,
    String? customerPhone,
    required String serviceId,
    required String staffId,
    required String startsAt,
    String? locationId,
  }) async {
    final result = await client.rpc(
      'create_public_booking',
      params: {
        'p_slug': slug,
        'p_customer_name': customerName,
        'p_customer_email': customerEmail,
        'p_customer_phone': customerPhone,
        'p_service': serviceId,
        'p_staff': staffId,
        'p_starts_at': startsAt,
        'p_location': locationId,
      },
    );
    return result as String;
  }

  Future<String> createBooking({
    required String operationId,
    required String organizationId,
    required String customerId,
    required String staffId,
    required String serviceId,
    required String startsAt,
    required String source,
    String? locationId,
    String? notes,
  }) async {
    final result = await client.rpc(
      'create_booking',
      params: {
        'p_operation_id': operationId,
        'p_organization': organizationId,
        'p_customer': customerId,
        'p_staff': staffId,
        'p_service': serviceId,
        'p_starts_at': startsAt,
        'p_source': source,
        'p_location': locationId,
        'p_notes': notes,
      },
    );
    return result as String;
  }
}

final appointmentsRepositoryProvider = Provider<AppointmentsRepository>(
  (ref) => AppointmentsRepository(
    ref.watch(supabaseProvider),
    ref.watch(localStoreProvider),
  ),
);
