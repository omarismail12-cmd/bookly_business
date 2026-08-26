import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/localization/gen/app_localizations.dart';
import '../../../shared/validators/validators.dart';
import '../../auth/data/auth_service.dart';
import '../../auth/presentation/forgot_password_page.dart';
import 'customer_signup_page.dart';

/// Customer-facing login, kept deliberately separate from the business
/// LoginPage (spec slide 3: "Separate public customer booking from
/// business operations"). Same Supabase Auth backend/profiles row as the
/// business side — whether someone is staff or a customer is a matter of
/// which records reference their profile, not a different account system.
class CustomerLoginPage extends StatefulWidget {
  const CustomerLoginPage({super.key});

  @override
  State<CustomerLoginPage> createState() => _CustomerLoginPageState();
}

class _CustomerLoginPageState extends State<CustomerLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _auth = AuthService(Supabase.instance.client);
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    final l10n = AppLocalizations.of(context);
    try {
      await _auth.signIn(
        email: _email.text.trim(),
        password: _password.text,
      );
      if (mounted) context.go('/customer');
    } on AuthException catch (e) {
      if (!mounted) return;
      var message = e.message;
      if (e.message.toLowerCase().contains('invalid login') ||
          e.message.toLowerCase().contains('invalid credentials')) {
        message = l10n.authIncorrectCredentials;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.authLoginFailed('$e')), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
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
                    l10n.customerPortalWelcome,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.customerPortalTagline,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 28),
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
                    textInputAction: TextInputAction.done,
                    validator: (v) => Validators.password(v, l10n),
                    onFieldSubmitted: (_) {
                      if (!_loading) _login();
                    },
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
                  const SizedBox(height: 4),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TextButton(
                      onPressed: _loading
                          ? null
                          : () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ForgotPasswordPage(),
                              ),
                            ),
                      child: Text(l10n.authForgotPasswordLink),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _login,
                      child: _loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(l10n.loginSubmit),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _loading
                        ? null
                        : () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const CustomerSignupPage(),
                            ),
                          ),
                    child: Text(l10n.loginNoAccount),
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
