import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../features/payments/application/payments_providers.dart';
import '../features/payments/domain/business_settings.dart';

/// Normalises a Kenyan (or already international) number for wa.me:
/// 0712…/+254712…/254712… → 254712…; other international numbers pass
/// through as digits.
String? whatsappNumber(String phone) {
  final digits = phone.replaceAll(RegExp(r'[^\d]'), '');
  if (RegExp(r'^0[17]\d{8}$').hasMatch(digits)) {
    return '254${digits.substring(1)}';
  }
  if (RegExp(r'^[17]\d{8}$').hasMatch(digits)) return '254$digits';
  if (digits.length >= 10 && digits.length <= 15) return digits;
  return null;
}

/// Click-to-chat: opens WhatsApp with [message] already typed — the
/// WhatsApp app on phones, WhatsApp Desktop/Web on computers (wa.me picks
/// the right one for the device). No API or credentials needed.
Future<bool> openWhatsApp(
  BuildContext context, {
  required String phone,
  required String message,
}) async {
  final number = whatsappNumber(phone);
  if (number == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No valid WhatsApp number for this contact.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    return false;
  }
  final uri = Uri.https('wa.me', '/$number', {'text': message});
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Couldn\'t open WhatsApp on this device.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
  return ok;
}

/// The trading name from Settings → Business (for outgoing messages).
String businessNameOf(BuildContext context) =>
    ProviderScope.containerOf(
      context,
      listen: false,
    ).read(businessSettingsProvider).valueOrNull?.businessName ??
    const BusinessSettings().businessName;

/// The business line customers message (Settings → WhatsApp number, else
/// the support phone).
String? businessWhatsapp(WidgetRef ref) {
  final s = ref.watch(businessSettingsProvider).valueOrNull;
  if (s == null) return null;
  final n = s.whatsappNumber.isNotEmpty ? s.whatsappNumber : s.supportPhone;
  return whatsappNumber(n) == null ? null : n;
}

/// A "WhatsApp us" button with a pre-filled, context-specific message.
/// Hidden when the business hasn't set a WhatsApp/support number.
class WhatsAppUsButton extends ConsumerWidget {
  const WhatsAppUsButton({
    super.key,
    required this.message,
    this.label = 'WhatsApp',
    this.compact = false,
  });

  final String message;
  final String label;
  final bool compact;

  static const _green = Color(0xFF25D366);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phone = businessWhatsapp(ref);
    if (phone == null) return const SizedBox.shrink();
    if (compact) {
      return IconButton(
        tooltip: label,
        icon: const Icon(Icons.chat_rounded, color: _green),
        onPressed: () => openWhatsApp(context, phone: phone, message: message),
      );
    }
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(foregroundColor: _green),
      onPressed: () => openWhatsApp(context, phone: phone, message: message),
      icon: const Icon(Icons.chat_rounded),
      label: Text(label),
    );
  }
}
