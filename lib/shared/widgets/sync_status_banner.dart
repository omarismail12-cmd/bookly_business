import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/sync/sync_service.dart';

/// Offline banner + pending-sync counter + manual retry (spec slide 9 UX
/// requirements). Shows nothing when online with an empty queue, so it
/// never adds visual noise to the common case.
class SyncStatusBanner extends ConsumerStatefulWidget {
  const SyncStatusBanner({super.key});

  @override
  ConsumerState<SyncStatusBanner> createState() => _SyncStatusBannerState();
}

class _SyncStatusBannerState extends ConsumerState<SyncStatusBanner> {
  bool offline = false;

  @override
  void initState() {
    super.initState();
    Connectivity().checkConnectivity().then(_onConnectivity);
    Connectivity().onConnectivityChanged.listen(_onConnectivity);
  }

  void _onConnectivity(List<ConnectivityResult> results) {
    if (mounted) setState(() => offline = results.contains(ConnectivityResult.none));
  }

  @override
  Widget build(BuildContext context) {
    final sync = ref.watch(syncServiceProvider);
    return ValueListenableBuilder<int>(
      valueListenable: sync.pendingCount,
      builder: (context, pending, _) {
        if (!offline && pending == 0) return const SizedBox.shrink();
        return Material(
          color: offline
              ? Theme.of(context).colorScheme.errorContainer
              : Theme.of(context).colorScheme.secondaryContainer,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(offline ? Icons.cloud_off : Icons.sync, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    offline
                        ? (pending > 0
                            ? 'Offline — $pending change${pending == 1 ? '' : 's'} will sync when you\'re back online.'
                            : 'You are offline.')
                        : '$pending change${pending == 1 ? '' : 's'} syncing…',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                if (!offline && pending > 0)
                  TextButton(
                    onPressed: sync.drain,
                    child: const Text('Retry now'),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
