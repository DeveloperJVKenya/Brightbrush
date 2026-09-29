import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/app_role.dart';
import '../../../../core/errors/user_facing_error.dart';
import '../../../../core/firebase/firebase_providers.dart';
import '../../../../core/logging/app_logger.dart';

/// Profile additions for a commercial launch: email verification, links to
/// the legal pages, and self-service account deletion (required by Google
/// Play / the App Store and Kenya's Data Protection Act 2019).
class AccountSafetySection extends ConsumerStatefulWidget {
  const AccountSafetySection({super.key, required this.role});

  final AppRole role;

  @override
  ConsumerState<AccountSafetySection> createState() =>
      _AccountSafetySectionState();
}

class _AccountSafetySectionState extends ConsumerState<AccountSafetySection> {
  bool _sending = false;

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _resendVerification(User user) async {
    setState(() => _sending = true);
    try {
      await user.sendEmailVerification();
      _snack('Verification email sent to ${user.email}.');
    } catch (error, stack) {
      appLogger.e(
        '[auth] sendEmailVerification failed',
        error: error,
        stackTrace: stack,
      );
      _snack(friendlyError(error));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _refreshVerification(User user) async {
    await user.reload();
    final refreshed = ref.read(firebaseAuthProvider).currentUser;
    if (refreshed?.emailVerified ?? false) {
      // Force a new ID token so the email_verified claim is current for
      // any server checks.
      await refreshed!.getIdToken(true);
      _snack('Email verified — thank you!');
    } else {
      _snack('Not verified yet. Check your inbox (and spam folder).');
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(firebaseAuthProvider).currentUser;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (user != null && !user.emailVerified) ...[
          const SizedBox(height: 10),
          Card(
            margin: EdgeInsets.zero,
            color: theme.colorScheme.tertiaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.mark_email_unread_outlined),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Verify your email (${user.email}) so we can send receipts and order updates.',
                        ),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton(
                        onPressed: _sending
                            ? null
                            : () => _resendVerification(user),
                        child: const Text('Send link'),
                      ),
                      TextButton(
                        onPressed: () => _refreshVerification(user),
                        child: const Text('I\'ve verified'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 10),
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined),
                title: const Text('Privacy policy'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/legal/privacy'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.gavel_rounded),
                title: const Text('Terms of service'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/legal/terms'),
              ),
              if (widget.role == AppRole.user) ...[
                const Divider(height: 1),
                ListTile(
                  leading: Icon(
                    Icons.delete_forever_outlined,
                    color: theme.colorScheme.error,
                  ),
                  title: Text(
                    'Delete my account',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                  subtitle: const Text(
                    'Permanently removes your profile, cart and quotes.',
                  ),
                  onTap: () => showDialog<void>(
                    context: context,
                    builder: (context) => const _DeleteAccountDialog(),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _DeleteAccountDialog extends ConsumerStatefulWidget {
  const _DeleteAccountDialog();

  @override
  ConsumerState<_DeleteAccountDialog> createState() =>
      _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends ConsumerState<_DeleteAccountDialog> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _deleting = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    final auth = ref.read(firebaseAuthProvider);
    final user = auth.currentUser;
    if (user == null || user.email == null) return;
    setState(() {
      _deleting = true;
      _error = null;
    });
    try {
      // Re-authenticate first: proves it's really the account owner at the
      // keyboard before anything irreversible happens.
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(
          email: user.email!,
          password: _password.text,
        ),
      );
      await ref.read(firebaseFunctionsProvider).httpsCallable('deleteMyAccount').call();
      appLogger.i('[auth] Account ${user.uid} deleted; signing out');
      await auth.signOut();
      if (mounted) Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      setState(
        () => _error = e.code == 'wrong-password' || e.code == 'invalid-credential'
            ? 'That password is incorrect.'
            : (e.message ?? 'Couldn\'t confirm your identity.'),
      );
    } catch (error, stack) {
      appLogger.e('[auth] deleteMyAccount failed', error: error, stackTrace: stack);
      setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ready =
        _confirm.text.trim().toUpperCase() == 'DELETE' &&
        _password.text.isNotEmpty;
    return AlertDialog(
      icon: const Icon(Icons.warning_amber_rounded, size: 40),
      title: const Text('Delete your account?'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This permanently deletes your login, profile, cart and quote requests. '
              'Past orders are kept anonymised for our tax records. '
              'You can\'t delete your account while an order is still in progress.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _password,
              obscureText: true,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Your password'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _confirm,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Type DELETE to confirm',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Keep my account'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed: ready && !_deleting ? _delete : null,
          child: _deleting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Delete forever'),
        ),
      ],
    );
  }
}
