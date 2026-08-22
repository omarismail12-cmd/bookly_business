import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/security/org_context.dart';

class CustomersPage extends ConsumerStatefulWidget {
  const CustomersPage({super.key});

  @override
  ConsumerState<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends ConsumerState<CustomersPage> {
  List<Map<String, dynamic>> rows = [];
  bool loading = true;
  final search = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(load);
  }

  Future<void> load() async {
    final organization = await ref.read(activeOrganizationProvider.future);
    if (organization == null) return;

    var query = Supabase.instance.client
        .from('customers')
        .select()
        .eq('organization_id', organization)
        .isFilter('deleted_at', null);
    if (search.text.trim().isNotEmpty) {
      query = query.ilike('name', '%${search.text.trim()}%');
    }
    final result = await query.order('name').limit(100);
    if (mounted) {
      setState(() {
        rows = List<Map<String, dynamic>>.from(result);
        loading = false;
      });
    }
  }

  Future<void> add() async {
    final name = TextEditingController();
    final phone = TextEditingController();
    final email = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add customer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: phone,
              decoration: const InputDecoration(labelText: 'Phone'),
            ),
            TextField(
              controller: email,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
          ],
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
    final organization = await ref.read(activeOrganizationProvider.future);
    await Supabase.instance.client.from('customers').insert({
      'organization_id': organization,
      'name': name.text.trim(),
      'phone': phone.text.trim(),
      'email': email.text.trim(),
    });
    load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    floatingActionButton: FloatingActionButton(
      onPressed: add,
      child: const Icon(Icons.add),
    ),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Customers',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            SizedBox(
              width: 250,
              child: TextField(
                controller: search,
                onChanged: (_) => load(),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (loading) const LinearProgressIndicator(),
        ...rows.map(
          (row) => Card(
            child: ListTile(
              title: Text(row['name']),
              subtitle: Text(
                '${row['phone'] ?? ''} • no-shows ${row['no_show_count']}',
              ),
              trailing: Text('${(row['total_spent_minor'] as num) / 100}'),
            ),
          ),
        ),
      ],
    ),
  );
}
