import "package:flutter/material.dart";

import "../../core/localization/gen/app_localizations.dart";

class AsyncErrorView extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;
  const AsyncErrorView({super.key, required this.error, required this.onRetry});
  @override
  Widget build(BuildContext c) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline, size: 48),
        const SizedBox(height: 12),
        Text(error.toString(), textAlign: TextAlign.center),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: onRetry,
          child: Text(AppLocalizations.of(c).commonRetry),
        ),
      ],
    ),
  );
}

class EmptyState extends StatelessWidget {
  final String message;
  const EmptyState({super.key, required this.message});
  @override
  Widget build(BuildContext c) => Center(child: Text(message));
}
