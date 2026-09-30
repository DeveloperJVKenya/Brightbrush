import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/user_facing_error.dart';
import '../application/notifications_providers.dart';

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
      _snack('Notification channels saved');
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
      _snack('Test sent — check your inbox, email and WhatsApp.');
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
                'Couldn\'t load notification settings: ${friendlyError(async.error!)}',
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Notifications',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'In-app and push notifications work out of the box. Add email and WhatsApp below; customers choose their channels in their inbox.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const Divider(height: 24),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Email'),
                    value: _emailOn,
                    onChanged: (v) => setState(() => _emailOn = v),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: _provider,
                    decoration: const InputDecoration(
                      labelText: 'Email provider',
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
                    decoration: const InputDecoration(
                      labelText: 'From address',
                      hintText: 'BrightBrush <orders@yourdomain.co.ke>',
                      helperText:
                          'Must be a sender/domain verified with the provider.',
                    ),
                  ),
                  TextField(
                    controller: _emailKey,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'API key',
                      helperText:
                          (d['emailApiKeyPreview'] as String? ?? '').isEmpty
                          ? null
                          : 'Saved (${d['emailApiKeyPreview']}). Leave blank to keep it.',
                    ),
                  ),
                  const Divider(height: 32),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('WhatsApp (Meta Cloud API)'),
                    subtitle: const Text(
                      'Needs an approved message template with two parameters: {{1}} title, {{2}} message.',
                    ),
                    value: _waOn,
                    onChanged: (v) => setState(() => _waOn = v),
                  ),
                  TextField(
                    controller: _waPhoneId,
                    decoration: const InputDecoration(
                      labelText: 'Phone number ID',
                      helperText: 'Meta for Developers → WhatsApp → API Setup',
                    ),
                  ),
                  TextField(
                    controller: _waToken,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Permanent access token',
                      helperText:
                          (d['whatsappTokenPreview'] as String? ?? '').isEmpty
                          ? 'Create a System User token with whatsapp_business_messaging.'
                          : 'Saved (${d['whatsappTokenPreview']}). Leave blank to keep it.',
                    ),
                  ),
                  TextField(
                    controller: _waTemplate,
                    decoration: const InputDecoration(
                      labelText: 'Template name',
                      hintText: 'order_update',
                    ),
                  ),
                  TextField(
                    controller: _waLang,
                    decoration: const InputDecoration(
                      labelText: 'Template language code',
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
                        label: const Text('Save'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _busy ? null : _test,
                        icon: const Icon(Icons.send_rounded),
                        label: const Text('Send me a test'),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}
