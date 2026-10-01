/// Kiswahili for the notifications sent to customers. Notices are written in
/// English where they're created; notifyUser translates them here when the
/// customer's app is set to Kiswahili (Users/{uid}/Settings/preferences
/// .language). Anything not matched is sent in English rather than guessed.

type Rule = [RegExp, string];

const TITLES: Rule[] = [
  [/^Order (.+) received$/, 'Oda $1 imepokelewa'],
  [/^Order (.+) confirmed$/, 'Oda $1 imethibitishwa'],
  [/^Your design proof is ready$/, 'Sampuli ya muundo wako iko tayari'],
  [/^Order (.+) is in production$/, 'Oda $1 iko kwenye uzalishaji'],
  [/^Order (.+) is ready to collect$/, 'Oda $1 iko tayari kuchukuliwa'],
  [/^Order (.+) is ready$/, 'Oda $1 iko tayari'],
  [/^Order (.+) is on its way$/, 'Oda $1 iko njiani'],
  [/^Order (.+) delivered$/, 'Oda $1 imefikishwa'],
  [/^Order (.+) was cancelled$/, 'Oda $1 imeghairiwa'],
  [/^Payment received — (.+)$/, 'Malipo yamepokelewa — $1'],
  [/^Refund on (.+)$/, 'Marejesho kwa $1'],
  [/^Invoice (.+) is overdue$/, 'Ankara $1 imechelewa'],
  [/^Your quote is ready — (.+)$/, 'Bei yako iko tayari — $1'],
  [/^About your quote request$/, 'Kuhusu ombi lako la bei'],
  [/^You left something in your cart$/, 'Umeacha kitu kwenye kikapu chako'],
  [/^New message about (.+)$/, 'Ujumbe mpya kuhusu $1'],
  [/^You earned (\d+) points$/, 'Umepata pointi $1'],
  [/^Referral bonus: (\d+) points$/, 'Zawadi ya rufaa: pointi $1'],
  [/^Test notification$/, 'Arifa ya majaribio'],
];

const BODIES: Rule[] = [
  [/^Total (.+) on your account\. We'll review it shortly\.$/, 'Jumla $1 kwenye akaunti yako. Tutaikagua hivi karibuni.'],
  [/^Total (.+)\. Pay the (.+) deposit from your order page to get started\.$/, 'Jumla $1. Lipa amana ya $2 kutoka ukurasa wa oda yako ili tuanze.'],
  [/^Total (.+)\. Pay from your order page to get started\.$/, 'Jumla $1. Lipa kutoka ukurasa wa oda yako ili tuanze.'],
  [/^We've reviewed your order and it's in the queue\.$/, 'Tumekagua oda yako na iko kwenye foleni.'],
  [/^Please approve the proof for (.+) so we can start production\.$/, 'Tafadhali idhinisha sampuli ya $1 ili tuanze uzalishaji.'],
  [/^Your items are being made now\.$/, 'Bidhaa zako zinatengenezwa sasa.'],
  [/^Bring your collection code \(on your order page\) to pick it up\.$/, 'Leta msimbo wako wa kuchukua (uko kwenye ukurasa wa oda yako) ili kuichukua.'],
  [/^It passed quality control and will be dispatched soon\.$/, 'Imepita ukaguzi wa ubora na itatumwa hivi karibuni.'],
  [/^Give the driver the 4-digit code on your order page when it arrives\.$/, 'Mpe dereva msimbo wa tarakimu 4 ulio kwenye ukurasa wa oda yako itakapofika.'],
  [/^Thank you! How did we do\? Leave a quick review from your order page\.$/, 'Asante! Tumefanyaje? Acha maoni mafupi kutoka ukurasa wa oda yako.'],
  [/^Reason: ([\s\S]+)$/, 'Sababu: $1'],
  [/^Contact us if you have any questions\.$/, 'Wasiliana nasi ukiwa na maswali yoyote.'],
  [/^Thank you\. Balance on (.+): (.+)\.$/, 'Asante. Salio la $1: $2.'],
  [/^Thank you — (.+) is fully paid\.$/, 'Asante — $1 imelipwa kikamilifu.'],
  [/^(.+) is being refunded to you\.$/, '$1 zinarejeshwa kwako.'],
  [/^(.+) is outstanding\. You can pay from your order page\.$/, '$1 zinadaiwa. Unaweza kulipa kutoka ukurasa wa oda yako.'],
  [/^([\s\S]+)\. Accept it in My quotes to place the order\.$/, '$1. Ikubali kwenye Bei Zangu ili kuweka oda.'],
  [/^We can't take on "(.+)" right now\.$/, 'Hatuwezi kushughulikia "$1" kwa sasa.'],
  [/^(\d+) item\(s\) are waiting for you\. Complete your order whenever you're ready\.$/, 'Bidhaa $1 zinakusubiri. Kamilisha oda yako wakati wowote ukiwa tayari.'],
  [/^Worth KES (.+) off a future order\.$/, 'Thamani ya punguzo la KES $1 kwenye oda ijayo.'],
  [/^Someone you referred just completed their first order\. Thank you!$/, 'Mtu uliyemwalika amekamilisha oda yake ya kwanza. Asante!'],
  [/^In-app notifications are working\.$/, 'Arifa za ndani ya programu zinafanya kazi.'],
];

function apply(rules: Rule[], text: string): string {
  for (const [re, out] of rules) {
    if (re.test(text)) return text.replace(re, out);
  }
  return text;
}

/// The words around an email's "Open in the app" button.
export function openInAppLabel(lang: string | undefined): string {
  return lang === 'sw' ? 'Fungua kwenye programu' : 'Open in the app';
}

export function localizeNotice(
  lang: string | undefined,
  title: string,
  body: string,
): { title: string; body: string } {
  if (lang !== 'sw') return { title, body };
  return { title: apply(TITLES, title), body: apply(BODIES, body) };
}
