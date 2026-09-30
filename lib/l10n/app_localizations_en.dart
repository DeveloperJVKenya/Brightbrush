// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get navHome => 'Home';

  @override
  String get navPackages => 'Packages';

  @override
  String get navPortfolio => 'Our work';

  @override
  String get navOrders => 'My Orders';

  @override
  String get navTracking => 'Track Delivery';

  @override
  String get navCart => 'Cart & Checkout';

  @override
  String get navNotifications => 'Notifications';

  @override
  String get navSupport => 'Support';

  @override
  String get navProfile => 'Profile';

  @override
  String get statusPendingReview => 'Pending review';

  @override
  String get statusConfirmed => 'Confirmed';

  @override
  String get statusAwaitingProof => 'Proof for approval';

  @override
  String get statusInProduction => 'In production';

  @override
  String get statusQualityCheck => 'Quality check';

  @override
  String get statusReadyForDelivery => 'Ready for delivery';

  @override
  String get statusOutForDelivery => 'Out for delivery';

  @override
  String get statusCompleted => 'Completed';

  @override
  String get statusCancelled => 'Cancelled';

  @override
  String get addToCart => 'Add to cart';

  @override
  String get customiseAndOrder => 'Customise & order';

  @override
  String get requestQuote => 'Custom job or bulk price? Request a quote';

  @override
  String get placeOrder => 'Place order';

  @override
  String get deliveryDetails => 'Delivery details';

  @override
  String get contactName => 'Contact name';

  @override
  String get contactPhone => 'Contact phone';

  @override
  String get deliveryAddress => 'Delivery address';

  @override
  String get subtotal => 'Subtotal';

  @override
  String get total => 'Total';

  @override
  String get howToPay => 'How would you like to pay?';

  @override
  String get payInFull => 'Pay in full';

  @override
  String get promoCode => 'Promo code';

  @override
  String get apply => 'Apply';

  @override
  String get payment => 'Payment';

  @override
  String get payWith => 'Pay with';

  @override
  String payAmount(String amount) {
    return 'Pay $amount';
  }

  @override
  String get documents => 'Documents';

  @override
  String get history => 'History';

  @override
  String get items => 'Items';

  @override
  String get orderAgain => 'Order again';

  @override
  String get messageUs => 'Message us';

  @override
  String get cancelOrder => 'Cancel order';

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get markAllRead => 'Mark all read';

  @override
  String get noNotifications => 'No notifications yet';

  @override
  String get language => 'Language';

  @override
  String get deliveryCodeHint =>
      'Give this code to the driver when your order arrives — only then will they hand it over.';

  @override
  String get pickupCodeHint => 'Show this code when you collect your order.';

  @override
  String get rateOrderTitle => 'How did we do?';

  @override
  String get rateOrderSubtitle => 'Rate your order — it helps other customers.';

  @override
  String get review => 'Review';

  @override
  String get cartEmpty => 'Your cart is empty';

  @override
  String get wishlist => 'Wishlist';

  @override
  String get rewards => 'Rewards';
}
