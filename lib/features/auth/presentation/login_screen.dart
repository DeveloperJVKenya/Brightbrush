import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/errors/user_facing_error.dart';
import '../../../core/firebase/firebase_providers.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/brand_mark.dart';

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
    } on FirebaseAuthException catch (e, stack) {
      appLogger.e('[auth] Sign-in/sign-up failed (${e.code})', error: e, stackTrace: stack);
      setState(() => _error = e.message ?? 'Something went wrong (${e.code}).');
    } catch (error, stack) {
      appLogger.e('[auth] Sign-in/sign-up failed with an unexpected error', error: error, stackTrace: stack);
      setState(() => _error = friendlyError(error));
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
        appLogger.i('[auth] Creating account for $email');
        final credential = await auth.createUserWithEmailAndPassword(email: email, password: password);
        appLogger.i('[auth] Account created uid=${credential.user!.uid}; writing user profile');
        await ref.read(userProfileRepositoryProvider).ensureUserProfile(
              uid: credential.user!.uid,
              email: email,
              displayName: _displayName.text.trim().isEmpty ? email : _displayName.text.trim(),
            );
      } else {
        appLogger.i('[auth] Signing in $email');
        await auth.signInWithEmailAndPassword(email: email, password: password);
      }
    });
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
          if (!_isSignUp) ...[
            const SizedBox(height: 8),
            Text(
              'Signing up here always creates a plain User account. Every other '
              'role is assigned afterward by an Admin/CEO or Developer.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
