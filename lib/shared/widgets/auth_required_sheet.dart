import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Shown when a signed-out visitor taps an action that needs an account
/// (add to cart, place an order, contact support, ...) — browsing itself
/// never needs one. Routes to `/login`, which offers both sign-in and
/// sign-up.
Future<void> showAuthRequiredSheet(
  BuildContext context, {
  required String message,
}) {
  return showModalBottomSheet(
    context: context,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 480),
    builder: (context) {
      final theme = Theme.of(context);
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: 32,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 12),
              Text(
                'Create an account to continue',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    context.go('/login');
                  },
                  child: const Text('Sign in or create account'),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
