import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/localization/gen/app_localizations.dart';

class OrganizationSetupPage extends StatefulWidget {
  final Future<void> Function() onCreated;

  const OrganizationSetupPage({super.key, required this.onCreated});

  @override
  State<OrganizationSetupPage> createState() => _OrganizationSetupPageState();
}

class _OrganizationSetupPageState extends State<OrganizationSetupPage> {
  final name = TextEditingController();
  final slug = TextEditingController();
  final timezone = TextEditingController(text: 'Asia/Beirut');
  bool loading = false;
  String? error;

  @override
  void dispose() {
    name.dispose();
    slug.dispose();
    timezone.dispose();
    super.dispose();
  }

  Future<void> seedDemo() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      await Supabase.instance.client.rpc('seed_demo_data_for_current_user');
      await widget.onCreated();
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> create() async {
    setState(() {
      loading = true;
      error = null;
    });
    final l10n = AppLocalizations.of(context);
    try {
      if (name.text.trim().length < 2) {
        throw Exception(l10n.orgSetupNameRequired);
      }
      if (!RegExp(
        r'^[a-z0-9-]{3,40}$',
      ).hasMatch(slug.text.trim().toLowerCase())) {
        throw Exception(l10n.orgSetupSlugInvalid);
      }
      await Supabase.instance.client.rpc(
        'create_organization_for_current_user',
        params: {
          'p_name': name.text.trim(),
          'p_slug': slug.text.trim().toLowerCase(),
          'p_timezone': timezone.text.trim(),
        },
      );
      await widget.onCreated();
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
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(l10n.orgSetupPageTitle),
        actions: [
          TextButton(
            onPressed: () => Supabase.instance.client.auth.signOut(),
            child: Text(l10n.commonSignOut),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.orgSetupHeading,
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: name,
                    decoration: InputDecoration(
                      labelText: l10n.orgSetupBusinessNameLabel,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: slug,
                    decoration: InputDecoration(labelText: l10n.orgSetupSlugLabel),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: timezone,
                    decoration: InputDecoration(labelText: l10n.orgSetupTimezoneLabel),
                  ),
                  if (error != null)
                    Text(error!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: loading ? null : create,
                      child: Text(l10n.orgSetupCreateButton),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: loading ? null : seedDemo,
                      child: Text(l10n.orgSetupCreateDemoButton),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.orgSetupWaitingForInvite,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
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
