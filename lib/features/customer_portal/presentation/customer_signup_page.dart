import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/localization/gen/app_localizations.dart';
import '../../../shared/validators/validators.dart';

class CustomerSignupPage extends StatefulWidget {
  const CustomerSignupPage({super.key});

  @override
  State<CustomerSignupPage> createState() => _CustomerSignupPageState();
}

class _CustomerSignupPageState extends State<CustomerSignupPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    try {
      final response = await Supabase.instance.client.auth.signUp(
        email: _email.text.trim(),
        password: _password.text,
        data: {'full_name': _name.text.trim()},
      );
      if (!mounted) return;
      if (response.session == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account created. Check your email to confirm it.'),
          ),
        );
        Navigator.pop(context);
        return;
      }
      context.go('/customer');
    } on AuthException catch (e) {
      if (!mounted) return;
      var message = e.message;
      if (e.message.toLowerCase().contains('already registered') ||
          e.message.toLowerCase().contains('already exists')) {
        message = 'This email is already registered. Please sign in instead.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sign up failed: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.signupSubmit)),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.calendar_month, size: 56),
                  const SizedBox(height: 16),
                  Text(
                    l10n.customerPortalSignupTagline,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 28),
                  TextFormField(
                    controller: _name,
                    textInputAction: TextInputAction.next,
                    validator: (v) => Validators.name(v, l10n),
                    decoration: InputDecoration(
                      labelText: l10n.signupFullName,
                      prefixIcon: const Icon(Icons.person_outline),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    validator: (v) => Validators.email(v, l10n),
                    decoration: InputDecoration(
                      labelText: l10n.loginEmail,
                      prefixIcon: const Icon(Icons.email_outlined),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _password,
                    obscureText: _obscure,
                    textInputAction: TextInputAction.next,
                    validator: (v) => Validators.password(v, l10n),
                    decoration: InputDecoration(
                      labelText: l10n.loginPassword,
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
                    obscureText: _obscureConfirm,
                    textInputAction: TextInputAction.done,
                    validator: (v) =>
                        Validators.confirmPassword(v, _password.text, l10n),
                    onFieldSubmitted: (_) {
                      if (!_loading) _signUp();
                    },
                    decoration: InputDecoration(
                      labelText: l10n.signupConfirmPassword,
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        onPressed: () =>
                            setState(() => _obscureConfirm = !_obscureConfirm),
                        icon: Icon(
                          _obscureConfirm
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _signUp,
                      child: _loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(l10n.signupSubmit),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _loading ? null : () => Navigator.pop(context),
                    child: Text(l10n.signupHaveAccount),
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
