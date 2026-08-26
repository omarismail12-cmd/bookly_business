import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/gen/app_localizations.dart';
import '../../../core/security/org_context.dart';
import '../../../shared/widgets/async_state.dart';
import '../../../shared/widgets/skeleton.dart';
import '../data/locations_repository.dart';
import '../domain/location.dart';

class LocationsPage extends ConsumerStatefulWidget {
  const LocationsPage({super.key});

  @override
  ConsumerState<LocationsPage> createState() => _LocationsPageState();
}

class _LocationsPageState extends ConsumerState<LocationsPage> {
  List<Location> rows = [];
  bool loading = true;
  Object? error;
  String? organizationId;
  String role = 'staff';

  @override
  void initState() {
    super.initState();
    Future.microtask(load);
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final o = await ref.read(activeOrganizationProvider.future);
      organizationId = o;
      role = await ref.read(activeRoleProvider.future) ?? 'staff';
      if (o == null) return;
      final r = await ref.read(locationsRepositoryProvider).listActive(o);
      if (mounted) setState(() => rows = r);
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  bool get canManage => role == 'owner' || role == 'manager';

  Future<void> edit({Location? existing}) async {
    final l10n = AppLocalizations.of(context);
    final name = TextEditingController(text: existing?.name);
    final address = TextEditingController(text: existing?.address);
    final timezone = TextEditingController(text: existing?.timezone ?? 'UTC');
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(existing == null ? l10n.locationsNewTitle : l10n.locationsEditTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: InputDecoration(labelText: l10n.commonName),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: address,
              decoration: InputDecoration(labelText: l10n.commonAddress),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: timezone,
              decoration: InputDecoration(labelText: l10n.orgSetupTimezoneLabel),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, name.text.trim().isNotEmpty),
            child: Text(l10n.commonSave),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final trimmedName = name.text.trim();
    final trimmedAddress = address.text.trim().isEmpty
        ? null
        : address.text.trim();
    final trimmedTimezone = timezone.text.trim().isEmpty
        ? 'UTC'
        : timezone.text.trim();
    try {
      final repo = ref.read(locationsRepositoryProvider);
      if (existing == null) {
        await repo.create(
          organizationId: organizationId!,
          name: trimmedName,
          address: trimmedAddress,
          timezone: trimmedTimezone,
        );
      } else {
        await repo.update(
          id: existing.id,
          name: trimmedName,
          address: trimmedAddress,
          timezone: trimmedTimezone,
        );
      }
      await load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).locationsSaveFailed('$e'))),
        );
      }
    }
  }

  Future<void> delete(Location row) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.locationsDeleteTitle),
        content: Text(l10n.commonConfirmDelete(row.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(locationsRepositoryProvider).softDelete(row.id);
      await load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.locationsDeleteFailed('$e'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () => edit(),
              icon: const Icon(Icons.add),
              label: Text(l10n.locationsAddLocation),
            )
          : null,
      body: loading
          ? const SkeletonList(itemHeight: 84)
          : error != null
          ? AsyncErrorView(error: error!, onRetry: load)
          : RefreshIndicator(
              onRefresh: load,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    l10n.pageTitleLocations,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  if (rows.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: EmptyState(message: l10n.locationsEmpty),
                      ),
                    ),
                  ...rows.map(
                    (row) => Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.storefront_outlined),
                        ),
                        title: Text(row.name),
                        subtitle: Text(
                          [
                            if ((row.address ?? '').isNotEmpty) row.address,
                            row.timezone,
                          ].join(' • '),
                        ),
                        trailing: canManage
                            ? PopupMenuButton<String>(
                                onSelected: (v) => v == 'edit'
                                    ? edit(existing: row)
                                    : delete(row),
                                itemBuilder: (_) => [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Text(l10n.commonEdit),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text(l10n.commonDelete),
                                  ),
                                ],
                              )
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
