import '../../core/localization/gen/app_localizations.dart';

/// Localizes a raw `appointments`/`queue_entries` status enum value
/// (e.g. `'checked_in'`) for display. Covers the union of both tables'
/// status vocabularies, since a handful of values (`in_service`,
/// `completed`, `cancelled`) are shared between them and every caller
/// already treats the value as an opaque string.
String humanStatusLabel(AppLocalizations l10n, String status) => switch (status) {
  'pending' => l10n.statusPending,
  'confirmed' => l10n.statusConfirmed,
  'checked_in' => l10n.statusCheckedIn,
  'in_service' => l10n.statusInService,
  'completed' => l10n.statusCompleted,
  'cancelled' => l10n.statusCancelled,
  'no_show' => l10n.statusNoShow,
  'waiting' => l10n.statusWaiting,
  'called' => l10n.statusCalled,
  'active' => l10n.statusActive,
  'inactive' => l10n.statusInactive,
  'reversed' => l10n.statusReversed,
  'draft' => l10n.statusDraft,
  'sent' => l10n.statusSent,
  'undeliverable' => l10n.statusUndeliverable,
  'expired' => l10n.statusExpired,
  'used_up' => l10n.statusUsedUp,
  _ => status,
};

/// Localizes a raw `payments.method` enum value.
String humanPaymentMethodLabel(AppLocalizations l10n, String method) => switch (method) {
  'cash' => l10n.paymentMethodCash,
  'card' => l10n.paymentMethodCard,
  'transfer' => l10n.paymentMethodTransfer,
  'online' => l10n.paymentMethodOnline,
  'other' => l10n.paymentMethodOther,
  _ => method,
};

/// Localizes a raw `payments.type` enum value.
String humanPaymentTypeLabel(AppLocalizations l10n, String type) => switch (type) {
  'deposit' => l10n.paymentTypeDeposit,
  'payment' => l10n.paymentTypePayment,
  'refund' => l10n.paymentTypeRefund,
  'forfeit' => l10n.paymentTypeForfeit,
  'adjustment' => l10n.paymentTypeAdjustment,
  _ => type,
};
