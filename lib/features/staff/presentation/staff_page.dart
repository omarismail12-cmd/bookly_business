import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/gen/app_localizations.dart';
import '../../../core/security/org_context.dart';
import '../../../shared/widgets/skeleton.dart';
import '../data/staff_repository.dart';
import '../domain/staff_member.dart';
import 'staff_schedule_page.dart';

class StaffPage extends ConsumerStatefulWidget {
  const StaffPage({super.key});

  @override
  ConsumerState<StaffPage> createState() => _StaffPageState();
}

class _StaffPageState extends ConsumerState<StaffPage> {
  List<StaffMember> rows = [];
  bool loading = true;
  String? role;
  String? organizationId;

  @override
  void initState() {
    super.initState();
    Future.microtask(load);
  }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      final o = await ref.read(activeOrganizationProvider.future);
      organizationId = o;
      role = await ref.read(activeRoleProvider.future);
      if (o == null) return;
      final r = await ref.read(staffRepositoryProvider).listActive(o);
      if (mounted) setState(() => rows = r);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> add() async {
    final c = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add staff'),
        content: TextField(
          controller: c,
          decoration: const InputDecoration(labelText: 'Display name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, c.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    final o = organizationId ?? await ref.read(activeOrganizationProvider.future);
    if (o == null) return;
    await ref
        .read(staffRepositoryProvider)
        .create(organizationId: o, displayName: name);
    await load();
  }

  Future<void> schedule(String id, String name) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StaffSchedulePage(staffId: id, staffName: name),
      ),
    );
  }

  Future<void> assignRole() async {
    final o = await ref.read(activeOrganizationProvider.future);
    if (o == null) return;
    final email = TextEditingController();
    String r = 'staff';
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Assign business role'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: email,
                decoration: const InputDecoration(
                  labelText: 'Existing account email',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: r,
                decoration: const InputDecoration(labelText: 'Role'),
                items: const [
                  DropdownMenuItem(value: 'manager', child: Text('Manager')),
                  DropdownMenuItem(
                    value: 'receptionist',
                    child: Text('Receptionist'),
                  ),
                  DropdownMenuItem(value: 'staff', child: Text('Staff')),
                ],
                onChanged: (v) => setLocal(() => r = v ?? 'staff'),
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
                  Navigator.pop(context, email.text.trim().isNotEmpty),
              child: const Text('Assign'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(staffRepositoryProvider).assignRoleByEmail(
        organizationId: o,
        email: email.text.trim(),
        role: r,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Role assigned.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not assign role: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      floatingActionButton: role == 'owner'
          ? FloatingActionButton.extended(
              onPressed: add,
              icon: const Icon(Icons.add),
              label: Text(l10n.staffAddStaff),
            )
          : null,
      body: loading
          ? const SkeletonList(itemCount: 6)
          : RefreshIndicator(
              onRefresh: load,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.pageTitleStaff,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                      if (role == 'owner')
                        OutlinedButton.icon(
                          onPressed: assignRole,
                          icon: const Icon(Icons.admin_panel_settings),
                          label: const Text('Assign role'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ...rows.map((row) {
                    final n = row.displayName;
                    return Card(
                      child: ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.person)),
                        title: Text(n),
                        subtitle: Text(row.status),
                        trailing: IconButton(
                          tooltip: 'Schedule',
                          onPressed: role == 'owner' || role == 'manager'
                              ? () => schedule(row.id, n)
                              : null,
                          icon: const Icon(Icons.schedule),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
    );
  }
}
