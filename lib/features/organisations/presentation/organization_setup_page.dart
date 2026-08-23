import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    try {
      if (name.text.trim().length < 2) {
        throw Exception('Business name is required.');
      }
      if (!RegExp(
        r'^[a-z0-9-]{3,40}$',
      ).hasMatch(slug.text.trim().toLowerCase())) {
        throw Exception(
          'Slug must use 3-40 lowercase letters, numbers or hyphens.',
        );
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
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Set up your business'),
        actions: [
          TextButton(
            onPressed: () => Supabase.instance.client.auth.signOut(),
            child: const Text('Sign out'),
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
                  const Text(
                    'Create your business',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(
                      labelText: 'Business name',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: slug,
                    decoration: const InputDecoration(labelText: 'Slug'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: timezone,
                    decoration: const InputDecoration(labelText: 'Timezone'),
                  ),
                  if (error != null)
                    Text(error!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: loading ? null : create,
                      child: const Text('Create business'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: loading ? null : seedDemo,
                      child: const Text('Create demo business + test data'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Waiting to be added to an existing team instead? Ask '
                    'the owner to assign you a role, then sign out above '
                    'and sign back in.',
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
