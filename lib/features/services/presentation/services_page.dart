import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/gen/app_localizations.dart';
import '../../../core/security/org_context.dart';
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

  @override
  void initState() {
    super.initState();
    Future.microtask(load);
  }

  Future<void> load() async {
    final o = await ref.read(activeOrganizationProvider.future);
    organizationId = o;
    if (o == null) return;

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
                decoration: const InputDecoration(labelText: 'Duration (min)'),
              ),
              TextField(
                controller: bufferController,
                decoration: const InputDecoration(labelText: 'Buffer (min)'),
              ),
              TextField(
                controller: priceController,
                decoration: const InputDecoration(
                  labelText: 'Price minor units',
                ),
              ),
              TextField(
                controller: depositController,
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
    final o = organizationId ?? await ref.read(activeOrganizationProvider.future);
    if (o == null) return;
    await ref.read(servicesRepositoryProvider).create(
      organizationId: o,
      name: nameController.text.trim(),
      durationMin: int.parse(durationController.text),
      bufferMin: int.parse(bufferController.text),
      priceMinor: int.parse(priceController.text),
      depositRequiredMinor: int.tryParse(depositController.text) ?? 0,
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
                      '${row.depositRequiredMinor > 0 ? ' • deposit ${row.depositRequiredMinor / 100}' : ''}'
                      '${row.description != null && row.description!.isNotEmpty ? '\n${row.description}' : ''}',
                    ),
                    isThreeLine: row.description != null && row.description!.isNotEmpty,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${row.priceMinor / 100}'),
                        IconButton(
                          tooltip: 'Edit description',
                          onPressed: () => editDescription(row),
                          icon: const Icon(Icons.edit_outlined),
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
