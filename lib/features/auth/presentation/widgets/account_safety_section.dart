import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/app_role.dart';
import '../../../../core/errors/user_facing_error.dart';
import '../../../../core/firebase/firebase_providers.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/l10n/l10n_ext.dart';

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
      if (mounted) {
        _snack(context.l10n.verificationEmailSentTo(user.email ?? ''));
      }
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
      if (mounted) _snack(context.l10n.emailVerifiedThankYou);
    } else {
      if (mounted) _snack(context.l10n.notVerifiedYetCheckYourInbox);
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
                          context.l10n.verifyYourEmailSoWeCan(user.email ?? ''),
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
                        child: Text(context.l10n.sendLink),
                      ),
                      TextButton(
                        onPressed: () => _refreshVerification(user),
                        child: Text(context.l10n.iveVerified),
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
                title: Text(context.l10n.privacyPolicy2),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/legal/privacy'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.gavel_rounded),
                title: Text(context.l10n.termsOfService),
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
                    context.l10n.deleteMyAccount,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                  subtitle: Text(
                    context.l10n.permanentlyRemovesYourProfileCartAnd,
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
      await ref
          .read(firebaseFunctionsProvider)
          .httpsCallable('deleteMyAccount')
          .call();
      appLogger.i('[auth] Account ${user.uid} deleted; signing out');
      await auth.signOut();
      if (mounted) Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      setState(
        () => _error =
            e.code == 'wrong-password' || e.code == 'invalid-credential'
            ? context.l10n.thatPasswordIsIncorrect
            : (e.message ?? context.l10n.couldntConfirmYourIdentity),
      );
    } catch (error, stack) {
      appLogger.e(
        '[auth] deleteMyAccount failed',
        error: error,
        stackTrace: stack,
      );
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
      title: Text(context.l10n.deleteYourAccount),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.l10n.thisPermanentlyDeletesYourLoginProfile),
            const SizedBox(height: 16),
            TextField(
              controller: _password,
              obscureText: true,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(labelText: context.l10n.yourPassword),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _confirm,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: context.l10n.typeDeleteToConfirm,
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
          child: Text(context.l10n.keepMyAccount),
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
              : Text(context.l10n.deleteForever),
        ),
      ],
    );
  }
}
