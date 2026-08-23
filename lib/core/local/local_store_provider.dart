import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'local_store.dart';
import 'local_store_factory.dart';

/// Riverpod access point for the offline read mirror (Phase 2). Sqlite3-
/// backed on native platforms, window.localStorage-backed on web — see
/// local_store_factory.dart for the platform switch.
final localStoreProvider = Provider<LocalStore>((ref) => createLocalStore());
