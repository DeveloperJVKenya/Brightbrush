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

  @override
  String get whatsappUs => 'WhatsApp us';

  @override
  String waOrderMessage(String orderNumber, String status) {
    return 'Hello BrightBrush, I\'m contacting you about my order $orderNumber (status: $status). ';
  }

  @override
  String waItemMessage(String item) {
    return 'Hello BrightBrush, I\'d like to ask about \"$item\". ';
  }

  @override
  String waQuoteMessage(String title) {
    return 'Hello BrightBrush, about my quote request \"$title\": ';
  }

  @override
  String get waSupportMessage => 'Hello BrightBrush, I need help with: ';

  @override
  String get workingHours => 'Working hours';

  @override
  String get homeSearchHint => 'Search caps, hoodies, bottles…';

  @override
  String get shopByCategory => 'Shop by category';

  @override
  String get seeAll => 'See all';

  @override
  String get sectionFeatured => 'Featured';

  @override
  String get sectionBulkDeals => 'Bulk deals';

  @override
  String get sectionTopRated => 'Top rated';

  @override
  String get sectionNewArrivals => 'New arrivals';

  @override
  String get sectionRecentlyViewed => 'Recently viewed';

  @override
  String get sectionBundles => 'Bundles & packages';

  @override
  String get sectionAllProducts => 'All products';

  @override
  String get sortLabel => 'Sort';

  @override
  String get filterLabel => 'Filter';

  @override
  String get sortRecommended => 'Recommended';

  @override
  String get sortPriceLow => 'Price: low to high';

  @override
  String get sortPriceHigh => 'Price: high to low';

  @override
  String get sortNewest => 'Newest';

  @override
  String get sortTopRated => 'Top rated';

  @override
  String get sortBulkSaving => 'Biggest bulk saving';

  @override
  String itemsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return '$_temp0';
  }

  @override
  String get clearAll => 'Clear all';

  @override
  String saveUpTo(int percent) {
    return 'Save up to $percent%';
  }

  @override
  String get badgeNew => 'New';

  @override
  String get badgeFeatured => 'Featured';

  @override
  String get badgeCustomisable => 'Add your logo';

  @override
  String endsIn(String time) {
    return 'Ends in $time';
  }

  @override
  String get recentSearches => 'Recent searches';

  @override
  String searchFor(String query) {
    return 'Search for \"$query\"';
  }

  @override
  String get backToTop => 'Back to top';

  @override
  String get customiseCtaTitle => 'Put your logo on anything';

  @override
  String get customiseCtaBody =>
      'Upload your artwork, preview it live and approve a proof before we stitch.';

  @override
  String get customiseCtaAction => 'Start designing';

  @override
  String get bulkQuoteTitle => 'Ordering 100+ pieces?';

  @override
  String get bulkQuoteBody =>
      'Get a tailored quote for schools, teams, events and companies.';

  @override
  String get bulkQuoteAction => 'Request a quote';

  @override
  String get trackOrderTitle => 'Track your order';

  @override
  String get trackOrderBody => 'See every step from proof to delivery.';

  @override
  String trustFreeDelivery(String amount) {
    return 'Free delivery over $amount';
  }

  @override
  String get trustPayments => 'Pay with M-Pesa or card';

  @override
  String get trustProof => 'Approve a proof first';

  @override
  String get trustBulk => 'Cheaper in bulk';

  @override
  String get filterPrice => 'Price (KES)';

  @override
  String get filterCustomisable => 'Can add my logo';

  @override
  String get filterRating => 'Rated 4★ and up';

  @override
  String get filterLeadTime => 'Ready within';

  @override
  String get filterCategory => 'Category';

  @override
  String daysCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String get anyTime => 'Any time';

  @override
  String get allCategories => 'All';

  @override
  String showResults(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Show $count items',
      one: 'Show 1 item',
      zero: 'No items',
    );
    return '$_temp0';
  }

  @override
  String get noMatchesTitle => 'No matching items';

  @override
  String get noMatchesBody => 'Try another word or clear the filters.';

  @override
  String get askAi => 'Ask AI';

  @override
  String minOrderShort(int moq, int days) {
    return 'Min $moq · ${days}d';
  }

  @override
  String fromPrice(String price) {
    return 'From $price';
  }

  @override
  String get gridView => 'Grid view';

  @override
  String get listView => 'List view';

  @override
  String get catalogEmptyTitle => 'No items in the catalog yet';

  @override
  String get catalogEmptyBody =>
      'New branding items will appear here as soon as they are added.';

  @override
  String get couldNotLoadCatalog => 'Couldn\'t load the catalog';

  @override
  String get retry => 'Retry';

  @override
  String addedToCart(String item, int qty) {
    return '$item added to cart ($qty)';
  }

  @override
  String cartCount(int count) {
    return 'Cart · $count';
  }

  @override
  String ratingCount(int count) {
    return '($count)';
  }
}
