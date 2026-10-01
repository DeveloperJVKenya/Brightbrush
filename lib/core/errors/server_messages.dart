import '../../features/customization/domain/customization_options.dart';
import '../l10n/current_l10n.dart';
import '../l10n/enum_l10n.dart';

/// Kiswahili for the messages our Cloud Functions send to users (and the
/// matching client-side checks in customization_pricing.dart). The server
/// writes English; when the app is in Kiswahili it is translated here.
/// Anything not listed is shown in English rather than mistranslated.
String translateServerMessage(String en) {
  if (l10nNow.localeName != 'sw') return en;
  final exact = _exact[en];
  if (exact != null) return exact;
  for (final (re, build) in _patterns) {
    final m = re.firstMatch(en);
    if (m != null) return build(m);
  }
  // Several problems joined into one sentence block.
  if (en.contains('. ') && en.split('. ').length > 1) {
    final parts = en.split(RegExp(r'(?<=\.)\s+'));
    final translated = parts.map(translateServerMessage).toList();
    if (translated.any((t) => !parts.contains(t))) return translated.join(' ');
  }
  return en;
}

/// A decoration method or placement name inside a message, in Kiswahili.
String _optionSw(String en) {
  for (final m in DecorationMethod.values) {
    if (m.label == en) return m.sw;
  }
  for (final p in Placement.values) {
    if (p.label == en) return p.sw;
  }
  return en;
}

/// Field labels the server puts into "must be…" messages.
String _label(String en) => _labels[en] ?? en;

const _labels = {
  'Amount': 'Kiasi',
  'Cancellation fee': 'Ada ya kughairi',
  'Comment': 'Maoni',
  'Contact name': 'Jina la mawasiliano',
  'Contact phone': 'Simu ya mawasiliano',
  'Delivery address': 'Anwani ya kufikisha',
  'Document': 'Hati',
  'From': 'Kuanzia',
  'Note': 'Dokezo',
  'Notes': 'Maelezo',
  'Order': 'Oda',
  'Payment': 'Malipo',
  'Phone number': 'Namba ya simu',
  'Proof': 'Sampuli',
  'Purchase order': 'Agizo la ununuzi',
  'Quote': 'Bei',
  'Reason': 'Sababu',
  'Recipient name': 'Jina la mpokeaji',
  'Reference': 'Kumbukumbu',
  'Referral code': 'Msimbo wa rufaa',
  'Refund amount': 'Kiasi cha kurejesha',
  'Subtotal': 'Jumla ndogo',
  'Supplier': 'Msambazaji',
  'Supplier contact': 'Mawasiliano ya msambazaji',
  'To': 'Hadi',
};

