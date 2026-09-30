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
}
