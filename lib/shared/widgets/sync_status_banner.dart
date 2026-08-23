import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/sync/sync_models.dart';
import '../../core/sync/sync_service.dart';

/// Offline banner + pending-sync counter + manual retry + conflict resolver
/// (spec slide 9 UX requirements). Shows nothing when online with an empty
/// queue and no conflicts, so it never adds visual noise to the common
/// case. Reflects every entity SyncService's write path now covers —
/// customer create/notes, service description, staff working hours/breaks
/// — not just the original customer-only scope, since the text below is
/// generic ("N changes") rather than naming an entity.
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

  Future<void> _openConflicts(SyncService sync) async {
    final conflicts = await sync.conflicts();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Resolve conflicts'),
        content: SizedBox(
          width: double.maxFinite,
          child: conflicts.isEmpty
              ? const Text('Nothing left to resolve.')
              : ListView(
                  shrinkWrap: true,
                  children: conflicts
                      .map((op) => _ConflictTile(operation: op, sync: sync))
                      .toList(),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sync = ref.watch(syncServiceProvider);
    return ValueListenableBuilder<int>(
      valueListenable: sync.pendingCount,
      builder: (context, pending, _) {
        return ValueListenableBuilder<int>(
          valueListenable: sync.failedCount,
          builder: (context, failed, _) {
            return ValueListenableBuilder<int>(
              valueListenable: sync.conflictCount,
              builder: (context, conflicts, _) {
                if (!offline && pending == 0 && failed == 0 && conflicts == 0) {
                  return const SizedBox.shrink();
                }
                // Priority: a conflict needs a decision, a failed row
                // exhausted its automatic retries — both outrank "still
                // offline"/"still syncing" so neither is ever silently
                // invisible.
                final hasConflicts = conflicts > 0;
                final hasFailed = failed > 0;
                return Material(
                  color: hasConflicts || hasFailed
                      ? Theme.of(context).colorScheme.errorContainer
                      : offline
                      ? Theme.of(context).colorScheme.errorContainer
                      : Theme.of(context).colorScheme.secondaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          hasConflicts
                              ? Icons.merge_type
                              : hasFailed
                              ? Icons.sync_problem
                              : offline
                              ? Icons.cloud_off
                              : Icons.sync,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            hasConflicts
                                ? '$conflicts change${conflicts == 1 ? '' : 's'} need${conflicts == 1 ? 's' : ''} your review.'
                                : hasFailed
                                ? '$failed change${failed == 1 ? '' : 's'} could not be synced.'
                                : offline
                                ? (pending > 0
                                      ? 'Offline — $pending change${pending == 1 ? '' : 's'} will sync when you\'re back online.'
                                      : 'You are offline.')
                                : '$pending change${pending == 1 ? '' : 's'} syncing…',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        if (hasConflicts)
                          TextButton(
                            onPressed: () => _openConflicts(sync),
                            child: const Text('Resolve'),
                          )
                        else if (hasFailed)
                          TextButton(
                            onPressed: sync.retryFailed,
                            child: const Text('Retry'),
                          )
                        else if (!offline && pending > 0)
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
          },
        );
      },
    );
  }
}

/// One conflicted operation inside the resolve dialog: what changed locally
/// vs. what the server has now, and the "keep mine / keep theirs" choice.
class _ConflictTile extends StatefulWidget {
  final SyncOperation operation;
  final SyncService sync;
  const _ConflictTile({required this.operation, required this.sync});

  @override
  State<_ConflictTile> createState() => _ConflictTileState();
}

class _ConflictTileState extends State<_ConflictTile> {
  bool resolving = false;

  Future<void> _resolve(bool keepMine) async {
    setState(() => resolving = true);
    if (keepMine) {
      await widget.sync.resolveConflictKeepMine(widget.operation.operationId);
    } else {
      await widget.sync.resolveConflictKeepTheirs(widget.operation.operationId);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final op = widget.operation;
    final mineValue = op.payload.entries
        .where((e) => !e.key.startsWith('_'))
        .map((e) => '${e.key}: ${e.value}')
        .join(', ');
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${op.entity} — this was changed elsewhere',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Text('Your edit: $mineValue'),
            if (op.detail != null) ...[
              const SizedBox(height: 4),
              Text(
                'Current value: ${op.detail}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 12),
            if (resolving)
              const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => _resolve(false),
                    child: const Text('Keep theirs'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => _resolve(true),
                    child: const Text('Keep mine'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
