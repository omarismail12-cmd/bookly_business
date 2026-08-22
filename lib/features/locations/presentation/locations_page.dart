import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/localization/gen/app_localizations.dart';
import '../../../core/security/org_context.dart';
import '../../../shared/widgets/async_state.dart';
import '../../../shared/widgets/skeleton.dart';

class LocationsPage extends ConsumerStatefulWidget {
  const LocationsPage({super.key});

  @override
  ConsumerState<LocationsPage> createState() => _LocationsPageState();
}

class _LocationsPageState extends ConsumerState<LocationsPage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> rows = [];
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
      final r = await supabase
          .from('locations')
          .select()
          .eq('organization_id', o)
          .isFilter('deleted_at', null)
          .order('name');
      if (mounted) setState(() => rows = List<Map<String, dynamic>>.from(r));
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  bool get canManage => role == 'owner' || role == 'manager';

  Future<void> edit({Map<String, dynamic>? existing}) async {
    final name = TextEditingController(text: existing?['name'] as String?);
    final address = TextEditingController(
      text: existing?['address'] as String?,
    );
    final timezone = TextEditingController(
      text: (existing?['timezone'] as String?) ?? 'UTC',
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(existing == null ? 'New location' : 'Edit location'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: address,
              decoration: const InputDecoration(labelText: 'Address'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: timezone,
              decoration: const InputDecoration(labelText: 'Timezone'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, name.text.trim().isNotEmpty),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final data = {
      'name': name.text.trim(),
      'address': address.text.trim().isEmpty ? null : address.text.trim(),
      'timezone': timezone.text.trim().isEmpty ? 'UTC' : timezone.text.trim(),
    };
    try {
      if (existing == null) {
        await supabase.from('locations').insert({
          'organization_id': organizationId,
          ...data,
        });
      } else {
        await supabase
            .from('locations')
            .update(data)
            .eq('id', existing['id']);
      }
      await load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not save location: $e')));
      }
    }
  }

  Future<void> delete(Map<String, dynamic> row) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete location?'),
        content: Text('Remove "${row['name']}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await supabase
          .from('locations')
          .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', row['id']);
      await load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete location: $e')),
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
                        title: Text(row['name'] ?? ''),
                        subtitle: Text(
                          [
                            if ((row['address'] as String?)?.isNotEmpty ==
                                true)
                              row['address'],
                            row['timezone'] ?? 'UTC',
                          ].join(' • '),
                        ),
                        trailing: canManage
                            ? PopupMenuButton<String>(
                                onSelected: (v) => v == 'edit'
                                    ? edit(existing: row)
                                    : delete(row),
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Text('Edit'),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Delete'),
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
