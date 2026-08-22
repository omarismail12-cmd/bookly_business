import '../../core/localization/gen/app_localizations.dart';

class Validators {
  static String? email(String? value, AppLocalizations l10n) {
    final email = value?.trim() ?? '';

    if (email.isEmpty) {
      return l10n.validationEmailRequired;
    }

    final emailRegex = RegExp(
      r'^[a-zA-Z0-9.!#$%&’*+/=?^_`{|}~-]+@'
      r'[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)+$',
    );

    if (!emailRegex.hasMatch(email)) {
      return l10n.validationEmailInvalid;
    }

    return null;
  }

  static String? password(String? value, AppLocalizations l10n) {
    final password = value ?? '';

    if (password.isEmpty) {
      return l10n.validationPasswordRequired;
    }

    if (password.length < 8) {
      return l10n.validationPasswordTooShort;
    }

    return null;
  }

  static String? confirmPassword(
    String? value,
    String password,
    AppLocalizations l10n,
  ) {
    if (value == null || value.isEmpty) {
      return l10n.validationConfirmPasswordRequired;
    }

    if (value != password) {
      return l10n.validationPasswordMismatch;
    }

    return null;
  }

  static String? name(String? value, AppLocalizations l10n) {
    if (value == null || value.trim().isEmpty) {
      return l10n.validationNameRequired;
    }

    if (value.trim().length < 2) {
      return l10n.validationNameTooShort;
    }

    return null;
  }
}
