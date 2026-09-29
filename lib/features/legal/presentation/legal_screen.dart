import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../payments/application/payments_providers.dart';
import '../../payments/domain/business_settings.dart';

enum LegalDocument { privacy, terms }

/// Privacy Policy and Terms of Service, reachable without an account
/// (/legal/privacy, /legal/terms) as app stores require. Business name and
/// contacts come from Settings/business so they stay current.
///
/// IMPORTANT: this is a starting template written around Kenya's Data
/// Protection Act 2019 and the Consumer Protection Act 2012 — have it
/// reviewed by a Kenyan advocate before launch.
class LegalScreen extends ConsumerWidget {
  const LegalScreen({super.key, required this.document});

  final LegalDocument document;

  static const _lastUpdated = '29 September 2026';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final s =
        ref.watch(businessSettingsProvider).valueOrNull ??
        const BusinessSettings();
    final contact = [
      if (s.supportEmail.isNotEmpty) s.supportEmail,
      if (s.supportPhone.isNotEmpty) s.supportPhone,
    ].join(' · ');
    final contactLine = contact.isEmpty
        ? 'through the Support section of the app'
        : 'at $contact or through the Support section of the app';
    final sections = document == LegalDocument.privacy
        ? _privacy(s.businessName, contactLine)
        : _terms(s.businessName, contactLine);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/customer'),
        ),
        title: Text(
          document == LegalDocument.privacy
              ? 'Privacy policy'
              : 'Terms of service',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Last updated $_lastUpdated',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  for (final (heading, body) in sections) ...[
                    Text(
                      heading,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SelectableText(body, style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 18),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<(String, String)> _privacy(String name, String contactLine) => [
    (
      'Who we are',
      '$name ("we", "us") provides custom branding and embroidery on '
          'apparel and merchandise. We are the data controller for personal '
          'data collected through this app, under Kenya\'s Data Protection Act, 2019.',
    ),
    (
      'What we collect',
      '• Account details: name, email address, phone number, profile photo.\n'
          '• Order details: delivery address, items, artwork notes and order history.\n'
          '• Payment details: amount, method, and the reference from the payment provider '
          '(e.g. M-Pesa receipt number). Card and wallet details are entered on the '
          'provider\'s own secure page (Stripe, PayPal, Flutterwave) and never reach us.\n'
          '• Delivery staff: vehicle details and delivery locations while on duty.\n'
          '• Technical data needed to run and secure the app.',
    ),
    (
      'Why we use it',
      'To take, produce, deliver and support your orders; to process payments '
          'and issue receipts and tax invoices; to send you order updates; to '
          'prevent fraud; and to meet our legal and tax obligations. We do not '
          'sell your personal data.',
    ),
    (
      'Who we share it with',
      'Only with service providers who help us run the business: Google Firebase '
          '(hosting and database), payment providers you choose (Safaricom M-Pesa, '
          'Stripe, PayPal, Flutterwave), mapping services for delivery, and the Kenya '
          'Revenue Authority where tax law requires. Some providers process data outside '
          'Kenya under appropriate safeguards.',
    ),
    (
      'How long we keep it',
      'Account data is kept while your account is active. Order and payment '
          'records are kept for as long as Kenyan tax law requires (generally '
          'five years), in anonymised form if you delete your account.',
    ),
    (
      'Your rights',
      'You may access, correct or delete your personal data, object to its '
          'processing, and request a copy of it. You can delete your account at '
          'any time from Profile → Delete my account. You may also complain to '
          'the Office of the Data Protection Commissioner (odpc.go.ke).',
    ),
    ('Contact', 'Questions about your data? Contact us $contactLine.'),
  ];

  List<(String, String)> _terms(String name, String contactLine) => [
    (
      'About these terms',
      'These terms apply when you browse or order from $name through this app. '
          'By creating an account or placing an order you agree to them.',
    ),
    (
      'Orders and pricing',
      'Prices are shown in Kenyan Shillings. An order is confirmed once we '
          'review it. Some items have a minimum order quantity. Quoted prices '
          'are valid until the date shown on the quote.',
    ),
    (
      'Custom work and artwork',
      'You confirm you own or are licensed to use any logo, text or artwork '
          'you ask us to reproduce, and you are responsible for spelling and '
          'content you approve. Because branded items are made to order, they '
          'can\'t be resold, so we can\'t accept returns for change of mind. '
          'Items that are defective or don\'t match what you approved will be '
          'remade or refunded.',
    ),
    (
      'Payment and deposits',
      'Where you choose to pay a deposit, production starts once the deposit '
          'is received and the balance is due before delivery. Payments are '
          'processed by the provider you choose; their terms also apply.',
    ),
    (
      'Cancellations',
      'You can cancel an order in the app while it is still awaiting review '
          'and nothing has been paid. Once production has started, cancellation '
          'may not be possible, and costs already incurred may be deducted from '
          'any refund.',
    ),
    (
      'Delivery',
      'Delivery times are estimates. Please make sure someone is available at '
          'the delivery address. Risk in the goods passes to you on delivery.',
    ),
    (
      'Liability',
      'Nothing in these terms limits your rights under the Consumer '
          'Protection Act, 2012. Otherwise, our liability for any order is '
          'limited to the amount you paid for it.',
    ),
    (
      'Governing law',
      'These terms are governed by the laws of Kenya. Contact us $contactLine '
          'with any complaint and we will try to resolve it quickly.',
    ),
  ];
}
