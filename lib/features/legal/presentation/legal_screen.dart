import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n_ext.dart';
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
  static const _lastUpdatedSw = '29 Septemba 2026';

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
    final sw = Localizations.localeOf(context).languageCode == 'sw';
    final contactLine = sw
        ? (contact.isEmpty
              ? 'kupitia sehemu ya Msaada ndani ya programu'
              : 'kupitia $contact au sehemu ya Msaada ndani ya programu')
        : (contact.isEmpty
              ? 'through the Support section of the app'
              : 'at $contact or through the Support section of the app');
    final sections = switch ((document, sw)) {
      (LegalDocument.privacy, false) => _privacy(s.businessName, contactLine),
      (LegalDocument.terms, false) => _terms(s.businessName, contactLine),
      (LegalDocument.privacy, true) => _privacySw(s.businessName, contactLine),
      (LegalDocument.terms, true) => _termsSw(s.businessName, contactLine),
    };

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: context.l10n.back,
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/customer'),
        ),
        title: Text(
          document == LegalDocument.privacy
              ? context.l10n.privacyPolicy
              : context.l10n.termsOfService,
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
                    sw
                        ? 'Imesasishwa mwisho: $_lastUpdatedSw'
                        : 'Last updated $_lastUpdated',
                    style: theme.textTheme.bodySmall,
                  ),
                  if (sw) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Hii ni tafsiri ya Kiswahili. Iwapo kuna tofauti kati '
                      'yake na toleo la Kiingereza, toleo la Kiingereza ndilo '
                      'litakalotumika.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
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
  List<(String, String)> _privacySw(String name, String contactLine) => [
    (
      'Sisi ni nani',
      '$name ("sisi") hutoa huduma ya kuweka nembo na kushona nembo kwenye '
          'mavazi na bidhaa. Sisi ndio wadhibiti wa data binafsi inayokusanywa '
          'kupitia programu hii, chini ya Sheria ya Ulinzi wa Data ya Kenya, 2019.',
    ),
    (
      'Tunachokusanya',
      '• Maelezo ya akaunti: jina, barua pepe, namba ya simu, picha ya wasifu.\n'
          '• Maelezo ya oda: anwani ya kufikisha, bidhaa, maelezo ya nembo na historia ya oda.\n'
          '• Maelezo ya malipo: kiasi, njia, na kumbukumbu kutoka kwa mtoa huduma wa malipo '
          '(mf. namba ya risiti ya M-Pesa). Maelezo ya kadi na pochi huwekwa kwenye ukurasa '
          'salama wa mtoa huduma mwenyewe (Stripe, PayPal, Flutterwave) na hayatufikii.\n'
          '• Wafanyakazi wa ufikishaji: maelezo ya gari na maeneo ya ufikishaji wakiwa kazini.\n'
          '• Data ya kiufundi inayohitajika kuendesha na kulinda programu.',
    ),
    (
      'Kwa nini tunaitumia',
      'Ili kupokea, kuzalisha, kufikisha na kuhudumia oda zako; kushughulikia malipo '
          'na kutoa risiti na ankara za kodi; kukutumia taarifa za oda; kuzuia '
          'udanganyifu; na kutimiza wajibu wetu wa kisheria na wa kodi. Hatuuzi '
          'data yako binafsi.',
    ),
    (
      'Tunaishiriki na nani',
      'Ni kwa watoa huduma wanaotusaidia kuendesha biashara pekee: Google Firebase '
          '(uhifadhi na hifadhidata), watoa huduma wa malipo unaowachagua (Safaricom M-Pesa, '
          'Stripe, PayPal, Flutterwave), huduma za ramani kwa ufikishaji, na Mamlaka ya '
          'Mapato ya Kenya (KRA) pale sheria ya kodi inapohitaji. Baadhi ya watoa huduma '
          'hushughulikia data nje ya Kenya kwa kinga zinazofaa.',
    ),
    (
      'Tunaihifadhi kwa muda gani',
      'Data ya akaunti huhifadhiwa wakati akaunti yako inatumika. Kumbukumbu za oda '
          'na malipo huhifadhiwa kwa muda unaohitajika na sheria ya kodi ya Kenya '
          '(kwa kawaida miaka mitano), bila jina lako ukifuta akaunti yako.',
    ),
    (
      'Haki zako',
      'Unaweza kuona, kurekebisha au kufuta data yako binafsi, kupinga '
          'matumizi yake, na kuomba nakala yake. Unaweza kufuta akaunti yako '
          'wakati wowote kupitia Wasifu → Futa akaunti yangu. Unaweza pia kulalamika '
          'kwa Ofisi ya Kamishna wa Ulinzi wa Data (odpc.go.ke).',
    ),
    (
      'Mawasiliano',
      'Una maswali kuhusu data yako? Wasiliana nasi $contactLine.',
    ),
  ];

  List<(String, String)> _termsSw(String name, String contactLine) => [
    (
      'Kuhusu masharti haya',
      'Masharti haya yanatumika unapotazama au kuagiza kutoka $name kupitia programu hii. '
          'Kwa kufungua akaunti au kuweka oda unakubali masharti haya.',
    ),
    (
      'Oda na bei',
      'Bei zinaonyeshwa kwa Shilingi za Kenya. Oda huthibitishwa baada ya '
          'kuikagua. Baadhi ya bidhaa zina kiwango cha chini cha oda. Bei '
          'zilizotolewa ni halali hadi tarehe iliyoonyeshwa kwenye bei hiyo.',
    ),
    (
      'Kazi maalum na nembo',
      'Unathibitisha kuwa unamiliki au una ruhusa ya kutumia nembo, maandishi au '
          'muundo wowote unaotuomba tuutengeneze, na unawajibika kwa tahajia na '
          'maudhui unayoidhinisha. Kwa kuwa bidhaa zenye nembo hutengenezwa kwa oda, '
          'haziwezi kuuzwa tena, kwa hiyo hatupokei bidhaa zilizorudishwa kwa sababu '
          'ya kubadili nia. Bidhaa zenye kasoro au zisizolingana na ulichoidhinisha '
          'zitatengenezwa upya au pesa kurejeshwa.',
    ),
    (
      'Malipo na amana',
      'Ukichagua kulipa amana, uzalishaji huanza amana inapopokelewa na salio '
          'hulipwa kabla ya kufikishwa. Malipo hushughulikiwa na mtoa huduma '
          'unayemchagua; masharti yake pia yanatumika.',
    ),
    (
      'Kughairi',
      'Unaweza kughairi oda ndani ya programu wakati bado inasubiri kukaguliwa '
          'na hakuna kilicholipwa. Uzalishaji ukishaanza, huenda isiwezekane '
          'kughairi, na gharama zilizokwisha tumika zinaweza kukatwa kwenye '
          'marejesho yoyote.',
    ),
    (
      'Ufikishaji',
      'Muda wa kufikisha ni makadirio. Tafadhali hakikisha kuna mtu anayepatikana '
          'kwenye anwani ya kufikisha. Hatari ya bidhaa huhamia kwako zinapofikishwa.',
    ),
    (
      'Dhima',
      'Hakuna chochote katika masharti haya kinachopunguza haki zako chini ya '
          'Sheria ya Kulinda Watumiaji, 2012. Vinginevyo, dhima yetu kwa oda yoyote '
          'ni kiasi ulicholipa kwa oda hiyo.',
    ),
    (
      'Sheria inayotumika',
      'Masharti haya yanaongozwa na sheria za Kenya. Wasiliana nasi $contactLine '
          'kwa malalamiko yoyote nasi tutajaribu kuyatatua haraka.',
    ),
  ];
}
