// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Swahili (`sw`).
class AppLocalizationsSw extends AppLocalizations {
  AppLocalizationsSw([String locale = 'sw']) : super(locale);

  @override
  String get navHome => 'Nyumbani';

  @override
  String get navPackages => 'Vifurushi';

  @override
  String get navPortfolio => 'Kazi zetu';

  @override
  String get navOrders => 'Oda zangu';

  @override
  String get navTracking => 'Fuatilia usafirishaji';

  @override
  String get navCart => 'Kikapu na malipo';

  @override
  String get navNotifications => 'Arifa';

  @override
  String get navSupport => 'Msaada';

  @override
  String get navProfile => 'Wasifu';

  @override
  String get statusPendingReview => 'Inasubiri ukaguzi';

  @override
  String get statusConfirmed => 'Imethibitishwa';

  @override
  String get statusAwaitingProof => 'Sampuli inasubiri idhini';

  @override
  String get statusInProduction => 'Inatengenezwa';

  @override
  String get statusQualityCheck => 'Ukaguzi wa ubora';

  @override
  String get statusReadyForDelivery => 'Iko tayari kusafirishwa';

  @override
  String get statusOutForDelivery => 'Iko njiani';

  @override
  String get statusCompleted => 'Imekamilika';

  @override
  String get statusCancelled => 'Imeghairiwa';

  @override
  String get addToCart => 'Ongeza kwenye kikapu';

  @override
  String get customiseAndOrder => 'Weka nembo na uagize';

  @override
  String get requestQuote => 'Kazi maalum au bei ya jumla? Omba bei';

  @override
  String get placeOrder => 'Weka oda';

  @override
  String get deliveryDetails => 'Maelezo ya usafirishaji';

  @override
  String get contactName => 'Jina la mawasiliano';

  @override
  String get contactPhone => 'Nambari ya simu';

  @override
  String get deliveryAddress => 'Anwani ya kufikisha';

  @override
  String get subtotal => 'Jumla ndogo';

  @override
  String get total => 'Jumla';

  @override
  String get howToPay => 'Ungependa kulipa vipi?';

  @override
  String get payInFull => 'Lipa yote';

  @override
  String get promoCode => 'Msimbo wa punguzo';

  @override
  String get apply => 'Tumia';

  @override
  String get payment => 'Malipo';

  @override
  String get payWith => 'Lipa kwa';

  @override
  String payAmount(String amount) {
    return 'Lipa $amount';
  }

  @override
  String get documents => 'Nyaraka';

  @override
  String get history => 'Historia';

  @override
  String get items => 'Bidhaa';

  @override
  String get orderAgain => 'Agiza tena';

  @override
  String get messageUs => 'Tutumie ujumbe';

  @override
  String get cancelOrder => 'Ghairi oda';

  @override
  String get notificationsTitle => 'Arifa';

  @override
  String get markAllRead => 'Zote zimesomwa';

  @override
  String get noNotifications => 'Bado hakuna arifa';

  @override
  String get language => 'Lugha';

  @override
  String get deliveryCodeHint =>
      'Mpe dereva namba hii oda yako ikifika — ndipo atakukabidhi.';

  @override
  String get pickupCodeHint => 'Onyesha namba hii unapochukua oda yako.';

  @override
  String get rateOrderTitle => 'Tulifanyaje?';

  @override
  String get rateOrderSubtitle =>
      'Tathmini oda yako — inasaidia wateja wengine.';

  @override
  String get review => 'Tathmini';

  @override
  String get cartEmpty => 'Kikapu chako ni tupu';

  @override
  String get wishlist => 'Orodha ya matamanio';

  @override
  String get rewards => 'Zawadi';

  @override
  String get whatsappUs => 'Tuandikie WhatsApp';

  @override
  String waOrderMessage(String orderNumber, String status) {
    return 'Habari BrightBrush, ninawasiliana kuhusu oda yangu $orderNumber (hali: $status). ';
  }

  @override
  String waItemMessage(String item) {
    return 'Habari BrightBrush, ningependa kuuliza kuhusu \"$item\". ';
  }

  @override
  String waQuoteMessage(String title) {
    return 'Habari BrightBrush, kuhusu ombi langu la bei \"$title\": ';
  }

  @override
  String get waSupportMessage =>
      'Habari BrightBrush, ninahitaji msaada kuhusu: ';

  @override
  String get workingHours => 'Saa za kazi';

  @override
  String get homeSearchHint => 'Tafuta kofia, hoodie, chupa…';

  @override
  String get shopByCategory => 'Nunua kwa aina';

  @override
  String get seeAll => 'Ona zote';

  @override
  String get sectionFeatured => 'Zilizoangaziwa';

  @override
  String get sectionBulkDeals => 'Ofa za jumla';

