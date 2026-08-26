import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/localization/gen/app_localizations.dart';

/// Owner-only screen to rename the business. Same direct-Supabase-call
/// pattern as OrganizationSetupPage. The write is already permitted by
/// organizations_update (0005_rls.sql: has_org_role(id, ['owner'])) — no
/// migration needed, this just adds the missing UI for it.
class OrganizationSettingsPage extends StatefulWidget {
  final String organizationId;
  final String currentName;
  final Future<void> Function() onSaved;

  const OrganizationSettingsPage({
    super.key,
    required this.organizationId,
    required this.currentName,
    required this.onSaved,
  });

  @override
  State<OrganizationSettingsPage> createState() =>
      _OrganizationSettingsPageState();
}

class _OrganizationSettingsPageState extends State<OrganizationSettingsPage> {
  late final TextEditingController name;
  bool loading = false;
  String? error;

  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: widget.currentName);
  }

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  Future<void> save() async {
    setState(() {
      loading = true;
      error = null;
    });
    final l10n = AppLocalizations.of(context);
    try {
      final trimmed = name.text.trim();
      if (trimmed.length < 2) {
        throw Exception(l10n.orgSetupNameRequired);
      }
      await Supabase.instance.client
          .from('organizations')
          .update({'name': trimmed})
          .eq('id', widget.organizationId);
      await widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.orgSettingsTitle)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: name,
                    decoration: InputDecoration(
                      labelText: l10n.orgSetupBusinessNameLabel,
                    ),
                  ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: loading ? null : save,
                      child: Text(l10n.commonSave),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