const _exact = <String, String>{
  // Account & access
  "Staff accounts can't be self-deleted. Ask an Admin to change your role to User first.":
      'Akaunti za wafanyakazi haziwezi kujifuta. Mwombe Msimamizi abadilishe nafasi yako kuwa Mtumiaji kwanza.',
  'Please sign in to continue.': 'Tafadhali ingia ili kuendelea.',
  'This account has been suspended. Contact an administrator.':
      'Akaunti hii imesimamishwa. Wasiliana na msimamizi.',
  'Your role is not allowed to do this.':
      'Nafasi yako hairuhusiwi kufanya hivi.',
  'Malformed request.': 'Ombi si sahihi.',
  'Staff only.': 'Wafanyakazi pekee.',
  'Too many attempts. Please wait a moment and try again.':
      'Majaribio mengi mno. Tafadhali subiri kidogo kisha ujaribu tena.',
  'Choose a valid date range.': 'Chagua kipindi sahihi cha tarehe.',

  // Cart & checkout
  'A customised item in your cart is incomplete. Remove it and add it again.':
      'Bidhaa iliyobinafsishwa kwenye kikapu chako haijakamilika. Iondoe kisha uiongeze tena.',
  'A customised item in your cart is no longer available. Remove it and try again.':
      'Bidhaa iliyobinafsishwa kwenye kikapu chako haipatikani tena. Iondoe kisha ujaribu tena.',
  "Store pickup isn't available right now.":
      'Kuchukua dukani hakupatikani kwa sasa.',
  'Choose your delivery area.': 'Chagua eneo lako la kufikisha.',
  'Enter a delivery address.': 'Weka anwani ya kufikisha.',
  "Credit terms aren't enabled on your account. Choose another way to pay.":
      'Malipo ya mkopo hayajawezeshwa kwenye akaunti yako. Chagua njia nyingine ya kulipa.',
  'Your cart is empty.': 'Kikapu chako ni kitupu.',
  'An item in your cart is no longer available. Remove it and try again.':
      'Bidhaa moja kwenye kikapu chako haipatikani tena. Iondoe kisha ujaribu tena.',
  'Enter how many pieces you need.': 'Weka idadi ya vipande unavyohitaji.',
  'Choose one of the available colours.': 'Chagua mojawapo ya rangi zilizopo.',
  'At most 6 decorations per item.': 'Mapambo yasiyozidi 6 kwa kila bidhaa.',
  "That decoration method isn't offered on this item.":
      'Njia hiyo ya urembo haitolewi kwa bidhaa hii.',
  'That decoration method is currently unavailable.':
      'Njia hiyo ya urembo haipatikani kwa sasa.',
  "That placement isn't offered on this item.":
      'Mahali hapo pa kuweka nembo hapatolewi kwa bidhaa hii.',
  'Each placement can only be used once.':
      'Kila mahali pa kuweka nembo panaweza kutumika mara moja tu.',
  'Each decoration needs artwork or text.':
      'Kila pambo linahitaji nembo au maandishi.',
  'You have more names than pieces.': 'Una majina mengi kuliko vipande.',

  // Payments
  'This order was cancelled.': 'Oda hii ilighairiwa.',
  'That payment method is not available right now.':
      'Njia hiyo ya malipo haipatikani kwa sasa.',
  'This order is already fully paid.': 'Oda hii tayari imelipwa kikamilifu.',
  'Enter a valid Safaricom number, e.g. 0712 345 678.':
      'Weka namba sahihi ya Safaricom, mf. 0712 345 678.',
  'An M-Pesa prompt was just sent for this order. Complete it on your phone or wait a minute before retrying.':
      'Ombi la M-Pesa limetumwa sasa hivi kwa oda hii. Likamilishe kwenye simu yako au subiri dakika moja kabla ya kujaribu tena.',
  'Payment not found.': 'Malipo hayakupatikana.',
  'Enter the Safaricom number that should receive the M-Pesa prompt.':
      'Weka namba ya Safaricom itakayopokea ombi la M-Pesa.',
  'That is more than was paid on this order.':
      'Hicho ni zaidi ya kilicholipwa kwa oda hii.',
  'Completed orders can be refunded but not cancelled.':
      'Oda zilizokamilika zinaweza kurejeshewa pesa lakini haziwezi kughairiwa.',
  'Fill in every required field before enabling this gateway.':
      'Jaza sehemu zote zinazohitajika kabla ya kuwezesha njia hii ya malipo.',
  'Save all required credentials first.':
      'Hifadhi taarifa zote zinazohitajika kwanza.',

  // Orders, documents, delivery
  'Document not found.': 'Hati haikupatikana.',
  'Order not found.': 'Oda haikupatikana.',
  'Receipt not found.': 'Risiti haikupatikana.',
  'Credit note not found.': 'Hati ya marejesho haikupatikana.',
  'Refund not found.': 'Marejesho hayakupatikana.',
  'Pickups are handed over by store staff.':
      'Oda za kuchukua hukabidhiwa na wafanyakazi wa duka.',
  "This order isn't ready for collection yet.":
      'Oda hii bado haiko tayari kuchukuliwa.',
  'Only the assigned driver can complete this delivery.':
      'Ni dereva aliyepangiwa pekee anayeweza kukamilisha ufikishaji huu.',
  "This order isn't out for delivery.": 'Oda hii haiko njiani kufikishwa.',
  'That code is wrong. Ask the customer to check their order page.':
      'Msimbo huo si sahihi. Mwombe mteja aangalie ukurasa wa oda yake.',
  "Enter the customer's delivery code, or take a handover photo and capture a signature.":
      'Weka msimbo wa kufikisha wa mteja, au piga picha ya makabidhiano na uchukue sahihi.',
  'Tick every checklist item to pass the order.':
      'Weka alama kwenye kila kipengele cha orodha ili kupitisha oda.',
  'Say what needs fixing.': 'Eleza kinachohitaji kurekebishwa.',
  'Only orders in production can be quality-checked.':
      'Ni oda zilizo kwenye uzalishaji pekee zinazoweza kukaguliwa ubora.',

  // Proofs & quotes
  'Attach at least one proof image.':
      'Ambatisha angalau picha moja ya sampuli.',
  'Proofs can only be sent before production starts.':
      'Sampuli zinaweza kutumwa kabla uzalishaji haujaanza tu.',
  'Tell us what to change.': 'Tuambie cha kubadilisha.',
  'Proof not found.': 'Sampuli haikupatikana.',
  'This proof has already been answered or replaced by a newer one.':
      'Sampuli hii tayari imejibiwa au imebadilishwa na mpya.',
  'Quote not found.': 'Bei haikupatikana.',
  'This quote has already been accepted.': 'Bei hii tayari imekubaliwa.',
  'This quote has not been priced yet.': 'Bei hii bado haijawekwa.',
  'This quote has no price yet.': 'Bei hii bado haina kiasi.',
  'This quote has expired. Ask us for an updated price.':
      'Bei hii imepitwa na muda. Tuombe bei mpya.',

  // Referrals & loyalty
  "Couldn't create a code. Please try again.":
      'Imeshindwa kutengeneza msimbo. Tafadhali jaribu tena.',
  "That referral code doesn't exist.": 'Msimbo huo wa rufaa haupo.',
  "You can't use your own code.": 'Huwezi kutumia msimbo wako mwenyewe.',
  "You've already used a referral code.": 'Tayari umetumia msimbo wa rufaa.',
  'Referral codes are for new customers before their first order.':
      'Misimbo ya rufaa ni kwa wateja wapya kabla ya oda yao ya kwanza.',

  // Staff/admin (shown if a staff member uses Kiswahili)
  'Purchase order not found.': 'Agizo la ununuzi halikupatikana.',
  'Add at least one material with a quantity.':
      'Ongeza angalau malighafi moja yenye kiasi.',
  'Save all eTIMS fields first.': 'Hifadhi sehemu zote za eTIMS kwanza.',
  'This invoice is already being submitted to KRA.':
      'Ankara hii tayari inatumwa KRA.',
  'eTIMS is not set up. An admin must configure and initialise it first.':
      'eTIMS haijawekwa. Msimamizi lazima aiweke na kuianzisha kwanza.',
  'The original invoice was never submitted to eTIMS.':
      'Ankara ya awali haikuwahi kutumwa eTIMS.',
};

