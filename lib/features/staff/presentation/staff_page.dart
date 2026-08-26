import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/gen/app_localizations.dart';
import '../../../core/security/org_context.dart';
import '../../../shared/formatters/status_labels.dart';
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
    final l10n = AppLocalizations.of(context);
    final c = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.staffAddTitle),
        content: TextField(
          controller: c,
          decoration: InputDecoration(labelText: l10n.staffDisplayNameLabel),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, c.text.trim()),
            child: Text(l10n.commonSave),
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

  Future<void> linkLogin(StaffMember row) async {
    final l10n = AppLocalizations.of(context);
    final email = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.staffLinkLoginTitle(row.displayName)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (row.profileId != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(l10n.staffAlreadyLinkedWarning),
              ),
            TextField(
              controller: email,
              decoration: InputDecoration(
                labelText: l10n.staffAccountEmailLabel,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                l10n.staffLinkMoveWarning,
                style: const TextStyle(fontSize: 12),
              ),
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
                Navigator.pop(context, email.text.trim().isNotEmpty),
            child: Text(l10n.staffLinkButton),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref
          .read(staffRepositoryProvider)
          .linkToUserByEmail(staffId: row.id, email: email.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.staffLoginLinked)),
        );
      }
      await load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.staffLinkFailed('$e'))),
        );
      }
    }
  }

  Future<void> assignRole() async {
    final o = await ref.read(activeOrganizationProvider.future);
    if (o == null) return;
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    final email = TextEditingController();
    String r = 'staff';
    final ok = await showDialog<bool>(
      // ignore: use_build_context_synchronously
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(l10n.staffAssignRoleTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: email,
                decoration: InputDecoration(
                  labelText: l10n.staffExistingAccountEmailLabel,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: r,
                decoration: InputDecoration(labelText: l10n.staffRoleLabel),
                items: [
                  DropdownMenuItem(value: 'manager', child: Text(l10n.staffRoleManager)),
                  DropdownMenuItem(
                    value: 'receptionist',
                    child: Text(l10n.staffRoleReceptionist),
                  ),
                  DropdownMenuItem(value: 'staff', child: Text(l10n.staffRoleStaff)),
                ],
                onChanged: (v) => setLocal(() => r = v ?? 'staff'),
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
                  Navigator.pop(context, email.text.trim().isNotEmpty),
              child: Text(l10n.staffAssignButton),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.staffRoleAssigned)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.staffAssignRoleFailed('$e'))),
        );
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
                          label: Text(l10n.staffAssignRoleButton),
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
                        subtitle: Text(
                          row.profileId == null
                              ? l10n.staffNoLoginLinked(humanStatusLabel(l10n, row.status))
                              : humanStatusLabel(l10n, row.status),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (role == 'owner')
                              IconButton(
                                tooltip: row.profileId == null
                                    ? l10n.staffLinkLoginTooltip
                                    : l10n.staffChangeLoginTooltip,
                                onPressed: () => linkLogin(row),
                                icon: Icon(
                                  row.profileId == null
                                      ? Icons.link_off
                                      : Icons.link,
                                ),
                              ),
                            IconButton(
                              tooltip: l10n.staffScheduleTooltip,
                              onPressed: role == 'owner' || role == 'manager'
                                  ? () => schedule(row.id, n)
                                  : null,
                              icon: const Icon(Icons.schedule),
                            ),
                          ],
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
