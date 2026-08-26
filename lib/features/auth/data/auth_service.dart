import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase;

  AuthService(this._supabase);

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    Map<String, dynamic>? data,
  }) async {
    return await _supabase.auth.signUp(
      email: email,
      password: password,
      data: data,
    );
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  /// Sends a password-reset email. [redirectTo] must be on the Supabase
  /// project's Authentication > URL Configuration > Redirect URLs
  /// allow-list, or the request is rejected server-side. Supabase doesn't
  /// reveal whether the email actually matched an account (avoids account
  /// enumeration) — callers should show the same confirmation regardless.
  Future<void> resetPassword({
    required String email,
    required String redirectTo,
  }) => _supabase.auth.resetPasswordForEmail(email, redirectTo: redirectTo);

  /// Sets a new password for the current session — only valid right after
  /// following a password-reset email link, which establishes a
  /// short-lived "recovery" session (see AuthChangeEvent.passwordRecovery
  /// in router.dart).
  Future<void> updatePassword(String newPassword) =>
      _supabase.auth.updateUser(UserAttributes(password: newPassword));

  User? get currentUser => _supabase.auth.currentUser;
}
