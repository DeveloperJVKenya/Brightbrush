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

  @override
  String get netOfflineTitle => 'Uko nje ya mtandao';

  @override
  String get netOfflineBody =>
      'Unaona taarifa zilizohifadhiwa kwenye kifaa hiki. Washa Wi-Fi au data ili kuona taarifa mpya na kuagiza.';

  @override
  String get netOfflineNoInternetBody =>
      'Umeunganishwa, lakini mtandao haupatikani. Angalia kifurushi chako cha data au badili kwenda Wi-Fi bora. Unaona taarifa zilizohifadhiwa.';

  @override
  String get netWeakTitle => 'Mtandao ni dhaifu';

  @override
  String get netWeakBody =>
      'Huenda mambo yakapakia polepole. Sogea mahali penye mtandao bora au unganisha Wi-Fi.';

  @override
  String get netBackOnline => 'Umerudi mtandaoni';

  @override
  String get netOpenSettings => 'Fungua mipangilio';

  @override
  String get netDismiss => 'Funga';

  @override
  String get netActionNeedsInternet =>
      'Uko nje ya mtandao. Unganisha intaneti kisha ujaribu tena.';

  @override
  String get netSavedCopyTag => 'Nakala iliyohifadhiwa';

  @override
  String get errNetwork =>
      'Tafadhali angalia muunganisho wako wa intaneti kisha ujaribu tena.';

  @override
  String get errPermission =>
      'Huna ruhusa ya kufanya hivi. Wasiliana na msimamizi ukiona ni kosa.';

  @override
  String get errAssistant =>
      'Msaidizi haupatikani kwa sasa. Tafadhali jaribu tena baada ya muda mfupi.';

  @override
  String get errSlow =>
      'Inachukua muda mrefu kuliko kawaida. Tafadhali jaribu tena.';

  @override
  String get errNotFound => 'Haikupatikana — huenda imeondolewa.';

  @override
  String get errGeneric => 'Hitilafu imetokea. Tafadhali jaribu tena.';

  @override
  String get couldntLoadYourCart => 'Imeshindwa kupakia kikapu chako';

  @override
  String get loading => 'Inapakia';

  @override
  String get addItemsOrSeasonalPackagesFrom =>
      'Ongeza bidhaa au vifurushi vya msimu kutoka katalogi ili kuanza oda.';

  @override
  String get packageNoLongerAvailable => 'Kifurushi hakipatikani tena';

  @override
  String get itemNoLongerAvailable => 'Bidhaa haipatikani tena';

  @override
  String get removeTheItemsThatAreNo =>
      'Ondoa bidhaa zisizopatikana tena ili kuendelea.';

  @override
  String tapEditToFixIt(Object invalid, Object problem) {
    return '\"$invalid\": $problem Gusa hariri ili kurekebisha.';
  }

  @override
  String hasAMinimumOrderOf(Object below, Object minQuantity) {
    return '\"$below\" ina kiwango cha chini cha $minQuantity.';
  }

  @override
  String get orderPlacedYouCanPayFor =>
      'Oda imewekwa — unaweza kuilipia hapa hapa.';

  @override
  String couldntPlaceOrder(Object error) {
    return 'Imeshindwa kuweka oda: $error';
  }

  @override
  String get chooseYourDeliveryArea => 'Chagua eneo lako la kufikisha.';

  @override
  String pcs(Object quantity, Object amount) {
    return 'Vipande $quantity · $amount';
  }

  @override
  String get package => 'Kifurushi';

  @override
  String min(Object minQuantity) {
    return 'chini $minQuantity';
  }

  @override
  String get removeThisToContinue => 'Ondoa hii ili kuendelea';

  @override
  String get edit => 'Hariri';

  @override
  String get remove => 'Ondoa';

  @override
  String get deliverToMe => 'Niletee';

  @override
  String get illPickUp => 'Nitachukua mwenyewe';

  @override
  String pickUpAt(Object pickupAddress) {
    return 'Chukua hapa: $pickupAddress';
  }

  @override
  String get deliveryArea => 'Eneo la kufikisha';

  @override
  String get enterYourName => 'Weka jina lako';

  @override
  String get enterAPhoneNumber => 'Weka namba ya simu';

  @override
  String get dropAPinForTheDriver =>
      'Weka alama kwenye ramani kwa dereva (hiari)';

  @override
  String get pinSetTapToAdjust => 'Alama imewekwa — gusa kurekebisha';

  @override
  String get save => 'Hifadhi';

  @override
  String get enterADeliveryAddress => 'Weka anwani ya kufikisha';

  @override
  String get notesArtworkDetailsColoursSizes =>
      'Maelezo (nembo, rangi, saizi...)';

  @override
  String get cartChangedApplyAgain => 'Kikapu kimebadilika — tumia tena';

  @override
  String get codeApplied => 'Msimbo umetumika';

  @override
  String accountDiscount(Object discountPercent) {
    return 'Punguzo la akaunti ($discountPercent%)';
  }

  @override
  String useMyPointsAvailable(Object myPoints) {
    return 'Tumia pointi zangu ($myPoints zipo)';
  }

  @override
  String upToOfTheOrder(Object maxRedeemPercent) {
    return 'Hadi $maxRedeemPercent% ya oda';
  }

  @override
  String points(Object points) {
    return 'Pointi ($points)';
  }

  @override
  String promo(Object text) {
    return 'Punguzo $text';
  }

  @override
  String get delivery => 'Usafirishaji';

  @override
  String get deliveryFree => 'Usafirishaji (bure)';

  @override
  String includesVat(Object taxRate) {
    return 'Inajumuisha VAT ($taxRate%)';
  }

  @override
  String vat(Object taxRate) {
    return 'VAT ($taxRate%)';
  }

  @override
  String deposit(Object depositPercent) {
    return 'Amana ya $depositPercent%';
  }

  @override
  String onAccountD(Object paymentTermsDays) {
    return 'Kwa akaunti (siku $paymentTermsDays)';
  }

  @override
  String payNowToStartProductionAnd(Object amount, Object amount2) {
    return 'Lipa $amount sasa ili uzalishaji uanze, na $amount2 kabla ya kufikishwa.';
  }

  @override
  String get youllChooseHowToPayM =>
      'Utachagua njia ya kulipa (M-Pesa, kadi na nyinginezo) kwenye ukurasa unaofuata. Bei za mwisho huthibitishwa oda inapowekwa.';

  @override
  String get decreaseQuantity => 'Punguza idadi';

  @override
  String get increaseQuantity => 'Ongeza idadi';

  @override
  String get quantity => 'Idadi';

  @override
  String minimum(Object minQuantity) {
    return 'Kiwango cha chini $minQuantity';
  }

  @override
  String get cancel => 'Ghairi';

  @override
  String get set => 'Weka';

  @override
  String get back => 'Rudi';

  @override
  String get itemDetails => 'Maelezo ya bidhaa';

  @override
  String get failedToLoad => 'Imeshindwa kupakia';

  @override
  String get itemNotFound => 'Bidhaa haikupatikana';

  @override
  String get itMayHaveBeenRemovedOr => 'Huenda imeondolewa au haipo tena.';

  @override
  String from(Object amount) {
    return 'Kuanzia $amount';
  }

  @override
  String moq(Object moq) {
    return 'Kiwango cha chini $moq';
  }

  @override
  String dayLeadTime(Object leadTimeDays) {
    return 'Tayari baada ya siku $leadTimeDays';
  }

  @override
  String get noDescriptionProvidedYet => 'Bado hakuna maelezo.';

  @override
  String signInOrCreateAnAccount(Object item) {
    return 'Ingia au fungua akaunti ili kuongeza \"$item\" kwenye kikapu chako.';
  }

  @override
  String addedMinimumOrder(Object item, Object moq) {
    return '$item imeongezwa (kiwango cha chini $moq)';
  }

  @override
  String couldntAddToCart(Object error) {
    return 'Imeshindwa kuongeza kwenye kikapu: $error';
  }

  @override
  String get ticketSentWellGetBackTo => 'Ombi limetumwa — tutakujibu hapa.';

  @override
  String couldntSend(Object error) {
    return 'Imeshindwa kutuma: $error';
  }

  @override
  String get tellUsAboutAnOrderA => 'Tueleze kuhusu oda, muundo au malalamiko.';

  @override
  String get subject => 'Kichwa';

  @override
  String get enterASubject => 'Weka kichwa';

  @override
  String get message => 'Ujumbe';

  @override
  String get enterAMessage => 'Andika ujumbe';

  @override
  String get send => 'Tuma';

  @override
  String get yourTickets => 'Maombi yako';

  @override
  String get couldntLoadTickets => 'Imeshindwa kupakia maombi';

  @override
  String get noTicketsYet => 'Bado hakuna maombi';

  @override
  String get anythingYouSendAboveWillShow =>
      'Chochote utakachotuma hapo juu kitaonekana hapa pamoja na jibu letu.';

  @override
  String get couldntLoadYourOrders => 'Imeshindwa kupakia oda zako';

  @override
  String get nothingOutForDelivery => 'Hakuna oda iliyo njiani';

  @override
  String get onceAnOrderIsOutFor =>
      'Oda ikiwa njiani kufikishwa, ifuatilie moja kwa moja hapa.';

  @override
  String get myOrders => 'Oda zangu';

  @override
  String get myQuotes => 'Bei zangu';

  @override
  String get everyOrderYouvePlacedWithLive =>
      'Kila oda uliyoweka, pamoja na hali yake inapoendelea kwenye uzalishaji.';

  @override
  String get searchYourOrders => 'Tafuta oda zako';

  @override
  String get couldntLoadOrders => 'Imeshindwa kupakia oda';

  @override
  String get noOrdersYet => 'Bado hakuna oda';

  @override
  String get noMatches => 'Hakuna zinazolingana';

  @override
  String get ordersYouPlaceFromTheCatalog =>
      'Oda utakazoweka kutoka katalogi zitaonekana hapa pamoja na hali yake.';

  @override
  String get tryADifferentSearchTerm => 'Jaribu neno lingine la kutafuta.';

  @override
  String get orderDetails => 'Maelezo ya oda';

  @override
  String get orderNotFound => 'Oda haikupatikana';

  @override
  String get itMayHaveBeenRemoved => 'Huenda imeondolewa.';

  @override
  String get paymentReceivedThankYou => 'Malipo yamepokelewa — asante!';

  @override
  String get confirmingYourPaymentWithTheProvider =>
      'Tunathibitisha malipo yako na mtoa huduma… ukurasa huu utajisasisha wenyewe.';

  @override
  String get paymentCancelledYouCanTryAgain =>
      'Malipo yameghairiwa. Unaweza kujaribu tena hapa chini.';

  @override
  String get thePaymentDidntGoThroughYou =>
      'Malipo hayakufanikiwa. Unaweza kujaribu tena hapa chini.';

  @override
  String get nothingToReorderQuotedItemsNeed =>
      'Hakuna cha kuagiza tena — bidhaa za bei maalum zinahitaji bei mpya.';

  @override
  String addedItemSToYourCart(Object added) {
    return 'Bidhaa $added zimeongezwa kwenye kikapu chako. Bei husasishwa wakati wa kulipa.';
  }

  @override
  String get cancelThisOrder => 'Ughairi oda hii?';

  @override
  String get thisCantBeUndone => 'Hili haliwezi kutenduliwa.';

  @override
  String get keepOrder => 'Endelea na oda';

  @override
  String couldntCancel(Object error) {
    return 'Imeshindwa kughairi: $error';
  }

  @override
  String get thisPackageDoesntListSpecificCatalog =>
      'Kifurushi hiki bado hakionyeshi bidhaa mahususi.';

  @override
  String includesCatalogItemS(Object count) {
    return 'Kinajumuisha bidhaa $count za katalogi.';
  }

  @override
  String signInOrCreateAnAccount2(Object package) {
    return 'Ingia au fungua akaunti ili kuagiza \"$package\".';
  }

  @override
  String addedToCart2(Object package) {
    return '\"$package\" kimeongezwa kwenye kikapu';
  }

  @override
  String get customiseItRequestAQuote => 'Kibinafsishe — omba bei';

  @override
  String get seasonalPackages => 'Vifurushi vya msimu';

  @override
  String get curatedBundlesForCampaignsAndSeasons =>
      'Vifurushi maalum kwa kampeni na misimu — Valentine, uchaguzi na mengineyo.';

  @override
  String get searchPackagesEGValentines =>
      'Tafuta vifurushi, mf. \"valentine\"';

  @override
  String get couldntLoadPackages => 'Imeshindwa kupakia vifurushi';

  @override
  String get noPackagesYet => 'Bado hakuna vifurushi';

  @override
  String get seasonalPackagesSetUpByThe =>
      'Vifurushi vya msimu vitakavyowekwa na Meneja wa Mfumo vitaonekana hapa.';

  @override
  String get filtersUpdated => 'Vichujio vimesasishwa.';

  @override
  String couldntReachTheAiAssistant(Object error) {
    return 'Imeshindwa kumfikia msaidizi wa AI: $error';
  }

  @override
  String get askWhatYouNeed => 'Uliza unachohitaji';

  @override
  String get describeTheOccasionOrItemIn =>
      'Eleza tukio au bidhaa kwa maneno yako — mf. \"kitu cha pikiniki ya kampuni, watu 60\" — nasi tutaweka vichujio sahihi.';

  @override
  String get whatAreYouBrandingAndFor =>
      'Unaweka nembo kwenye nini, na kwa ajili ya nini?';

  @override
  String get ask => 'Uliza';

  @override
  String order(Object displayNumber) {
    return 'Oda $displayNumber';
  }

  @override
  String itemS(Object itemCount, Object amount) {
    return 'Bidhaa $itemCount · $amount';
  }

  @override
  String get backToHome => 'Rudi mwanzo';

  @override
  String starsFromReviews(Object avg, Object count) {
    return 'Nyota $avg kutoka maoni $count';
  }

  @override
  String get removeFromWishlist => 'Ondoa kwenye orodha ya matamanio';

  @override
  String get saveToWishlist => 'Hifadhi kwenye orodha ya matamanio';

  @override
  String signInToSaveToYour(Object itemName) {
    return 'Ingia ili kuhifadhi \"$itemName\" kwenye orodha yako ya matamanio.';
  }

  @override
  String get clearSearch => 'Futa utafutaji';

  @override
  String items2(Object category, Object count) {
    return '$category, bidhaa $count';
  }

  @override
  String items3(Object count, Object amount) {
    return 'Bidhaa $count · $amount';
  }

  @override
  String get oneSystemForOrdersProductionDelivery =>
      'Mfumo mmoja wa oda, uzalishaji, ufikishaji na hesabu za kila kofia, hoodie na kifurushi cha kampeni.';

  @override
  String somethingWentWrong(Object code) {
    return 'Hitilafu imetokea ($code).';
  }

  @override
  String get enterYourEmailAboveFirstThen =>
      'Weka barua pepe yako hapo juu kwanza, kisha gusa \"Umesahau nenosiri?\".';

  @override
  String ifAnAccountExistsForA(Object email) {
    return 'Ikiwa akaunti ya $email ipo, kiungo cha kubadilisha nenosiri kinakuja. Angalia kikasha chako na folda ya barua taka.';
  }

  @override
  String get pleaseAcceptTheTermsAndPrivacy =>
      'Tafadhali kubali Masharti na Sera ya Faragha ili kuendelea.';

  @override
  String get createYourAccount => 'Fungua akaunti yako';

  @override
  String get signIn => 'Ingia';

  @override
  String get accessYourBrightbrushCreationsWorkspace =>
      'Fikia eneo lako la kazi la BrightBrush Creations.';

  @override
  String get fullName => 'Jina kamili';

  @override
  String get email => 'Barua pepe';

  @override
  String get enterAValidEmail => 'Weka barua pepe sahihi';

  @override
  String get password => 'Nenosiri';

  @override
  String get atLeast6Characters => 'Angalau herufi 6';

  @override
  String get forgotPassword => 'Umesahau nenosiri?';

  @override
  String get iAgreeToThe => 'Ninakubali ';

  @override
  String get terms => 'Masharti';

  @override
  String get and => ' na ';

  @override
  String get privacyPolicy => 'Sera ya Faragha';

  @override
  String get createAccount => 'Fungua akaunti';

  @override
  String get alreadyHaveAnAccountSignIn => 'Una akaunti tayari? Ingia';

  @override
  String get dontHaveAnAccountSignUp => 'Huna akaunti? Jisajili';

  @override
  String get signingUpHereAlwaysCreatesA =>
      'Kujisajili hapa hufungua akaunti ya Mtumiaji wa kawaida. Nafasi nyingine zote hupangwa baadaye na Msimamizi/Mkurugenzi au Msanidi.';

  @override
  String verificationEmailSentTo(Object email) {
    return 'Barua pepe ya uthibitisho imetumwa kwa $email.';
  }

  @override
  String get emailVerifiedThankYou => 'Barua pepe imethibitishwa — asante!';

  @override
  String get notVerifiedYetCheckYourInbox =>
      'Bado haijathibitishwa. Angalia kikasha chako (na folda ya barua taka).';

  @override
  String verifyYourEmailSoWeCan(Object email) {
    return 'Thibitisha barua pepe yako ($email) ili tukutumie risiti na taarifa za oda.';
  }

  @override
  String get sendLink => 'Tuma kiungo';

  @override
  String get iveVerified => 'Nimethibitisha';

  @override
  String get privacyPolicy2 => 'Sera ya faragha';

  @override
  String get termsOfService => 'Masharti ya huduma';

  @override
  String get deleteMyAccount => 'Futa akaunti yangu';

  @override
  String get permanentlyRemovesYourProfileCartAnd =>
      'Huondoa kabisa wasifu wako, kikapu na maombi ya bei.';

  @override
  String get thatPasswordIsIncorrect => 'Nenosiri hilo si sahihi.';

  @override
  String get couldntConfirmYourIdentity =>
      'Imeshindwa kuthibitisha utambulisho wako.';

  @override
  String get deleteYourAccount => 'Ufute akaunti yako?';

  @override
  String get thisPermanentlyDeletesYourLoginProfile =>
      'Hii hufuta kabisa akaunti yako ya kuingia, wasifu, kikapu na maombi ya bei. Oda za zamani huhifadhiwa bila jina kwa kumbukumbu zetu za kodi. Huwezi kufuta akaunti yako wakati oda bado inaendelea.';

  @override
  String get yourPassword => 'Nenosiri lako';

  @override
  String get typeDeleteToConfirm => 'Andika DELETE ili kuthibitisha';

  @override
  String get keepMyAccount => 'Baki na akaunti yangu';

  @override
  String get deleteForever => 'Futa kabisa';

  @override
  String get chatWithCustomer => 'Zungumza na mteja';

  @override
  String get filesMustBeUnder10Mb => 'Faili lazima ziwe chini ya MB 10.';

  @override
  String messages(Object orderLabel) {
    return 'Ujumbe · $orderLabel';
  }

  @override
  String get noMessagesYet => 'Bado hakuna ujumbe.';

  @override
  String get questionsAboutSizesPlacementOrDelivery =>
      'Una maswali kuhusu saizi, mahali pa nembo au ufikishaji? Tutumie ujumbe.';

  @override
  String get attachPhotoOrPdf => 'Ambatisha picha au PDF';

  @override
  String get writeAMessage => 'Andika ujumbe';

  @override
  String get customise => 'Binafsisha';

  @override
  String customise2(Object item) {
    return 'Binafsisha $item';
  }

  @override
  String get itemNotAvailable => 'Bidhaa haipatikani';

  @override
  String get itMayHaveBeenRemovedFrom => 'Huenda imeondolewa kwenye katalogi.';

  @override
  String get notCustomisable => 'Haibinafsishwi';

  @override
  String get thisItemIsSoldAsIs =>
      'Bidhaa hii huuzwa kama ilivyo. Iongeze kutoka ukurasa wake.';

  @override
  String get signInToUploadYourLogo =>
      'Ingia ili kupakia nembo yako na kuihifadhi kwenye maktaba yako.';

  @override
  String get signInOrCreateAnAccount3 =>
      'Ingia au fungua akaunti ili kuongeza hii kwenye kikapu chako.';

  @override
  String get cartUpdated => 'Kikapu kimesasishwa';

  @override
  String addedToYourCart(Object item) {
    return '$item imeongezwa kwenye kikapu chako';
  }

  @override
  String get colour => 'Rangi';

  @override
  String get pieces => 'Vipande';

  @override
  String get branding => 'Uwekaji nembo';

  @override
  String get addALogoOrTextAt => 'Ongeza nembo au maandishi kwenye kila mahali';

  @override
  String get addAnotherPlacement => 'Ongeza mahali pengine';

  @override
  String get namesOptional => 'Majina (hiari)';

  @override
  String onePerLineEGStaff(Object amount) {
    return 'Moja kwa kila mstari, mf. majina ya wafanyakazi — $amount kwa kipande';
  }

  @override
  String pcsEach(Object quantity, Object amount) {
    return 'Vipande $quantity · $amount kila kimoja';
  }

  @override
  String get updateCart => 'Sasisha kikapu';

  @override
  String get removePlacement => 'Ondoa mahali';

  @override
  String get uploadChooseLogo => 'Pakia / chagua nembo';

  @override
  String get removeLogo => 'Ondoa nembo';

  @override
  String get alreadyDigitizedNoDigitizingFee =>
      'Tayari imeandaliwa kwa kushona — hakuna ada ya maandalizi.';

  @override
  String get orTextToPrintStitch => 'Au maandishi ya kuchapisha/kushona';

  @override
  String get extraTextOptional => 'Maandishi ya ziada (hiari)';

  @override
  String get threadColoursCommaSeparated =>
      'Rangi za uzi (tenganisha kwa koma)';

  @override
  String get eGWhiteGold => 'mf. Nyeupe, Dhahabu';

  @override
  String brandingPerPiece(Object amount) {
    return 'Uwekaji nembo ($amount kwa kipande)';
  }

  @override
  String get oneOffSetupDigitizing =>
      'Maandalizi ya mara moja / kuandaa kushona';

  @override
  String get names => 'Majina';

  @override
  String get itemTotal => 'Jumla ya bidhaa';

  @override
  String get deliveryAndVatAreAddedAt =>
      'Usafirishaji na VAT huongezwa wakati wa kulipa. Utaidhinisha sampuli ya kidijitali kabla hatujazalisha chochote.';

  @override
  String addedToYourLibrary(Object art) {
    return '\"$art\" imeongezwa kwenye maktaba yako';
  }

  @override
  String uploadFailed(Object error) {
    return 'Imeshindwa kupakia: $error';
  }

  @override
  String get notDigitizedYet => 'Bado haijaandaliwa kwa kushona';

  @override
  String get rename => 'Badilisha jina';

  @override
  String get deleteFromLibrary => 'Futa kwenye maktaba';

  @override
  String get pastOrdersKeepTheirCopy =>
      'Oda za zamani zinabaki na nakala yake.';

  @override
  String get renameArtwork => 'Badilisha jina la nembo';

  @override
  String get deleted => 'Imefutwa';

  @override
  String get myArtwork => 'Nembo zangu';

  @override
  String get uploadLogo => 'Pakia nembo';

  @override
  String get couldntLoadYourArtwork => 'Imeshindwa kupakia nembo zako';

  @override
  String get noArtworkYet => 'Bado hakuna nembo';

  @override
  String get uploadYourLogoOnceAndReuse =>
      'Pakia nembo yako mara moja na uitumie tena kwenye kofia, shati, chupa na zaidi.';

  @override
  String get thatFileIsOver25Mb =>
      'Faili hiyo inazidi MB 25. Tafadhali pakia ndogo zaidi.';

  @override
  String get chooseYourArtwork => 'Chagua nembo yako';

  @override
  String get pngWithATransparentBackgroundGives =>
      'PNG yenye mandharinyuma angavu hutoa mfano bora. Faili za vekta (SVG, AI, EPS, PDF) zinakaribishwa kwa uzalishaji.';

  @override
  String get uploadNewArtwork => 'Pakia nembo mpya';

  @override
  String get yourLibrary => 'Maktaba yako';

  @override
  String get digitizedNoSetupFeeForEmbroidery =>
      'Imeandaliwa — hakuna ada ya maandalizi ya kushona';

  @override
  String pcs2(Object e) {
    return 'Vipande $e';
  }

  @override
  String get dragADesignToAdjustIts =>
      'Buruta muundo ili kurekebisha mahali pake. Mahali pa mwisho huthibitishwa kwenye sampuli yako.';

  @override
  String get logo => 'Nembo';

  @override
  String get yourDesign => 'Muundo wako';

  @override
  String get tellUsWhatYoudLikeChanged =>
      'Tuambie ungependa nini kibadilishwe.';

  @override
  String get approvedProductionCanBegin =>
      'Imeidhinishwa — uzalishaji unaweza kuanza.';

  @override
  String get thanksWellSendARevisedProof =>
      'Asante — tutatuma sampuli iliyorekebishwa.';

  @override
  String get designProof => 'Sampuli ya muundo';

  @override
  String get ourDesignersArePreparingADigital =>
      'Wabunifu wetu wanaandaa sampuli ya kidijitali ya nembo yako. Utaiidhinisha hapa kabla chochote hakijazalishwa.';

  @override
  String version(Object version, Object proofStatus) {
    return 'Toleo $version · $proofStatus';
  }

  @override
  String stitches(Object amount) {
    return 'Mishono $amount';
  }

  @override
  String get commentsRequiredToRequestChanges =>
      'Maoni (yanahitajika kuomba mabadiliko)';

  @override
  String get approveProof => 'Idhinisha sampuli';

  @override
  String get requestChanges => 'Omba mabadiliko';

  @override
  String yourComment(Object customerComment) {
    return 'Maoni yako: $customerComment';
  }

  @override
  String earlierVersions(Object length) {
    return 'Matoleo ya awali ($length)';
  }

  @override
  String version2(Object version, Object status) {
    return 'Toleo $version · $status';
  }

  @override
  String get proofSentToTheCustomer => 'Sampuli imetumwa kwa mteja';

  @override
  String proof(Object displayNumber) {
    return 'Sampuli · $displayNumber';
  }

  @override
  String status(Object proofStatus) {
    return 'Hali: $proofStatus';
  }

  @override
  String customer(Object customerComment) {
    return 'Mteja: $customerComment';
  }

  @override
  String get sendANewVersion => 'Tuma toleo jipya';

  @override
  String get addMockupStitchOutPhotos => 'Ongeza picha za mfano / za mishono';

  @override
  String get stitchCountEmbroideryOptional =>
      'Idadi ya mishono (kushona, hiari)';

  @override
  String get noteToCustomerSizesThreadColours =>
      'Ujumbe kwa mteja (saizi, rangi za uzi, mahali)';

  @override
  String get close => 'Funga';

  @override
  String get sendProof => 'Tuma sampuli';

  @override
  String get newRequest => 'Ombi jipya';

  @override
  String get couldntLoadYourQuotes => 'Imeshindwa kupakia bei zako';

  @override
  String get noQuoteRequestsYet => 'Bado hakuna maombi ya bei';

  @override
  String get needACustomJobABig =>
      'Unahitaji kazi maalum, idadi kubwa au kifurushi kilichoandaliwa kwa ajili yako? Omba bei.';

  @override
  String get turnDownThisPrice => 'Ukatae bei hii?';

  @override
  String get withdrawThisRequest => 'Uondoe ombi hili?';

  @override
  String get keep => 'Baki nayo';

  @override
  String get turnDown => 'Kataa';

  @override
  String get withdraw => 'Ondoa ombi';

  @override
  String get expired => 'Imepitwa na muda';

  @override
  String pcsRequested(Object quantity, Object amount) {
    return 'Vipande $quantity · iliombwa $amount';
  }

  @override
  String get quotedPrice => 'Bei iliyotolewa';

  @override
  String validUntilIncludesDelivery(Object amount) {
    return 'Halali hadi $amount · inajumuisha usafirishaji';
  }

  @override
  String get acceptOrder => 'Kubali na uagize';

  @override
  String get quotePdf => 'PDF ya bei';

  @override
  String get viewOrder => 'Tazama oda';

  @override
  String get acceptQuote => 'Kubali bei';

  @override
  String get enterAName => 'Weka jina';

  @override
  String get enterAnAddress => 'Weka anwani';

  @override
  String get notesOptional => 'Maelezo (hiari)';

  @override
  String totalPayNow(Object amount, Object amount2) {
    return 'Jumla $amount · lipa $amount2 sasa';
  }

  @override
  String total2(Object amount) {
    return 'Jumla $amount';
  }

  @override
  String get signInOrCreateAnAccount4 =>
      'Ingia au fungua akaunti ili kuomba bei.';

  @override
  String get quoteRequestSentWellPriceIt =>
      'Ombi la bei limetumwa — tutaweka bei na kukujulisha kwenye Bei Zangu.';

  @override
  String get view => 'Tazama';

  @override
  String couldntSendRequest(Object error) {
    return 'Imeshindwa kutuma ombi: $error';
  }

  @override
  String get tellUsWhatYouNeedAnd =>
      'Tuambie unachohitaji nasi tutakutumia bei.';

  @override
  String get whatDoYouNeed => 'Unahitaji nini?';

  @override
  String get eG200EmbroideredPoloShirts =>
      'mf. shati 200 za polo zilizoshonwa nembo';

  @override
  String get describeTheItem => 'Eleza bidhaa';

  @override
  String get details => 'Maelezo';

  @override
  String get logoPlacementColoursSizesDeadlineDelivery =>
      'Mahali pa nembo, rangi, saizi, tarehe ya mwisho, mahali pa kufikisha…';

  @override
  String get sendRequest => 'Tuma ombi';

  @override
  String get accountDiscount2 => 'Punguzo la akaunti';

  @override
  String delivery2(Object deliveryZoneName) {
    return 'Usafirishaji ($deliveryZoneName)';
  }

  @override
  String get storePickup => 'Kuchukua dukani';

  @override
  String includesVat2(Object vatPercent) {
    return 'Inajumuisha VAT ($vatPercent%)';
  }

  @override
  String vat2(Object vatPercent) {
    return 'VAT ($vatPercent%)';
  }

  @override
  String get paid => 'Imelipwa';

  @override
  String get refunded => 'Imerejeshwa';

  @override
  String get cancellationFeeKept => 'Ada ya kughairi iliyobakizwa';

  @override
  String get balanceDue => 'Salio linalodaiwa';

  @override
  String get depositReceivedProductionCanStart =>
      'Amana imepokelewa — uzalishaji unaweza kuanza.';

  @override
  String depositOfDueBeforeProductionStarts(Object amount) {
    return 'Amana ya $amount inahitajika kabla uzalishaji haujaanza.';
  }

  @override
  String get couldntOpenThePaymentPage =>
      'Imeshindwa kufungua ukurasa wa malipo.';

  @override
  String get onlinePaymentIsntAvailableYetWell =>
      'Malipo ya mtandaoni bado hayapatikani. Tutakutumia ankara yenye maelezo ya malipo.';

  @override
  String deposit2(Object amount) {
    return 'Amana $amount';
  }

  @override
  String full(Object amount) {
    return 'Kamili $amount';
  }

  @override
  String get mPesaPhoneNumber => 'Namba ya simu ya M-Pesa';

  @override
  String get testModeNoRealMoneyWill =>
      'Hali ya majaribio — hakuna pesa halisi itakayotozwa.';

  @override
  String ref(Object receipt) {
    return 'Kumb: $receipt';
  }

  @override
  String charged(Object chargedCurrency, Object chargedAmount) {
    return 'Imetozwa $chargedCurrency $chargedAmount';
  }

  @override
  String get checkStatus => 'Angalia hali';

  @override
  String get checkYourPhone => 'Angalia simu yako';

  @override
  String get paymentReceived => 'Malipo yamepokelewa';

  @override
  String get paymentFailed => 'Malipo yameshindwa';

  @override
  String get paymentCancelled => 'Malipo yameghairiwa';

  @override
  String amount(Object message, Object amount) {
    return '$message\n\nKiasi: $amount';
  }

  @override
  String get thePaymentDidNotGoThrough => 'Malipo hayakufanikiwa.';

  @override
  String get ivePaidCheck => 'Nimelipa — angalia';

  @override
  String get done => 'Imekamilika';

  @override
  String getYourCustomBrandingFromUse(
    Object context,
    Object code,
    Object referralBonusPoints,
    Object base,
  ) {
    return 'Pata bidhaa zako zenye nembo kutoka $context! Tumia msimbo wangu $code unapojisajili na sote tutapata pointi $referralBonusPoints baada ya oda yako ya kwanza. $base';
  }

  @override
  String get enterAFriendsCode => 'Weka msimbo wa rafiki';

  @override
  String get onlyBeforeYourFirstOrder => 'Kabla ya oda yako ya kwanza tu.';

  @override
  String get codeAppliedYoullBothGetBonus =>
      'Msimbo umetumika — nyote mtapata pointi za ziada baada ya oda yako ya kwanza.';

  @override
  String pts(Object points) {
    return 'Pointi $points';
  }

  @override
  String worthOffYouEarnPointS(Object amount, Object pointsPerHundred) {
    return 'Zina thamani ya punguzo la $amount. Unapata pointi $pointsPerHundred kwa kila KES 100 unayotumia.';
  }

  @override
  String referAFriendPtsEach(Object referralBonusPoints) {
    return 'Mwalike rafiki (+pointi $referralBonusPoints kila mmoja)';
  }

  @override
  String get iHaveACode => 'Nina msimbo';

  @override
  String get copy => 'Nakili';

  @override
  String get copied => 'Imenakiliwa';

  @override
  String get share => 'Shiriki';

  @override
  String get thanksForYourReview => 'Asante kwa maoni yako';

  @override
  String get rateYourOrder => 'Kadiria oda yako';

  @override
  String get qualityFitDeliveryAnythingToShare =>
      'Ubora, ukubwa, ufikishaji… una la kushiriki?';

  @override
  String photos4(Object count) {
    return 'Picha ($count/4)';
  }

  @override
  String get reviewsAppearPubliclyAfterAQuick =>
      'Maoni huonekana hadharani baada ya ukaguzi mfupi.';

  @override
  String get submit => 'Wasilisha';

  @override
  String get reviews => 'Maoni';

  @override
  String get nothingSavedYet => 'Bado hakuna kilichohifadhiwa';

  @override
  String get tapTheHeartOnAnyItem =>
      'Gusa moyo kwenye bidhaa yoyote ili kuihifadhi kwa baadaye.';

  @override
  String get brandingWeveProducedForSchoolsCompanies =>
      'Kazi za nembo tulizotengeneza kwa shule, makampuni, hafla na timu.';

  @override
  String get comingSoon => 'Inakuja hivi karibuni';

  @override
  String get ourGalleryOfRecentJobsWill =>
      'Picha za kazi zetu za karibuni zitaonekana hapa.';

  @override
  String get portfolio => 'Kazi zetu';

  @override
  String get noReviewsYet => 'Bado hakuna maoni';

  @override
  String get customersAreAskedToReviewEach =>
      'Wateja huombwa kutoa maoni kwa kila oda iliyokamilika.';

  @override
  String reply(Object reply) {
    return 'Jibu: $reply';
  }

  @override
  String get publicReply => 'Jibu la hadharani';

  @override
  String get approvePublish => 'Idhinisha (chapisha)';

  @override
  String get hide => 'Ficha';

  @override
  String get replyPublicly => 'Jibu hadharani';

  @override
  String newPortfolioEntryPhotoS(Object count) {
    return 'Kazi mpya ya kuonyesha (picha $count)';
  }

  @override
  String get title => 'Kichwa';

  @override
  String get description => 'Maelezo';

  @override
  String get tagsCommaSeparated => 'Lebo (tenganisha kwa koma)';

  @override
  String get publish => 'Chapisha';

  @override
  String get addWork => 'Ongeza kazi';

  @override
  String get unfeature => 'Ondoa kwenye maalum';

  @override
  String get feature => 'Weka kuwa maalum';

  @override
  String get delete => 'Futa';

  @override
  String get dropAPinOnYourDelivery => 'Weka alama mahali pa kukuletea';

  @override
  String get useThisSpot => 'Tumia mahali hapa';

  @override
  String uniforms(Object company) {
    return 'Sare za $company';
  }

  @override
  String get approvedBrandedItemsForYourTeam =>
      'Bidhaa zenye nembo zilizoidhinishwa kwa timu yako — chagua saizi tu.';

  @override
  String get newCompany => 'Kampuni mpya';

  @override
  String get couldntLoadCompanies => 'Imeshindwa kupakia makampuni';

  @override
  String get noCompaniesYet => 'Bado hakuna makampuni';

  @override
  String get groupBuyersFromTheSameOrganisation =>
      'Unganisha wanunuzi wa shirika moja: punguzo moja, mkopo na mipango ya sare.';

  @override
  String buyerS(Object count) {
    return 'Wanunuzi $count';
  }

  @override
  String off(Object discountPercent) {
    return 'Punguzo $discountPercent%';
  }

  @override
  String get editCompanyBuyers => 'Hariri kampuni na wanunuzi';

  @override
  String get newUniformProgram => 'Mpango mpya wa sare';

  @override
  String edit2(Object existing) {
    return 'Hariri $existing';
  }

  @override
  String get companyName => 'Jina la kampuni';

  @override
  String get kraPinForInvoicesEtims => 'PIN ya KRA (kwa ankara / eTIMS)';

  @override
  String get discountForAllBuyers => 'Punguzo kwa wanunuzi wote (%)';

  @override
  String get creditTerms => 'Masharti ya mkopo';

  @override
  String get paymentTermsDays => 'Muda wa kulipa (siku)';

  @override
  String get companyCreditLimitKes0None =>
      'Kikomo cha mkopo cha kampuni (KES, 0 = hakuna)';

  @override
  String buyers(Object count) {
    return 'Wanunuzi ($count)';
  }

  @override
  String get findCustomersByNameOrEmail =>
      'Tafuta wateja kwa jina au barua pepe';

  @override
  String get editProgram => 'Hariri mpango';

  @override
  String get programName => 'Jina la mpango';

  @override
  String get eG2027StaffUniforms => 'mf. sare za wafanyakazi 2027';

  @override
  String get notesForBuyers => 'Maelezo kwa wanunuzi';

  @override
  String get active => 'Inatumika';

  @override
  String get itemsComeFromCustomisedOrdersThis =>
      'Bidhaa hutoka kwenye oda zilizobinafsishwa ambazo kampuni hii imeweka. Mnunuzi akiagiza bidhaa yenye nembo, inaweza kuongezwa hapa.';

  @override
  String from2(Object c, Object order) {
    return '$c (kutoka $order)';
  }

  @override
  String get addFromAPastOrder => 'Ongeza kutoka oda ya zamani';

  @override
  String get saved => 'Imehifadhiwa';

  @override
  String get loyaltyReferrals => 'Uaminifu na rufaa';

  @override
  String get loyaltyProgrammeOn => 'Mpango wa uaminifu umewashwa';

  @override
  String get pointsPerKes100Spent => 'Pointi kwa kila KES 100 inayotumika';

  @override
  String get kesValueOf1Point => 'Thamani ya pointi 1 kwa KES';

  @override
  String get referralBonusPointsEach => 'Zawadi ya rufaa (pointi kila mmoja)';

  @override
  String get maxOfAnOrderPaidWith =>
      'Asilimia ya juu ya oda kulipwa kwa pointi';

  @override
  String get displayCurrencies => 'Sarafu za kuonyesha';

  @override
  String get kesPer1UnitCustomersCan =>
      'KES kwa kipimo 1. Wateja wanaweza kuona bei za makadirio kwa sarafu hizi; malipo yote bado ni kwa KES.';

  @override
  String kesPer1(Object c) {
    return 'KES kwa $c 1';
  }

  @override
  String get saveLoyaltyCurrencies => 'Hifadhi uaminifu na sarafu';

  @override
  String get alsoShowPricesIn => 'Pia onyesha bei kwa';

  @override
  String get approximateOnlyYouPayInKes => 'Makadirio tu — unalipa kwa KES.';

  @override
  String get kesOnly => 'KES pekee';

  @override
  String get couldntLoadNotifications => 'Imeshindwa kupakia arifa';

  @override
  String unread(Object count) {
    return '$count hazijasomwa';
  }

  @override
  String get notificationSettings => 'Mipangilio ya arifa';

  @override
  String get orderUpdatesProofsPaymentsAndMessages =>
      'Taarifa za oda, sampuli, malipo na ujumbe zitaonekana hapa.';

  @override
  String get getAlertsOnThisDevice => 'Pokea arifa kwenye kifaa hiki';

  @override
  String get orderUpdatesAndMessagesEvenWhen =>
      'Taarifa za oda na ujumbe, hata programu ikiwa imefungwa.';

  @override
  String get alertsSwitchedOnForThisDevice =>
      'Arifa zimewashwa kwenye kifaa hiki';

  @override
  String get couldntSwitchOnAlertsCheckYour =>
      'Imeshindwa kuwasha arifa — angalia ruhusa ya arifa kwenye kivinjari/simu yako.';

  @override
  String get turnOn => 'Washa';

  @override
  String get howShouldWeReachYou => 'Tukufikie vipi?';

  @override
  String get theInAppInboxAlwaysGets =>
      'Kikasha cha ndani ya programu hupokea kila kitu.';

  @override
  String get pushNotifications => 'Arifa za simu';

  @override
  String get usesThePhoneNumberOnYour =>
      'Hutumia namba ya simu iliyo kwenye wasifu wako';

  @override
  String get remindersOffers => 'Vikumbusho na ofa';

  @override
  String get cartRemindersAndPromotions => 'Vikumbusho vya kikapu na ofa';

  @override
  String get notificationChannelsSaved => 'Njia za arifa zimehifadhiwa';

  @override
  String get testSentCheckYourInboxEmail =>
      'Jaribio limetumwa — angalia kikasha, barua pepe na WhatsApp.';

  @override
  String couldntLoadNotificationSettings(Object error) {
    return 'Imeshindwa kupakia mipangilio ya arifa: $error';
  }

  @override
  String get inAppAndPushNotificationsWork =>
      'Arifa za ndani ya programu na za simu zinafanya kazi tayari. Ongeza barua pepe na WhatsApp hapa chini; wateja huchagua njia zao kwenye kikasha chao.';

  @override
  String get emailProvider => 'Mtoa huduma wa barua pepe';

  @override
  String get fromAddress => 'Anwani ya mtumaji';

  @override
  String get mustBeASenderDomainVerified =>
      'Lazima iwe mtumaji/kikoa kilichothibitishwa na mtoa huduma.';

  @override
  String get apiKey => 'Ufunguo wa API';

  @override
  String get whatsappMetaCloudApi => 'WhatsApp (Meta Cloud API)';

  @override
  String get phoneNumberId => 'Kitambulisho cha namba ya simu';

  @override
  String get metaForDevelopersWhatsappApiSetup =>
      'Meta for Developers → WhatsApp → API Setup';

  @override
  String get permanentAccessToken => 'Tokeni ya kudumu ya ufikiaji';

  @override
  String get createASystemUserTokenWith =>
      'Tengeneza tokeni ya System User yenye whatsapp_business_messaging.';

  @override
  String get templateName => 'Jina la kiolezo';

  @override
  String get templateLanguageCode => 'Msimbo wa lugha wa kiolezo';

  @override
  String get sendMeATest => 'Nitumie jaribio';

  @override
  String get settings => 'Mipangilio';

  @override
  String get appearance => 'Mwonekano';

  @override
  String get theme => 'Mandhari';

  @override
  String get followYourDeviceOrLockIt =>
      'Fuata kifaa chako, au chagua mwanga au giza.';

  @override
  String get system => 'Mfumo';

  @override
  String get light => 'Mwanga';

  @override
  String get dark => 'Giza';

  @override
  String get font => 'Fonti';

  @override
  String get pickWhicheverReadsBestToYou =>
      'Chagua inayosomeka vizuri zaidi kwako — inatumika kila mahali, papo hapo.';

  @override
  String get accessibility => 'Ufikivu';

  @override
  String get textSize => 'Ukubwa wa maandishi';

  @override
  String get appliesAcrossTheWholeAppIndependent =>
      'Inatumika kwenye programu nzima, bila kujali ukubwa wa maandishi wa kifaa chako.';

  @override
  String get reduceMotion => 'Punguza mwendo';

  @override
  String get skipEntranceStaggerAnimationsOnLists =>
      'Ruka michoro ya kuingia kwenye orodha na gridi.';

  @override
  String get inAppNotifications => 'Arifa za ndani ya programu';

  @override
  String get showTheAnnouncementBannerOnHome =>
      'Onyesha matangazo kwenye ukurasa wa mwanzo. Hii haitumi arifa za simu.';

  @override
  String get languageCurrency => 'Lugha na sarafu';

  @override
  String get aboutSupport => 'Kuhusu na msaada';

  @override
  String get contactSupport => 'Wasiliana na msaada';

  @override
  String get getHelpWithAnOrderA =>
      'Pata msaada kuhusu oda, muundo au jambo lingine lolote.';

  @override
  String get loadingVersion => 'Inapakia toleo…';

  @override
  String version3(Object version, Object buildNumber) {
    return 'Toleo $version ($buildNumber)';
  }

  @override
  String get answer => 'Jibu';

  @override
  String get savedAnswerShownWhileOffline =>
      'Jibu lililohifadhiwa — linaonyeshwa ukiwa nje ya mtandao';

  @override
  String get gotIt => 'Nimeelewa';

  @override
  String get nothingHereYet => 'Bado hakuna kitu hapa';

  @override
  String get askAQuestionBelowAndThe =>
      'Uliza swali hapa chini na msaidizi atakusaidia.';

  @override
  String get tryADifferentSearchOrAsk =>
      'Jaribu utafutaji mwingine, au uliza hapa chini.';

  @override
  String get guide => 'Mwongozo';

  @override
  String get answersForWhatYouCanDo =>
      'Majibu kuhusu unachoweza kufanya hapa — tafuta hapa chini, au uliza swali lako.';

  @override
  String get searchQuestionsEGAssignOrder => 'Tafuta maswali, mf. \"kuagiza\"';

  @override
  String get couldntLoadTheGuide => 'Imeshindwa kupakia mwongozo';

  @override
  String get youreOfflineShowingSavedAnswersAsking =>
      'Uko nje ya mtandao — unaona majibu yaliyohifadhiwa. Kuuliza jambo jipya kunahitaji mtandao.';

  @override
  String get askSomethingElseNeedsInternet =>
      'Uliza jambo lingine — inahitaji intaneti';

  @override
  String get typeYourQuestion => 'Andika swali lako…';

  @override
  String get switchViewDeveloper => 'Badilisha mwonekano (Msanidi)';

  @override
  String get signOut => 'Toka';

  @override
  String get createAnAccountToContinue => 'Fungua akaunti ili kuendelea';

  @override
  String get signInOrCreateAccount => 'Ingia au fungua akaunti';

  @override
  String get orderStatusCancelled => 'Hali ya oda: imeghairiwa';

  @override
  String orderStatusStepOf(Object context, Object currentIndex, Object count) {
    return 'Hali ya oda: $context, hatua $currentIndex kati ya $count';
  }

  @override
  String couldntUploadPhoto(Object error) {
    return 'Imeshindwa kupakia picha: $error';
  }

  @override
  String get profileUpdated => 'Wasifu umesasishwa';

  @override
  String couldntSave(Object error) {
    return 'Imeshindwa kuhifadhi: $error';
  }

  @override
  String get couldntLoadYourProfile => 'Imeshindwa kupakia wasifu wako';

  @override
  String get noProfileFound => 'Wasifu haukupatikana';

  @override
  String get signInAgainToLoadYour =>
      'Ingia tena ili kupakia maelezo ya akaunti yako.';

  @override
  String get yourAccountDetails => 'Maelezo ya akaunti yako.';

  @override
  String get displayName => 'Jina la kuonyesha';

  @override
  String get required => 'Inahitajika';

  @override
  String get phoneOptional => 'Simu (hiari)';

  @override
  String get vehiclePlateOptional => 'Namba ya gari (hiari)';

  @override
  String get availableForDeliveries => 'Ninapatikana kwa ufikishaji';

  @override
  String dailyWageDaySetByAdmin(Object amount) {
    return 'Mshahara wa siku: $amount/siku (umewekwa na Msimamizi)';
  }

  @override
  String get saveChanges => 'Hifadhi mabadiliko';

  @override
  String get security => 'Usalama';

  @override
  String get changePassword => 'Badilisha nenosiri';

  @override
  String get yourSavedLogosForBrandingOrders =>
      'Nembo zako zilizohifadhiwa kwa oda za nembo';

  @override
  String get passwordChanged => 'Nenosiri limebadilishwa';

  @override
  String get couldntChangePassword => 'Imeshindwa kubadilisha nenosiri';

  @override
  String get currentPassword => 'Nenosiri la sasa';

  @override
  String get newPassword => 'Nenosiri jipya';

  @override
  String locatingMoreStopS(Object count) {
    return 'Inatafuta vituo $count zaidi…';
  }

  @override
  String stops(Object count) {
    return 'Vituo ($count)';
  }

  @override
  String get pageNotFound => 'Ukurasa haukupatikana';

  @override
  String get thatLinkDoesntLeadAnywhereIn =>
      'Kiungo hicho hakielekei popote ndani ya BrightBrush.';

  @override
  String get goHome => 'Rudi mwanzo';

  @override
  String get noValidWhatsappNumberForThis =>
      'Hakuna namba sahihi ya WhatsApp kwa mtu huyu.';

  @override
  String get couldntOpenWhatsappOnThisDevice =>
      'Imeshindwa kufungua WhatsApp kwenye kifaa hiki.';

  @override
  String get auto => 'Otomatiki';

  @override
  String get browsingAsGuest => 'Unavinjari kama mgeni';

  @override
  String developerView(Object role) {
    return '$role · Mwonekano wa msanidi';
  }

  @override
  String invoiceNothingNow(Object account, Object days) {
    return 'Hakuna cha kulipa sasa — tutatuma ankara kwa $account, ya kulipwa ndani ya siku $days.';
  }

  @override
  String get yourAccount => 'akaunti yako';

  @override
  String volumePricing(Object tiers) {
    return 'Bei kwa wingi: $tiers';
  }

  @override
  String tierPcs(Object minQty, Object price) {
    return 'Vipande $minQty+ $price';
  }

  @override
  String piecesCount(Object quantity) {
    return 'Vipande $quantity';
  }

  @override
  String inclSetup(Object amount) {
    return ' · ikijumuisha maandalizi $amount';
  }

  @override
  String minimumPcs(Object moq) {
    return 'Kiwango cha chini vipande $moq';
  }

  @override
  String tierAt(Object minQty, Object price) {
    return '$minQty+ kwa $price';
  }

  @override
  String blanksLine(Object quantity, Object price, Object surcharges) {
    return 'Bidhaa tupu ($quantity × $price$surcharges)';
  }

  @override
  String get plusSizeSurcharges => ' + ada za saizi';

  @override
  String get digitized => 'Imeandaliwa kwa kushona';

  @override
  String stitchesSuffix(Object count) {
    return ' · mishono $count';
  }

  @override
  String threadsList(Object colours) {
    return 'nyuzi $colours';
  }

  @override
  String namesList(Object count, Object names) {
    return 'Majina ($count): $names';
  }

  @override
  String overdueWasDue(Object date) {
    return 'Imechelewa — ilipaswa kulipwa $date';
  }

  @override
  String onAccountDue(Object date) {
    return 'Kwa akaunti · inalipwa $date';
  }

  @override
  String thankYouReceived(Object amount, Object reference) {
    return 'Asante! $amount zimepokelewa$reference.';
  }

  @override
  String mpesaRefSuffix(Object receipt) {
    return ' (kumbukumbu ya M-Pesa $receipt)';
  }

  @override
  String photosCount(Object count) {
    return 'Picha $count';
  }

  @override
  String get featuredSuffix => ' · maalum';

  @override
  String memberSince(Object date) {
    return 'Mwanachama tangu $date';
  }
}
