import "dart:async";
import "package:connectivity_plus/connectivity_plus.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "sync_models.dart";

final syncServiceProvider = Provider<SyncService>(
  (ref) => SyncService(Supabase.instance.client),
);

class SyncService {
  final SupabaseClient client;
  final List<SyncOperation> _queue = [];
  StreamSubscription<List<ConnectivityResult>>? _sub;
  SyncService(this.client) {
    _sub = Connectivity().onConnectivityChanged.listen((_) => drain());
  }
  int get pendingCount => _queue.where((e) => e.status == "pending").length;
  void enqueue(SyncOperation op) {
    if (!_queue.any((e) => e.operationId == op.operationId)) _queue.add(op);
  }

  Future<void> drain() async {
    for (final op in List<SyncOperation>.from(_queue)) {
      if (op.status != "pending") continue;
      try {
        if (op.operation == "update_customer") {
          await client
              .from("customers")
              .update(op.payload)
              .eq("id", op.entityId);
        }
        op.status = "synced";
      } catch (_) {
        op.retryCount++;
        if (op.retryCount >= 5) op.status = "failed";
      }
    }
  }

  void dispose() => _sub?.cancel();
}
