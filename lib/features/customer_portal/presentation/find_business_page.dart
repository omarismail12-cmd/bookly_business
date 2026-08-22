import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/localization/gen/app_localizations.dart';

/// Entry point into booking for a signed-in customer: type the business
/// code (its `organizations.slug`, e.g. from a business card / marketing
/// link) and continue to the same public booking flow used by anonymous
/// visitors. Because the customer is authenticated, create_public_booking()
/// links the resulting appointment to their profile automatically
/// (0013_customer_portal.sql), so it shows up under My Appointments.
class FindBusinessPage extends StatefulWidget {
  const FindBusinessPage({super.key});

  @override
  State<FindBusinessPage> createState() => _FindBusinessPageState();
}

class _FindBusinessPageState extends State<FindBusinessPage> {
  final _slug = TextEditingController();
  bool _checking = false;
  String? _error;

  @override
  void dispose() {
    _slug.dispose();
    super.dispose();
  }

  Future<void> _go() async {
    final slug = _slug.text.trim().toLowerCase();
    if (slug.isEmpty) return;
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      final rows = await Supabase.instance.client
          .from('organizations')
          .select('id')
          .eq('slug', slug)
          .eq('status', 'active')
          .limit(1);
      if (!mounted) return;
      if (rows.isEmpty) {
        setState(() {
          _error = AppLocalizations.of(context).findBusinessNotFound;
          _checking = false;
        });
        return;
      }
      context.push('/book/$slug');
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.storefront_outlined, size: 56),
              const SizedBox(height: 16),
              Text(
                l10n.findBusinessTitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _slug,
                textInputAction: TextInputAction.go,
                onSubmitted: (_) => _go(),
                decoration: InputDecoration(
                  labelText: l10n.findBusinessHint,
                  border: const OutlineInputBorder(),
                  errorText: _error,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: _checking ? null : _go,
                  child: _checking
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.findBusinessGo),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
