import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/gen/app_localizations.dart';
import '../../../core/security/org_context.dart';
import '../../../shared/formatters/currency.dart';
import '../data/services_repository.dart';
import '../domain/service.dart';

class ServicesPage extends ConsumerStatefulWidget {
  const ServicesPage({super.key});

  @override
  ConsumerState<ServicesPage> createState() => _ServicesPageState();
}

class _ServicesPageState extends ConsumerState<ServicesPage> {
  List<Service> rows = [];
  bool loading = true;
  String? organizationId;
  String currency = 'USD';

  @override
  void initState() {
    super.initState();
    Future.microtask(load);
  }

  Future<void> load() async {
    final o = await ref.read(activeOrganizationProvider.future);
    organizationId = o;
    if (o == null) return;
    currency = await ref.read(activeCurrencyProvider.future);

    final result = await ref
        .read(servicesRepositoryProvider)
        .listActive(o);

    if (mounted) {
      setState(() {
        rows = result;
        loading = false;
      });
    }
  }

  Future<void> add() async {
    final nameController = TextEditingController();
    final durationController = TextEditingController(text: '30');
    final bufferController = TextEditingController(text: '0');
    final priceController = TextEditingController(text: '1500');
    final depositController = TextEditingController(text: '0');
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add service'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: durationController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Duration (min)'),
              ),
              TextField(
                controller: bufferController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Buffer (min)'),
              ),
              TextField(
                controller: priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Price minor units',
                ),
              ),
              TextField(
                controller: depositController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Deposit required (minor units, 0 = none)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final durationMin = int.tryParse(durationController.text.trim());
    final bufferMin = int.tryParse(bufferController.text.trim());
    final priceMinor = int.tryParse(priceController.text.trim());
    if (durationMin == null || bufferMin == null || priceMinor == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Duration, buffer and price must be whole numbers.',
            ),
          ),
        );
      }
      return;
    }
    final o = organizationId ?? await ref.read(activeOrganizationProvider.future);
    if (o == null) return;
    await ref.read(servicesRepositoryProvider).create(
      organizationId: o,
      name: nameController.text.trim(),
      durationMin: durationMin,
      bufferMin: bufferMin,
      priceMinor: priceMinor,
      depositRequiredMinor: int.tryParse(depositController.text.trim()) ?? 0,
    );
    load();
  }

  /// Local-first, conflict-checked edit (spec slide 9) — queues through
  /// SyncService so it works offline; see
  /// ServicesRepository.updateDescription for the version-conflict check.
  Future<void> editDescription(Service row) async {
    final controller = TextEditingController(text: row.description ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Edit description • ${row.name}'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Description'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(servicesRepositoryProvider).updateDescription(
        serviceId: row.id,
        description: controller.text.trim().isEmpty
            ? null
            : controller.text.trim(),
        baseVersion: row.version,
      );
    } finally {
      await load();
    }
  }

  Future<void> delete(Service row) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete service?'),
        content: Text('Remove "${row.name}"? This cannot be undone.'),
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
      await ref.read(servicesRepositoryProvider).softDelete(row.id);
      await load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not delete service: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
    floatingActionButton: FloatingActionButton(
      onPressed: add,
      child: const Icon(Icons.add),
    ),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                l10n.pageTitleServices,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              ...rows.map(
                (row) => Card(
                  child: ListTile(
                    title: Text(row.name),
                    subtitle: Text(
                      '${row.durationMin} min • buffer ${row.bufferMin} min'
                      '${row.depositRequiredMinor > 0 ? ' • deposit ${formatMinor(row.depositRequiredMinor, currency: currency)}' : ''}'
                      '${row.description != null && row.description!.isNotEmpty ? '\n${row.description}' : ''}',
                    ),
                    isThreeLine: row.description != null && row.description!.isNotEmpty,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(formatMinor(row.priceMinor, currency: currency)),
                        IconButton(
                          tooltip: 'Edit description',
                          onPressed: () => editDescription(row),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          tooltip: 'Delete',
                          onPressed: () => delete(row),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
  );
  }
}
