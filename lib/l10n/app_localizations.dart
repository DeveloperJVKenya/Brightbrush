import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_sw.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('sw'),
  ];

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navPackages.
  ///
  /// In en, this message translates to:
  /// **'Packages'**
  String get navPackages;

  /// No description provided for @navPortfolio.
  ///
  /// In en, this message translates to:
  /// **'Our work'**
  String get navPortfolio;

  /// No description provided for @navOrders.
  ///
  /// In en, this message translates to:
  /// **'My Orders'**
  String get navOrders;

  /// No description provided for @navTracking.
  ///
  /// In en, this message translates to:
  /// **'Track Delivery'**
  String get navTracking;

  /// No description provided for @navCart.
  ///
  /// In en, this message translates to:
  /// **'Cart & Checkout'**
  String get navCart;

  /// No description provided for @navNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get navNotifications;

  /// No description provided for @navSupport.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get navSupport;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @statusPendingReview.
  ///
  /// In en, this message translates to:
  /// **'Pending review'**
  String get statusPendingReview;

  /// No description provided for @statusConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get statusConfirmed;

  /// No description provided for @statusAwaitingProof.
  ///
  /// In en, this message translates to:
  /// **'Proof for approval'**
  String get statusAwaitingProof;

  /// No description provided for @statusInProduction.
  ///
  /// In en, this message translates to:
  /// **'In production'**
  String get statusInProduction;

  /// No description provided for @statusQualityCheck.
  ///
  /// In en, this message translates to:
  /// **'Quality check'**
  String get statusQualityCheck;

  /// No description provided for @statusReadyForDelivery.
  ///
  /// In en, this message translates to:
  /// **'Ready for delivery'**
  String get statusReadyForDelivery;

  /// No description provided for @statusOutForDelivery.
  ///
  /// In en, this message translates to:
  /// **'Out for delivery'**
  String get statusOutForDelivery;

  /// No description provided for @statusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get statusCompleted;

  /// No description provided for @statusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get statusCancelled;

  /// No description provided for @addToCart.
  ///
  /// In en, this message translates to:
  /// **'Add to cart'**
  String get addToCart;

  /// No description provided for @customiseAndOrder.
  ///
  /// In en, this message translates to:
  /// **'Customise & order'**
  String get customiseAndOrder;

  /// No description provided for @requestQuote.
  ///
  /// In en, this message translates to:
  /// **'Custom job or bulk price? Request a quote'**
  String get requestQuote;

  /// No description provided for @placeOrder.
  ///
  /// In en, this message translates to:
  /// **'Place order'**
  String get placeOrder;

  /// No description provided for @deliveryDetails.
  ///
  /// In en, this message translates to:
  /// **'Delivery details'**
  String get deliveryDetails;

  /// No description provided for @contactName.
  ///
  /// In en, this message translates to:
  /// **'Contact name'**
  String get contactName;

  /// No description provided for @contactPhone.
  ///
  /// In en, this message translates to:
  /// **'Contact phone'**
  String get contactPhone;

  /// No description provided for @deliveryAddress.
  ///
  /// In en, this message translates to:
  /// **'Delivery address'**
  String get deliveryAddress;

  /// No description provided for @subtotal.
  ///
  /// In en, this message translates to:
  /// **'Subtotal'**
  String get subtotal;

  /// No description provided for @total.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get total;

  /// No description provided for @howToPay.
  ///
  /// In en, this message translates to:
  /// **'How would you like to pay?'**
  String get howToPay;

  /// No description provided for @payInFull.
  ///
  /// In en, this message translates to:
  /// **'Pay in full'**
  String get payInFull;

  /// No description provided for @promoCode.
  ///
  /// In en, this message translates to:
  /// **'Promo code'**
  String get promoCode;

  /// No description provided for @apply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// No description provided for @payment.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get payment;

  /// No description provided for @payWith.
  ///
  /// In en, this message translates to:
  /// **'Pay with'**
  String get payWith;

  /// No description provided for @payAmount.
  ///
  /// In en, this message translates to:
  /// **'Pay {amount}'**
  String payAmount(String amount);

  /// No description provided for @documents.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get documents;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @items.
  ///
  /// In en, this message translates to:
  /// **'Items'**
  String get items;

  /// No description provided for @orderAgain.
  ///
  /// In en, this message translates to:
  /// **'Order again'**
  String get orderAgain;

  /// No description provided for @messageUs.
  ///
  /// In en, this message translates to:
  /// **'Message us'**
  String get messageUs;

  /// No description provided for @cancelOrder.
  ///
  /// In en, this message translates to:
  /// **'Cancel order'**
  String get cancelOrder;

  /// No description provided for @notificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsTitle;

  /// No description provided for @markAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all read'**
  String get markAllRead;

  /// No description provided for @noNotifications.
  ///
  /// In en, this message translates to:
  /// **'No notifications yet'**
  String get noNotifications;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @deliveryCodeHint.
  ///
  /// In en, this message translates to:
  /// **'Give this code to the driver when your order arrives — only then will they hand it over.'**
  String get deliveryCodeHint;

  /// No description provided for @pickupCodeHint.
  ///
  /// In en, this message translates to:
  /// **'Show this code when you collect your order.'**
  String get pickupCodeHint;

  /// No description provided for @rateOrderTitle.
  ///
  /// In en, this message translates to:
  /// **'How did we do?'**
  String get rateOrderTitle;

  /// No description provided for @rateOrderSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Rate your order — it helps other customers.'**
  String get rateOrderSubtitle;

  /// No description provided for @review.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get review;

  /// No description provided for @cartEmpty.
  ///
  /// In en, this message translates to:
  /// **'Your cart is empty'**
  String get cartEmpty;

  /// No description provided for @wishlist.
  ///
  /// In en, this message translates to:
  /// **'Wishlist'**
  String get wishlist;

  /// No description provided for @rewards.
  ///
  /// In en, this message translates to:
  /// **'Rewards'**
  String get rewards;

  /// No description provided for @whatsappUs.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp us'**
  String get whatsappUs;

  /// No description provided for @waOrderMessage.
  ///
  /// In en, this message translates to:
  /// **'Hello BrightBrush, I\'m contacting you about my order {orderNumber} (status: {status}). '**
  String waOrderMessage(String orderNumber, String status);

  /// No description provided for @waItemMessage.
  ///
  /// In en, this message translates to:
  /// **'Hello BrightBrush, I\'d like to ask about \"{item}\". '**
  String waItemMessage(String item);

  /// No description provided for @waQuoteMessage.
  ///
  /// In en, this message translates to:
  /// **'Hello BrightBrush, about my quote request \"{title}\": '**
  String waQuoteMessage(String title);

  /// No description provided for @waSupportMessage.
  ///
  /// In en, this message translates to:
  /// **'Hello BrightBrush, I need help with: '**
  String get waSupportMessage;

  /// No description provided for @workingHours.
  ///
  /// In en, this message translates to:
  /// **'Working hours'**
  String get workingHours;

  /// No description provided for @homeSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search caps, hoodies, bottles…'**
  String get homeSearchHint;

  /// No description provided for @shopByCategory.
  ///
  /// In en, this message translates to:
  /// **'Shop by category'**
  String get shopByCategory;

  /// No description provided for @seeAll.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get seeAll;

  /// No description provided for @sectionFeatured.
  ///
  /// In en, this message translates to:
  /// **'Featured'**
  String get sectionFeatured;

  /// No description provided for @sectionBulkDeals.
  ///
  /// In en, this message translates to:
  /// **'Bulk deals'**
  String get sectionBulkDeals;

  /// No description provided for @sectionTopRated.
  ///
  /// In en, this message translates to:
  /// **'Top rated'**
  String get sectionTopRated;

  /// No description provided for @sectionNewArrivals.
  ///
  /// In en, this message translates to:
  /// **'New arrivals'**
  String get sectionNewArrivals;

  /// No description provided for @sectionRecentlyViewed.
  ///
  /// In en, this message translates to:
  /// **'Recently viewed'**
  String get sectionRecentlyViewed;

  /// No description provided for @sectionBundles.
  ///
  /// In en, this message translates to:
  /// **'Bundles & packages'**
  String get sectionBundles;

  /// No description provided for @sectionAllProducts.
  ///
  /// In en, this message translates to:
  /// **'All products'**
  String get sectionAllProducts;

  /// No description provided for @sortLabel.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get sortLabel;

  /// No description provided for @filterLabel.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get filterLabel;

  /// No description provided for @sortRecommended.
  ///
  /// In en, this message translates to:
  /// **'Recommended'**
  String get sortRecommended;

  /// No description provided for @sortPriceLow.
  ///
  /// In en, this message translates to:
  /// **'Price: low to high'**
  String get sortPriceLow;

  /// No description provided for @sortPriceHigh.
  ///
  /// In en, this message translates to:
  /// **'Price: high to low'**
  String get sortPriceHigh;

  /// No description provided for @sortNewest.
  ///
  /// In en, this message translates to:
  /// **'Newest'**
  String get sortNewest;

  /// No description provided for @sortTopRated.
  ///
  /// In en, this message translates to:
  /// **'Top rated'**
  String get sortTopRated;

  /// No description provided for @sortBulkSaving.
  ///
  /// In en, this message translates to:
  /// **'Biggest bulk saving'**
  String get sortBulkSaving;

  /// No description provided for @itemsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item} other{{count} items}}'**
  String itemsCount(int count);

  /// No description provided for @clearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear all'**
  String get clearAll;

  /// No description provided for @saveUpTo.
  ///
  /// In en, this message translates to:
  /// **'Save up to {percent}%'**
  String saveUpTo(int percent);

  /// No description provided for @badgeNew.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get badgeNew;

  /// No description provided for @badgeFeatured.
  ///
  /// In en, this message translates to:
  /// **'Featured'**
  String get badgeFeatured;

  /// No description provided for @badgeCustomisable.
  ///
  /// In en, this message translates to:
  /// **'Add your logo'**
  String get badgeCustomisable;

  /// No description provided for @endsIn.
  ///
  /// In en, this message translates to:
  /// **'Ends in {time}'**
  String endsIn(String time);

  /// No description provided for @recentSearches.
  ///
  /// In en, this message translates to:
  /// **'Recent searches'**
  String get recentSearches;

  /// No description provided for @searchFor.
  ///
  /// In en, this message translates to:
  /// **'Search for \"{query}\"'**
  String searchFor(String query);

  /// No description provided for @backToTop.
  ///
  /// In en, this message translates to:
  /// **'Back to top'**
  String get backToTop;

  /// No description provided for @customiseCtaTitle.
  ///
  /// In en, this message translates to:
  /// **'Put your logo on anything'**
  String get customiseCtaTitle;

  /// No description provided for @customiseCtaBody.
  ///
  /// In en, this message translates to:
  /// **'Upload your artwork, preview it live and approve a proof before we stitch.'**
  String get customiseCtaBody;

  /// No description provided for @customiseCtaAction.
  ///
  /// In en, this message translates to:
  /// **'Start designing'**
  String get customiseCtaAction;

  /// No description provided for @bulkQuoteTitle.
  ///
  /// In en, this message translates to:
  /// **'Ordering 100+ pieces?'**
  String get bulkQuoteTitle;

  /// No description provided for @bulkQuoteBody.
  ///
  /// In en, this message translates to:
  /// **'Get a tailored quote for schools, teams, events and companies.'**
  String get bulkQuoteBody;

  /// No description provided for @bulkQuoteAction.
  ///
  /// In en, this message translates to:
  /// **'Request a quote'**
  String get bulkQuoteAction;

  /// No description provided for @trackOrderTitle.
  ///
  /// In en, this message translates to:
  /// **'Track your order'**
  String get trackOrderTitle;

  /// No description provided for @trackOrderBody.
  ///
  /// In en, this message translates to:
  /// **'See every step from proof to delivery.'**
  String get trackOrderBody;

  /// No description provided for @trustFreeDelivery.
  ///
  /// In en, this message translates to:
  /// **'Free delivery over {amount}'**
  String trustFreeDelivery(String amount);

  /// No description provided for @trustPayments.
  ///
  /// In en, this message translates to:
  /// **'Pay with M-Pesa or card'**
  String get trustPayments;

  /// No description provided for @trustProof.
  ///
  /// In en, this message translates to:
  /// **'Approve a proof first'**
  String get trustProof;

  /// No description provided for @trustBulk.
  ///
  /// In en, this message translates to:
  /// **'Cheaper in bulk'**
  String get trustBulk;

  /// No description provided for @filterPrice.
  ///
  /// In en, this message translates to:
  /// **'Price (KES)'**
  String get filterPrice;

  /// No description provided for @filterCustomisable.
  ///
  /// In en, this message translates to:
  /// **'Can add my logo'**
  String get filterCustomisable;

  /// No description provided for @filterRating.
  ///
  /// In en, this message translates to:
  /// **'Rated 4★ and up'**
  String get filterRating;

  /// No description provided for @filterLeadTime.
  ///
  /// In en, this message translates to:
  /// **'Ready within'**
  String get filterLeadTime;

  /// No description provided for @filterCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get filterCategory;

  /// No description provided for @daysCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day} other{{count} days}}'**
  String daysCount(int count);

  /// No description provided for @anyTime.
  ///
  /// In en, this message translates to:
  /// **'Any time'**
  String get anyTime;

  /// No description provided for @allCategories.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get allCategories;

  /// No description provided for @showResults.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No items} =1{Show 1 item} other{Show {count} items}}'**
  String showResults(int count);

  /// No description provided for @noMatchesTitle.
  ///
  /// In en, this message translates to:
  /// **'No matching items'**
  String get noMatchesTitle;

  /// No description provided for @noMatchesBody.
  ///
  /// In en, this message translates to:
  /// **'Try another word or clear the filters.'**
  String get noMatchesBody;

  /// No description provided for @askAi.
  ///
  /// In en, this message translates to:
  /// **'Ask AI'**
  String get askAi;

  /// No description provided for @minOrderShort.
  ///
  /// In en, this message translates to:
  /// **'Min {moq} · {days}d'**
  String minOrderShort(int moq, int days);

  /// No description provided for @fromPrice.
  ///
  /// In en, this message translates to:
  /// **'From {price}'**
  String fromPrice(String price);

  /// No description provided for @gridView.
  ///
  /// In en, this message translates to:
  /// **'Grid view'**
  String get gridView;

  /// No description provided for @listView.
  ///
  /// In en, this message translates to:
  /// **'List view'**
  String get listView;

  /// No description provided for @catalogEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No items in the catalog yet'**
  String get catalogEmptyTitle;

  /// No description provided for @catalogEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'New branding items will appear here as soon as they are added.'**
  String get catalogEmptyBody;

  /// No description provided for @couldNotLoadCatalog.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the catalog'**
  String get couldNotLoadCatalog;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @addedToCart.
  ///
  /// In en, this message translates to:
  /// **'{item} added to cart ({qty})'**
  String addedToCart(String item, int qty);

  /// No description provided for @cartCount.
  ///
  /// In en, this message translates to:
  /// **'Cart · {count}'**
  String cartCount(int count);

  /// No description provided for @ratingCount.
  ///
  /// In en, this message translates to:
  /// **'({count})'**
  String ratingCount(int count);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'sw'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'sw':
      return AppLocalizationsSw();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
