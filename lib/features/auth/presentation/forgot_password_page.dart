import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/localization/gen/app_localizations.dart';
import '../../../shared/validators/validators.dart';
import '../data/auth_service.dart';

/// Shared by both the business LoginPage and CustomerLoginPage — forgetting
/// a password isn't role-specific (same Supabase Auth backend either way;
/// see CustomerLoginPage's class doc), so one page covers both.
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _auth = AuthService(Supabase.instance.client);
  final _email = TextEditingController();
  bool _loading = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _auth.resetPassword(
        email: _email.text.trim(),
        redirectTo: '${Uri.base.origin}/reset-password',
      );
      if (mounted) setState(() => _sent = true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = AppLocalizations.of(context).authForgotPasswordFailed('$e');
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.authForgotPasswordTitle)),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: _sent
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.mark_email_read_outlined, size: 56),
                      const SizedBox(height: 16),
                      Text(
                        l10n.authForgotPasswordSent,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(l10n.authBackToLogin),
                      ),
                    ],
                  )
                : Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          l10n.authForgotPasswordInstructions,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.done,
                          validator: (v) => Validators.email(v, l10n),
                          onFieldSubmitted: (_) {
                            if (!_loading) _send();
                          },
                          decoration: InputDecoration(
                            labelText: l10n.loginEmail,
                            prefixIcon: const Icon(Icons.email_outlined),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _send,
                            child: _loading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : Text(l10n.authForgotPasswordSendButton),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(l10n.authBackToLogin),
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
