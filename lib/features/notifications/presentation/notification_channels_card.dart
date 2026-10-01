import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/user_facing_error.dart';
import '../application/notifications_providers.dart';
import '../../../core/l10n/l10n_ext.dart';

final _channelsProvider = FutureProvider.autoDispose<Map<String, dynamic>>(
  (ref) => ref.watch(notificationsRepositoryProvider).adminGetChannels(),
);

/// Admin/CEO: email and WhatsApp channels for customer and staff
/// notifications. In-app and push work without any setup (push on the web
/// needs the VAPID key in Business settings). No SMS.
class NotificationChannelsCard extends ConsumerStatefulWidget {
  const NotificationChannelsCard({super.key});

  @override
  ConsumerState<NotificationChannelsCard> createState() =>
      _NotificationChannelsCardState();
}

class _NotificationChannelsCardState
    extends ConsumerState<NotificationChannelsCard> {
  final _emailFrom = TextEditingController();
  final _emailKey = TextEditingController();
  final _waPhoneId = TextEditingController();
  final _waToken = TextEditingController();
  final _waTemplate = TextEditingController();
  final _waLang = TextEditingController();
  String _provider = 'resend';
  bool _emailOn = false;
  bool _waOn = false;
  bool _seeded = false;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [
      _emailFrom,
      _emailKey,
      _waPhoneId,
      _waToken,
      _waTemplate,
      _waLang,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _seed(Map<String, dynamic> d) {
    if (_seeded) return;
    _seeded = true;
    _provider = d['emailProvider'] as String? ?? 'resend';
    _emailOn = d['emailEnabled'] as bool? ?? false;
    _waOn = d['whatsappEnabled'] as bool? ?? false;
    _emailFrom.text = d['emailFrom'] as String? ?? '';
    _waPhoneId.text = d['whatsappPhoneNumberId'] as String? ?? '';
    _waTemplate.text = d['whatsappTemplate'] as String? ?? '';
    _waLang.text = d['whatsappLanguage'] as String? ?? 'en';
  }

  void _snack(String t) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(t), behavior: SnackBarBehavior.floating),
  );

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await ref.read(notificationsRepositoryProvider).adminSaveChannels({
        'emailEnabled': _emailOn,
        'emailProvider': _provider,
        'emailFrom': _emailFrom.text.trim(),
        if (_emailKey.text.trim().isNotEmpty)
          'emailApiKey': _emailKey.text.trim(),
        'whatsappEnabled': _waOn,
        'whatsappPhoneNumberId': _waPhoneId.text.trim(),
        if (_waToken.text.trim().isNotEmpty)
          'whatsappToken': _waToken.text.trim(),
        'whatsappTemplate': _waTemplate.text.trim(),
        'whatsappLanguage': _waLang.text.trim(),
      });
      _emailKey.clear();
      _waToken.clear();
      _seeded = false;
      ref.invalidate(_channelsProvider);
      if (mounted) _snack(context.l10n.notificationChannelsSaved);
    } catch (e) {
      _snack(friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _test() async {
    setState(() => _busy = true);
    try {
      await ref.read(notificationsRepositoryProvider).adminTest();
      if (mounted) _snack(context.l10n.testSentCheckYourInboxEmail);
    } catch (e) {
      _snack(friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final async = ref.watch(_channelsProvider);
    if (async.hasValue) _seed(async.value!);
    final d = async.valueOrNull ?? const {};
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: async.hasError
            ? Text(
                context.l10n.couldntLoadNotificationSettings(
                  friendlyError(async.error!),
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.notificationsTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    context.l10n.inAppAndPushNotificationsWork,
                    style: theme.textTheme.bodySmall,
                  ),
                  const Divider(height: 24),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(context.l10n.email),
                    value: _emailOn,
                    onChanged: (v) => setState(() => _emailOn = v),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: _provider,
                    decoration: InputDecoration(
                      labelText: context.l10n.emailProvider,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'resend',
                        child: Text('Resend (resend.com)'),
                      ),
                      DropdownMenuItem(
                        value: 'sendgrid',
                        child: Text('SendGrid'),
                      ),
                      DropdownMenuItem(
                        value: 'brevo',
                        child: Text('Brevo (Sendinblue)'),
                      ),
                    ],
                    onChanged: (v) => setState(() => _provider = v!),
                  ),
                  TextField(
                    controller: _emailFrom,
                    decoration: InputDecoration(
                      labelText: context.l10n.fromAddress,
                      hintText: 'BrightBrush <orders@yourdomain.co.ke>',
                      helperText: context.l10n.mustBeASenderDomainVerified,
                    ),
                  ),
                  TextField(
                    controller: _emailKey,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: context.l10n.apiKey,
                      helperText:
                          (d['emailApiKeyPreview'] as String? ?? '').isEmpty
                          ? null
                          : 'Saved (${d['emailApiKeyPreview']}). Leave blank to keep it.',
                    ),
                  ),
                  const Divider(height: 32),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(context.l10n.whatsappMetaCloudApi),
                    subtitle: const Text(
                      'Needs an approved message template with two parameters: {{1}} title, {{2}} message.',
                    ),
                    value: _waOn,
                    onChanged: (v) => setState(() => _waOn = v),
                  ),
                  TextField(
                    controller: _waPhoneId,
                    decoration: InputDecoration(
                      labelText: context.l10n.phoneNumberId,
                      helperText:
                          context.l10n.metaForDevelopersWhatsappApiSetup,
                    ),
                  ),
                  TextField(
                    controller: _waToken,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: context.l10n.permanentAccessToken,
                      helperText:
                          (d['whatsappTokenPreview'] as String? ?? '').isEmpty
                          ? context.l10n.createASystemUserTokenWith
                          : 'Saved (${d['whatsappTokenPreview']}). Leave blank to keep it.',
                    ),
                  ),
                  TextField(
                    controller: _waTemplate,
                    decoration: InputDecoration(
                      labelText: context.l10n.templateName,
                      hintText: 'order_update',
                    ),
                  ),
                  TextField(
                    controller: _waLang,
                    decoration: InputDecoration(
                      labelText: context.l10n.templateLanguageCode,
                      hintText: 'en',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: _busy ? null : _save,
                        icon: const Icon(Icons.save_rounded),
                        label: Text(context.l10n.save),
                      ),
                      OutlinedButton.icon(
                        onPressed: _busy ? null : _test,
                        icon: const Icon(Icons.send_rounded),
                        label: Text(context.l10n.sendMeATest),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}
