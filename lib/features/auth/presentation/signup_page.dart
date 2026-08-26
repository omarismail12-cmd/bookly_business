import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/localization/gen/app_localizations.dart';
import '../../../../shared/validators/validators.dart';
import '../data/auth_service.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _formKey = GlobalKey<FormState>();
  final _auth = AuthService(Supabase.instance.client);

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _loading = true;
    });

    final l10n = AppLocalizations.of(context);
    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      final response = await _auth.signUp(
        email: email,
        password: password,
        data: {'full_name': _nameController.text.trim()},
      );

      if (!mounted) return;

      final user = response.user;

      if (user == null) {
        throw Exception(l10n.authNoUserReturned);
      }

      /*
       * Supabase may require email confirmation.
       *
       * If confirmation is enabled, session will be null.
       */
      if (response.session == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.authAccountCreatedConfirmEmail)),
        );

        showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(l10n.authCheckEmailTitle),
            content: Text(l10n.authCheckEmailBody(email)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.commonOk),
              ),
            ],
          ),
        ).then((_) {
          if (mounted) Navigator.pop(context);
        });
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.authAccountCreatedSuccess)),
      );

      Navigator.pop(context);
    } on AuthException catch (e) {
      if (!mounted) return;

      String message = e.message;

      if (e.message.toLowerCase().contains('already registered') ||
          e.message.toLowerCase().contains('already exists')) {
        message = l10n.authEmailAlreadyRegistered;
      } else if (e.message.toLowerCase().contains('invalid email')) {
        message = l10n.authEmailInvalidGeneric;
      } else if (e.message.toLowerCase().contains('password')) {
        message = l10n.authPasswordRequirementsNotMet;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.authSignupFailed('$e')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
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
            constraints: const BoxConstraints(maxWidth: 450),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.business_center, size: 64),

                  const SizedBox(height: 24),

                  Text(
                    l10n.signupWelcomeTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    l10n.signupTagline,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),

                  const SizedBox(height: 32),

                  TextFormField(
                    controller: _nameController,
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
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    validator: (v) => Validators.email(v, l10n),
                    decoration: InputDecoration(
                      labelText: l10n.loginEmail,
                      hintText: 'you@example.com',
                      prefixIcon: const Icon(Icons.email_outlined),
                      border: const OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.next,
                    validator: (v) => Validators.password(v, l10n),
                    decoration: InputDecoration(
                      labelText: l10n.loginPassword,
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    textInputAction: TextInputAction.done,
                    validator: (value) {
                      return Validators.confirmPassword(
                        value,
                        _passwordController.text,
                        l10n,
                      );
                    },
                    onFieldSubmitted: (_) {
                      if (!_loading) {
                        _signUp();
                      }
                    },
                    decoration: InputDecoration(
                      labelText: l10n.signupConfirmPassword,
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            _obscureConfirmPassword = !_obscureConfirmPassword;
                          });
                        },
                        icon: Icon(
                          _obscureConfirmPassword
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

                  const SizedBox(height: 16),

                  TextButton(
                    onPressed: _loading
                        ? null
                        : () {
                            Navigator.pop(context);
                          },
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
