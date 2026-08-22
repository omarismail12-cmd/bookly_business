import 'sqlite_sync_queue_store.dart';
import 'sync_queue_store.dart';

SyncQueueStore createSyncQueueStore() => SqliteSyncQueueStore();
