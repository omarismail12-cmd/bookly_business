import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/security/org_context.dart';

class StaffPage extends ConsumerStatefulWidget {
  const StaffPage({super.key});

  @override
  ConsumerState<StaffPage> createState() => _StaffPageState();
}

class _StaffPageState extends ConsumerState<StaffPage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> rows = [];
  bool loading = true;
  String? role;

  @override
  void initState() {
    super.initState();
    Future.microtask(load);
  }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      final o = await ref.read(activeOrganizationProvider.future);
      role = await ref.read(activeRoleProvider.future);
      if (o == null) return;
      final r = await supabase
          .from('staff')
          .select()
          .eq('organization_id', o)
          .isFilter('deleted_at', null)
          .order('display_name');
      if (mounted) setState(() => rows = List<Map<String, dynamic>>.from(r));
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
    final o = await ref.read(activeOrganizationProvider.future);
    await supabase.from('staff').insert({
      'organization_id': o,
      'display_name': name,
    });
    await load();
  }

  Future<void> schedule(String id, String name) async {
    int day = DateTime.now().weekday % 7;
    TimeOfDay start = const TimeOfDay(hour: 9, minute: 0),
        end = const TimeOfDay(hour: 17, minute: 0);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text('Schedule • $name'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                value: day,
                decoration: const InputDecoration(labelText: 'Day'),
                items: const [
                  DropdownMenuItem(value: 1, child: Text('Monday')),
                  DropdownMenuItem(value: 2, child: Text('Tuesday')),
                  DropdownMenuItem(value: 3, child: Text('Wednesday')),
                  DropdownMenuItem(value: 4, child: Text('Thursday')),
                  DropdownMenuItem(value: 5, child: Text('Friday')),
                  DropdownMenuItem(value: 6, child: Text('Saturday')),
                  DropdownMenuItem(value: 0, child: Text('Sunday')),
                ],
                onChanged: (v) => setLocal(() => day = v ?? 1),
              ),
              ListTile(
                title: Text('Start: ${start.format(context)}'),
                onTap: () async {
                  final x = await showTimePicker(
                    context: context,
                    initialTime: start,
                  );
                  if (x != null) setLocal(() => start = x);
                },
              ),
              ListTile(
                title: Text('End: ${end.format(context)}'),
                onTap: () async {
                  final x = await showTimePicker(
                    context: context,
                    initialTime: end,
                  );
                  if (x != null) setLocal(() => end = x);
                },
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
      ),
    );
    if (ok != true) return;
    final fmt = (TimeOfDay t) =>
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';
    await supabase.from('working_hours').upsert({
      'staff_id': id,
      'weekday': day,
      'start_time': fmt(start),
      'end_time': fmt(end),
    }, onConflict: 'staff_id,weekday');
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Schedule saved')));
    }
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
                value: r,
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
      await supabase.rpc(
        'set_member_role_by_email',
        params: {'p_org': o, 'p_email': email.text.trim(), 'p_role': r},
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
    return Scaffold(
      floatingActionButton: role == 'owner'
          ? FloatingActionButton.extended(
              onPressed: add,
              icon: const Icon(Icons.add),
              label: const Text('Staff'),
            )
          : null,
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: load,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Staff & Schedules',
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
                    final n = row['display_name'] ?? 'Unnamed';
                    return Card(
                      child: ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.person)),
                        title: Text(n),
                        subtitle: Text(row['status'] ?? 'active'),
                        trailing: IconButton(
                          tooltip: 'Schedule',
                          onPressed: role == 'owner' || role == 'manager'
                              ? () => schedule(row['id'], n)
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