typedef _Build = String Function(RegExpMatch m);

final List<(RegExp, _Build)> _patterns = [
  (
    RegExp(
      r"^You have (\d+) order\(s\) still in progress\. Wait until they're delivered or cancel them, then try again\.$",
    ),
    (m) =>
        'Una oda ${m[1]} ambazo bado zinaendelea. Subiri zifikishwe au zighairi, kisha ujaribu tena.',
  ),
  (
    RegExp(
      r'^The code "(.+)" isn'
      "'"
      r't valid\.$',
    ),
    (m) => 'Msimbo "${m[1]}" si sahihi.',
  ),
  (
    RegExp(r'^The code "(.+)" has expired\.$'),
    (m) => 'Msimbo "${m[1]}" umepitwa na muda.',
  ),
  (
    RegExp(r'^The code "(.+)" has been fully used\.$'),
    (m) => 'Msimbo "${m[1]}" umeshatumika kikamilifu.',
  ),
  (
    RegExp(
      r'^You'
      "'"
      r've already used the code "(.+)"\.$',
    ),
    (m) => 'Tayari umetumia msimbo "${m[1]}".',
  ),
  (
    RegExp(r'^(.+) must be between (\d+) and (\d+) characters\.$'),
    (m) => '${_label(m[1]!)} lazima iwe na herufi kati ya ${m[2]} na ${m[3]}.',
  ),
  (
    RegExp(r'^(.+) must be at most (\d+) characters\.$'),
    (m) => '${_label(m[1]!)} isizidi herufi ${m[2]}.',
  ),
  (
    RegExp(r'^(.+) must be a number\.$'),
    (m) => '${_label(m[1]!)} lazima iwe namba.',
  ),
  (
    RegExp(r'^(.+) must be between (.+) and (.+)\.$'),
    (m) => '${_label(m[1]!)} lazima iwe kati ya ${m[2]} na ${m[3]}.',
  ),
  (
    RegExp(r'^Invalid value for (.+)\.$'),
    (m) => 'Thamani si sahihi kwa ${_label(m[1]!)}.',
  ),
  (
    RegExp(r'^Invalid choice for (.+)\.$'),
    (m) => 'Chaguo si sahihi kwa ${_label(m[1]!)}.',
  ),
  (
    RegExp(r'^An artwork used on "(.+)" is missing\. Choose it again\.$'),
    (m) => 'Nembo iliyotumika kwenye "${m[1]}" haipo. Ichague tena.',
  ),
  (
    RegExp(r'^An order can hold at most (\d+) different items\.$'),
    (m) => 'Oda moja inaweza kuwa na bidhaa tofauti zisizozidi ${m[1]}.',
  ),
  (
    RegExp(r'^"(.+)" exceeds the maximum quantity of (\d+)\.$'),
    (m) => '"${m[1]}" imezidi idadi ya juu ya ${m[2]}.',
  ),
  (
    RegExp(
      r'^The "(.+)" package isn'
      "'"
      r't on offer right now\.$',
    ),
    (m) => 'Kifurushi "${m[1]}" hakipatikani kwa sasa.',
  ),
  (
    RegExp(r'^"(.+)" has a minimum order of (\d+)\. You have (\d+)\.$'),
    (m) => '"${m[1]}" ina kiwango cha chini cha ${m[2]}. Una ${m[3]}.',
  ),
  (
    RegExp(r'^"(.+)" has a minimum order of (\d+)\.$'),
    (m) => '"${m[1]}" ina kiwango cha chini cha ${m[2]}.',
  ),
  (
    RegExp(r'^Spend at least KES (\S+) to use "(.+)"\.$'),
    (m) => 'Nunua angalau KES ${m[1]} ili kutumia "${m[2]}".',
  ),
  (
    RegExp(
      r'^This order would take you over your credit limit \(KES (\S+); KES (\S+) already outstanding\)\. Pay a deposit or in full instead\.$',
    ),
    (m) =>
        'Oda hii itazidi kikomo chako cha mkopo (KES ${m[1]}; KES ${m[2]} bado zinadaiwa). Lipa amana au ulipe kikamilifu badala yake.',
  ),
  (
    RegExp(r"^That's more than the outstanding balance \(KES (\S+)\)\.$"),
    (m) => 'Hicho ni zaidi ya salio linalodaiwa (KES ${m[1]}).',
  ),
  (
    RegExp(r'^Only KES (\S+) can be refunded on this order\.$'),
    (m) => 'Ni KES ${m[1]} pekee zinazoweza kurejeshwa kwa oda hii.',
  ),
  (
    RegExp(r'^The minimum order is (\d+) pieces \(you have (\d+)\)\.$'),
    (m) => 'Kiwango cha chini ni vipande ${m[1]} (una ${m[2]}).',
  ),
  (
    RegExp(
      r'^Size "(.+)" isn'
      "'"
      r't available for this item\.$',
    ),
    (m) => 'Saizi "${m[1]}" haipatikani kwa bidhaa hii.',
  ),
  (
    RegExp(r'^This purchase order is already (.+)\.$'),
    (m) => 'Agizo hili la ununuzi tayari ni ${m[1]}.',
  ),
  (
    RegExp(r'^KRA rejected the invoice: (.+)$'),
    (m) => 'KRA imekataa ankara: ${m[1]}',
  ),
  // From the item designer's checks (customization_pricing.dart).
  (
    RegExp(r'^(.+) is currently unavailable\.$'),
    (m) => '${_optionSw(m[1]!)} haipatikani kwa sasa.',
  ),
  (
    RegExp(r'^(.+): add artwork or text\.$'),
    (m) => '${_optionSw(m[1]!)}: ongeza nembo au maandishi.',
  ),
  // '"Item name": problem' from cart validation.
  (
    RegExp(r'^"([^"]+)": (.+)$'),
    (m) => '"${m[1]}": ${translateServerMessage(m[2]!)}',
  ),
];
