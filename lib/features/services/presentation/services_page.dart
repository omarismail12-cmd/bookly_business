import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/security/org_context.dart';

class ServicesPage extends ConsumerStatefulWidget {
  const ServicesPage({super.key});

  @override
  ConsumerState<ServicesPage> createState() => _ServicesPageState();
}

class _ServicesPageState extends ConsumerState<ServicesPage> {
  List<Map<String, dynamic>> rows = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(load);
  }

  Future<void> load() async {
    final organizationId = await ref.read(activeOrganizationProvider.future);
    if (organizationId == null) return;

    final result = await Supabase.instance.client
        .from('services')
        .select()
        .eq('organization_id', organizationId)
        .isFilter('deleted_at', null)
        .order('name');

    if (mounted) {
      setState(() {
        rows = List<Map<String, dynamic>>.from(result);
        loading = false;
      });
    }
  }

  Future<void> add() async {
    final nameController = TextEditingController();
    final durationController = TextEditingController(text: '30');
    final bufferController = TextEditingController(text: '0');
    final priceController = TextEditingController(text: '1500');
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
    final organizationId = await ref.read(activeOrganizationProvider.future);
    await Supabase.instance.client.from('services').insert({
      'organization_id': organizationId,
      'name': nameController.text.trim(),
      'duration_min': int.parse(durationController.text),
      'buffer_min': int.parse(bufferController.text),
      'price_minor': int.parse(priceController.text),
    });
    load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
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
                'Services',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              ...rows.map(
                (row) => Card(
                  child: ListTile(
                    title: Text(row['name']),
                    subtitle: Text(
                      '${row['duration_min']} min • buffer ${row['buffer_min']} min',
                    ),
                    trailing: Text('${(row['price_minor'] as num) / 100}'),
                  ),
                ),
              ),
            ],
          ),
  );
}
