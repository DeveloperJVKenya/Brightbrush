import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/app_role.dart';
import '../../../core/auth/auth_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/brand_mark.dart';

/// Login UI is laid out for real Firebase Authentication (email/password,
/// plus room for Google sign-in) but that wiring comes later. For now the
/// "Demo access" section lets every role be reached and clicked through.
class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void enterAs(AppRole role) {
      ref.read(currentRoleProvider.notifier).state = role;
      context.go(role.homePath);
    }

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 900;
          final form = _LoginForm(onEnterAs: enterAs);
          if (!isWide) {
            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 440), child: form)),
              ),
            );
          }
          return Row(
            children: [
              const Expanded(flex: 5, child: _BrandPanel()),
              Expanded(
                flex: 6,
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(48),
                    child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: form),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Left-hand hero panel on wide layouts — where the "we're a design studio"
/// impression lives, kept off the working chrome everywhere else.
class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: BrandColors.brandGradient),
      padding: const EdgeInsets.all(56),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const BrandMark(size: 56),
          const SizedBox(height: 28),
          Text(
            'BrightBrush\nCreations',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                ),
          ),
          const SizedBox(height: 16),
          Text(
            'One system for orders, production, delivery and the numbers behind '
            'every cap, hoodie and campaign package.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white.withValues(alpha: 0.85),
                ),
          ),
        ],
      ),
    );
  }
}

class _LoginForm extends StatelessWidget {
  const _LoginForm({required this.onEnterAs});

  final void Function(AppRole role) onEnterAs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Sign in',
          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          'Access your BrightBrush Creations workspace.',
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 28),
        const TextField(
          decoration: InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline)),
        ),
        const SizedBox(height: 12),
        const TextField(
          obscureText: true,
          decoration: InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock_outline)),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: null, // enabled once Firebase Auth is wired up
          child: const Text('Sign in'),
        ),
        const SizedBox(height: 6),
        Text(
          'Email/password sign-in activates once Firebase Auth is connected.',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        Row(
          children: [
            Expanded(child: Divider(color: theme.colorScheme.outlineVariant)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'Demo access',
                style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
            Expanded(child: Divider(color: theme.colorScheme.outlineVariant)),
          ],
        ),
        const SizedBox(height: 14),
        for (final role in AppRole.values) ...[
          OutlinedButton.icon(
            onPressed: () => onEnterAs(role),
            icon: const Icon(Icons.arrow_forward_rounded, size: 18),
            label: Align(
              alignment: Alignment.centerLeft,
              child: Text('Continue as ${role.label}'),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}
