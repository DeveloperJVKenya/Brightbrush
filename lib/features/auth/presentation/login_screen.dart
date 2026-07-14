import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/firebase/firebase_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/brand_mark.dart';

/// Fixed demo credentials for the three staff roles, seeded once via the
/// Firebase Admin API during development. Signing in with these gives a
/// real persistent Firestore `users/{uid}.role`, unlike the earlier
/// anonymous-session-only demo mode — which broke (permission-denied on
/// Manager/Admin screens) the moment a different browser/profile/port
/// created a fresh anonymous session that nobody had bootstrapped a role
/// for. These are pilot-only placeholders; replace with real staff
/// accounts before this goes further than an internal demo.
const _demoStaffAccounts = [
  (label: 'System Manager (demo)', email: 'demo.manager@brightbrush.app'),
  (label: 'Admin / CEO (demo)', email: 'demo.admin@brightbrush.app'),
  (label: 'Delivery Staff (demo)', email: 'demo.staff@brightbrush.app'),
];
const _demoStaffPassword = 'BrightBrush2026!';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 900;
          const form = _LoginForm();
          if (!isWide) {
            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Center(child: ConstrainedBox(constraints: BoxConstraints(maxWidth: 440), child: form)),
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

class _LoginForm extends ConsumerStatefulWidget {
  const _LoginForm();

  @override
  ConsumerState<_LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends ConsumerState<_LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _displayName = TextEditingController();
  bool _isSignUp = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _displayName.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await action();
      // No explicit navigation: the router listens to resolvedRoleProvider
      // (which watches Firebase auth state) and redirects itself the
      // moment a role resolves.
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message ?? 'Something went wrong (${e.code}).');
    } catch (error) {
      setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = ref.read(firebaseAuthProvider);
    final email = _email.text.trim();
    final password = _password.text;
    await _run(() async {
      if (_isSignUp) {
        final credential = await auth.createUserWithEmailAndPassword(email: email, password: password);
        await ref.read(userProfileRepositoryProvider).ensureCustomerProfile(
              uid: credential.user!.uid,
              email: email,
              displayName: _displayName.text.trim().isEmpty ? email : _displayName.text.trim(),
            );
      } else {
        await auth.signInWithEmailAndPassword(email: email, password: password);
      }
    });
  }

  Future<void> _continueAsGuest() async {
    await _run(() async {
      final auth = ref.read(firebaseAuthProvider);
      if (auth.currentUser == null) {
        await auth.signInAnonymously();
      }
      ref.read(guestEnteredProvider.notifier).state = true;
    });
  }

  Future<void> _continueAsDemoStaff(String email) async {
    await _run(() => ref.read(firebaseAuthProvider).signInWithEmailAndPassword(
          email: email,
          password: _demoStaffPassword,
        ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _isSignUp ? 'Create your account' : 'Sign in',
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Access your BrightBrush Creations workspace.',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          if (_isSignUp) ...[
            TextFormField(
              controller: _displayName,
              decoration: const InputDecoration(labelText: 'Full name', prefixIcon: Icon(Icons.person_outline)),
            ),
            const SizedBox(height: 12),
          ],
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline)),
            validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock_outline)),
            validator: (v) => (v == null || v.length < 6) ? 'At least 6 characters' : null,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _loading ? null : _submit,
            child: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(_isSignUp ? 'Create account' : 'Sign in'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _loading ? null : () => setState(() => _isSignUp = !_isSignUp),
            child: Text(_isSignUp ? 'Already have an account? Sign in' : "Don't have an account? Sign up"),
          ),
          if (_error != null) ...[
            const SizedBox(height: 4),
            Text(_error!, style: TextStyle(color: theme.colorScheme.error, fontSize: 12), textAlign: TextAlign.center),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: Divider(color: theme.colorScheme.outlineVariant)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'Quick demo access',
                  style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
              Expanded(child: Divider(color: theme.colorScheme.outlineVariant)),
            ],
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _loading ? null : _continueAsGuest,
            icon: const Icon(Icons.storefront_outlined, size: 18),
            label: const Align(alignment: Alignment.centerLeft, child: Text('Continue as Guest Customer')),
          ),
          const SizedBox(height: 8),
          for (final account in _demoStaffAccounts) ...[
            OutlinedButton.icon(
              onPressed: _loading ? null : () => _continueAsDemoStaff(account.email),
              icon: const Icon(Icons.badge_outlined, size: 18),
              label: Align(alignment: Alignment.centerLeft, child: Text('Continue as ${account.label}')),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}