  @override
  String get sectionTopRated => 'Zilizopendwa zaidi';

  @override
  String get sectionNewArrivals => 'Mpya';

  @override
  String get sectionRecentlyViewed => 'Ulizotazama karibuni';

  @override
  String get sectionBundles => 'Vifurushi';

  @override
  String get sectionAllProducts => 'Bidhaa zote';

  @override
  String get sortLabel => 'Panga';

  @override
  String get filterLabel => 'Chuja';

  @override
  String get sortRecommended => 'Zinazopendekezwa';

  @override
  String get sortPriceLow => 'Bei: chini kwenda juu';

  @override
  String get sortPriceHigh => 'Bei: juu kwenda chini';

  @override
  String get sortNewest => 'Mpya zaidi';

  @override
  String get sortTopRated => 'Zilizopendwa zaidi';

  @override
  String get sortBulkSaving => 'Punguzo kubwa la jumla';

  @override
  String itemsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Bidhaa $count',
      one: 'Bidhaa 1',
    );
    return '$_temp0';
  }

  @override
  String get clearAll => 'Futa zote';

  @override
  String saveUpTo(int percent) {
    return 'Okoa hadi $percent%';
  }

  @override
  String get badgeNew => 'Mpya';

  @override
  String get badgeFeatured => 'Maalum';

  @override
  String get badgeCustomisable => 'Weka nembo yako';

  @override
  String endsIn(String time) {
    return 'Inaisha baada ya $time';
  }

  @override
  String get recentSearches => 'Ulichotafuta karibuni';

  @override
  String searchFor(String query) {
    return 'Tafuta \"$query\"';
  }

  @override
  String get backToTop => 'Rudi juu';

  @override
  String get customiseCtaTitle => 'Weka nembo yako kwenye chochote';

  @override
  String get customiseCtaBody =>
      'Pakia nembo yako, ione moja kwa moja na uidhinishe sampuli kabla hatujashona.';

  @override
  String get customiseCtaAction => 'Anza kubuni';

  @override
  String get bulkQuoteTitle => 'Unaagiza vipande 100+?';

  @override
  String get bulkQuoteBody =>
      'Pata bei maalum kwa shule, timu, hafla na makampuni.';

  @override
  String get bulkQuoteAction => 'Omba bei';

  @override
  String get trackOrderTitle => 'Fuatilia oda yako';

  @override
  String get trackOrderBody =>
      'Ona kila hatua kuanzia sampuli hadi kufikishwa.';

  @override
  String trustFreeDelivery(String amount) {
    return 'Usafirishaji bure zaidi ya $amount';
  }

  @override
  String get trustPayments => 'Lipa kwa M-Pesa au kadi';

  @override
  String get trustProof => 'Idhinisha sampuli kwanza';

  @override
  String get trustBulk => 'Bei nafuu kwa jumla';

  @override
  String get filterPrice => 'Bei (KES)';

  @override
  String get filterCustomisable => 'Naweza kuweka nembo';

  @override
  String get filterRating => 'Nyota 4 na zaidi';

  @override
  String get filterLeadTime => 'Tayari ndani ya';

  @override
  String get filterCategory => 'Aina';

  @override
  String daysCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Siku $count',
      one: 'Siku 1',
    );
    return '$_temp0';
  }

  @override
  String get anyTime => 'Wakati wowote';

  @override
  String get allCategories => 'Zote';

  @override
  String showResults(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Onyesha bidhaa $count',
      one: 'Onyesha bidhaa 1',
      zero: 'Hakuna bidhaa',
    );
    return '$_temp0';
  }

  @override
  String get noMatchesTitle => 'Hakuna bidhaa zinazolingana';

  @override
  String get noMatchesBody => 'Jaribu neno lingine au futa vichujio.';

  @override
  String get askAi => 'Uliza AI';

  @override
  String minOrderShort(int moq, int days) {
    return 'Kiwango $moq · siku $days';
  }

  @override
  String fromPrice(String price) {
    return 'Kuanzia $price';
  }

  @override
  String get gridView => 'Mwonekano wa gridi';

  @override
  String get listView => 'Mwonekano wa orodha';

  @override
  String get catalogEmptyTitle => 'Bado hakuna bidhaa';

  @override
  String get catalogEmptyBody =>
      'Bidhaa mpya zitaonekana hapa mara tu zitakapoongezwa.';

  @override
  String get couldNotLoadCatalog => 'Imeshindwa kupakia bidhaa';

  @override
  String get retry => 'Jaribu tena';

  @override
  String addedToCart(String item, int qty) {
    return '$item imeongezwa kwenye kikapu ($qty)';
  }

  @override
  String cartCount(int count) {
    return 'Kikapu · $count';
  }

  @override
  String ratingCount(int count) {
    return '($count)';
  }
}
