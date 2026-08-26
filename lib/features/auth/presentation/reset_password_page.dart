import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/router.dart' show passwordRecoveryPending;
import '../../../core/localization/gen/app_localizations.dart';
import '../../../shared/validators/validators.dart';
import '../data/auth_service.dart';

/// Landing page for a password-reset email link. Only reachable with a
/// valid Supabase "recovery" session (see AuthChangeEvent.passwordRecovery
/// in router.dart, which forces navigation here) — there's deliberately no
/// way to reach this page by clicking around the app.
class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _auth = AuthService(Supabase.instance.client);
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  bool get _hasSession => Supabase.instance.client.auth.currentSession != null;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    final l10n = AppLocalizations.of(context);
    try {
      await _auth.updatePassword(_password.text);
      passwordRecoveryPending = false;
      await _auth.signOut();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          content: Text(l10n.authResetPasswordSuccess),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.commonOk),
            ),
          ],
        ),
      );
      if (mounted) context.go('/login');
    } catch (e) {
      if (mounted) setState(() => _error = l10n.authResetPasswordFailed('$e'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _cancel() async {
    passwordRecoveryPending = false;
    await _auth.signOut();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.authResetPasswordTitle),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: !_hasSession
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 56),
                      const SizedBox(height: 16),
                      Text(
                        l10n.authResetPasswordInvalidSession,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      TextButton(
                        onPressed: _cancel,
                        child: Text(l10n.authBackToLogin),
                      ),
                    ],
                  )
                : Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _password,
                          obscureText: _obscure,
                          textInputAction: TextInputAction.next,
                          validator: (v) => Validators.password(v, l10n),
                          decoration: InputDecoration(
                            labelText: l10n.authResetPasswordNewPasswordLabel,
                            prefixIcon: const Icon(Icons.lock_outline),
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              onPressed: () => setState(() => _obscure = !_obscure),
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _confirm,
                          obscureText: _obscure,
                          textInputAction: TextInputAction.done,
                          validator: (v) =>
                              Validators.confirmPassword(v, _password.text, l10n),
                          onFieldSubmitted: (_) {
                            if (!_loading) _save();
                          },
                          decoration: InputDecoration(
                            labelText: l10n.signupConfirmPassword,
                            prefixIcon: const Icon(Icons.lock_outline),
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
                            onPressed: _loading ? null : _save,
                            child: _loading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : Text(l10n.authResetPasswordButton),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: _loading ? null : _cancel,
                          child: Text(l10n.authResetPasswordCancelSignOut),
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
