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

  /// No description provided for @netOfflineTitle.
  ///
  /// In en, this message translates to:
  /// **'You\'re offline'**
  String get netOfflineTitle;

  /// No description provided for @netOfflineBody.
  ///
  /// In en, this message translates to:
  /// **'Showing what was saved on this device. Turn on Wi-Fi or mobile data to see updates and place orders.'**
  String get netOfflineBody;

  /// No description provided for @netOfflineNoInternetBody.
  ///
  /// In en, this message translates to:
  /// **'Connected, but the internet isn\'t reachable. Check your data bundle or switch to a better Wi-Fi. Showing saved data.'**
  String get netOfflineNoInternetBody;

  /// No description provided for @netWeakTitle.
  ///
  /// In en, this message translates to:
  /// **'Weak connection'**
  String get netWeakTitle;

  /// No description provided for @netWeakBody.
  ///
  /// In en, this message translates to:
  /// **'Things may load slowly. Move to a stronger signal or connect to Wi-Fi.'**
  String get netWeakBody;

  /// No description provided for @netBackOnline.
  ///
  /// In en, this message translates to:
  /// **'Back online'**
  String get netBackOnline;

  /// No description provided for @netOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get netOpenSettings;

  /// No description provided for @netDismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get netDismiss;

  /// No description provided for @netActionNeedsInternet.
  ///
  /// In en, this message translates to:
  /// **'You\'re offline. Connect to the internet and try again.'**
  String get netActionNeedsInternet;

  /// No description provided for @netSavedCopyTag.
  ///
  /// In en, this message translates to:
  /// **'Saved copy'**
  String get netSavedCopyTag;

  /// No description provided for @errNetwork.
  ///
  /// In en, this message translates to:
  /// **'Please check your internet connection and try again.'**
  String get errNetwork;

  /// No description provided for @errPermission.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have permission to do this. Contact an admin if you think this is a mistake.'**
  String get errPermission;

  /// No description provided for @errAssistant.
  ///
  /// In en, this message translates to:
  /// **'The assistant is temporarily unavailable right now. Please try again shortly.'**
  String get errAssistant;

  /// No description provided for @errSlow.
  ///
  /// In en, this message translates to:
  /// **'That\'s taking longer than expected. Please try again.'**
  String get errSlow;

  /// No description provided for @errNotFound.
  ///
  /// In en, this message translates to:
  /// **'That couldn\'t be found — it may have been removed.'**
  String get errNotFound;

  /// No description provided for @errGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get errGeneric;

  /// No description provided for @couldntLoadYourCart.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your cart'**
  String get couldntLoadYourCart;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get loading;

  /// No description provided for @addItemsOrSeasonalPackagesFrom.
  ///
  /// In en, this message translates to:
  /// **'Add items or seasonal packages from the catalog to start an order.'**
  String get addItemsOrSeasonalPackagesFrom;

  /// No description provided for @packageNoLongerAvailable.
  ///
  /// In en, this message translates to:
  /// **'Package no longer available'**
  String get packageNoLongerAvailable;

  /// No description provided for @itemNoLongerAvailable.
  ///
  /// In en, this message translates to:
  /// **'Item no longer available'**
  String get itemNoLongerAvailable;

  /// No description provided for @removeTheItemsThatAreNo.
  ///
  /// In en, this message translates to:
  /// **'Remove the items that are no longer available to continue.'**
  String get removeTheItemsThatAreNo;

  /// No description provided for @tapEditToFixIt.
  ///
  /// In en, this message translates to:
  /// **'\"{invalid}\": {problem} Tap edit to fix it.'**
  String tapEditToFixIt(Object invalid, Object problem);

  /// No description provided for @hasAMinimumOrderOf.
  ///
  /// In en, this message translates to:
  /// **'\"{below}\" has a minimum order of {minQuantity}.'**
  String hasAMinimumOrderOf(Object below, Object minQuantity);

  /// No description provided for @orderPlacedYouCanPayFor.
  ///
  /// In en, this message translates to:
  /// **'Order placed — you can pay for it right here.'**
  String get orderPlacedYouCanPayFor;

  /// No description provided for @couldntPlaceOrder.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t place order: {error}'**
  String couldntPlaceOrder(Object error);

  /// No description provided for @chooseYourDeliveryArea.
  ///
  /// In en, this message translates to:
  /// **'Choose your delivery area.'**
  String get chooseYourDeliveryArea;

  /// No description provided for @pcs.
  ///
  /// In en, this message translates to:
  /// **'{quantity} pcs · {amount}'**
  String pcs(Object quantity, Object amount);

  /// No description provided for @package.
  ///
  /// In en, this message translates to:
  /// **'Package'**
  String get package;

  /// No description provided for @min.
  ///
  /// In en, this message translates to:
  /// **'min {minQuantity}'**
  String min(Object minQuantity);

  /// No description provided for @removeThisToContinue.
  ///
  /// In en, this message translates to:
  /// **'Remove this to continue'**
  String get removeThisToContinue;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @deliverToMe.
  ///
  /// In en, this message translates to:
  /// **'Deliver to me'**
  String get deliverToMe;

  /// No description provided for @illPickUp.
  ///
  /// In en, this message translates to:
  /// **'I\'ll pick up'**
  String get illPickUp;

  /// No description provided for @pickUpAt.
  ///
  /// In en, this message translates to:
  /// **'Pick up at: {pickupAddress}'**
  String pickUpAt(Object pickupAddress);

  /// No description provided for @deliveryArea.
  ///
  /// In en, this message translates to:
  /// **'Delivery area'**
  String get deliveryArea;

  /// No description provided for @enterYourName.
  ///
  /// In en, this message translates to:
  /// **'Enter your name'**
  String get enterYourName;

  /// No description provided for @enterAPhoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter a phone number'**
  String get enterAPhoneNumber;

  /// No description provided for @dropAPinForTheDriver.
  ///
  /// In en, this message translates to:
  /// **'Drop a pin for the driver (optional)'**
  String get dropAPinForTheDriver;

  /// No description provided for @pinSetTapToAdjust.
  ///
  /// In en, this message translates to:
  /// **'Pin set — tap to adjust'**
  String get pinSetTapToAdjust;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @enterADeliveryAddress.
  ///
  /// In en, this message translates to:
  /// **'Enter a delivery address'**
  String get enterADeliveryAddress;

  /// No description provided for @notesArtworkDetailsColoursSizes.
  ///
  /// In en, this message translates to:
  /// **'Notes (artwork details, colours, sizes...)'**
  String get notesArtworkDetailsColoursSizes;

  /// No description provided for @cartChangedApplyAgain.
  ///
  /// In en, this message translates to:
  /// **'Cart changed — apply again'**
  String get cartChangedApplyAgain;

  /// No description provided for @codeApplied.
  ///
  /// In en, this message translates to:
  /// **'Code applied'**
  String get codeApplied;

  /// No description provided for @accountDiscount.
  ///
  /// In en, this message translates to:
  /// **'Account discount ({discountPercent}%)'**
  String accountDiscount(Object discountPercent);

  /// No description provided for @useMyPointsAvailable.
  ///
  /// In en, this message translates to:
  /// **'Use my points ({myPoints} available)'**
  String useMyPointsAvailable(Object myPoints);

  /// No description provided for @upToOfTheOrder.
  ///
  /// In en, this message translates to:
  /// **'Up to {maxRedeemPercent}% of the order'**
  String upToOfTheOrder(Object maxRedeemPercent);

  /// No description provided for @points.
  ///
  /// In en, this message translates to:
  /// **'Points ({points})'**
  String points(Object points);

  /// No description provided for @promo.
  ///
  /// In en, this message translates to:
  /// **'Promo {text}'**
  String promo(Object text);

  /// No description provided for @delivery.
  ///
  /// In en, this message translates to:
  /// **'Delivery'**
  String get delivery;

  /// No description provided for @deliveryFree.
  ///
  /// In en, this message translates to:
  /// **'Delivery (free)'**
  String get deliveryFree;

  /// No description provided for @includesVat.
  ///
  /// In en, this message translates to:
  /// **'Includes VAT ({taxRate}%)'**
  String includesVat(Object taxRate);

  /// No description provided for @vat.
  ///
  /// In en, this message translates to:
  /// **'VAT ({taxRate}%)'**
  String vat(Object taxRate);

  /// No description provided for @deposit.
  ///
  /// In en, this message translates to:
  /// **'{depositPercent}% deposit'**
  String deposit(Object depositPercent);

  /// No description provided for @onAccountD.
  ///
  /// In en, this message translates to:
  /// **'On account ({paymentTermsDays}d)'**
  String onAccountD(Object paymentTermsDays);

  /// No description provided for @payNowToStartProductionAnd.
  ///
  /// In en, this message translates to:
  /// **'Pay {amount} now to start production, and {amount2} before delivery.'**
  String payNowToStartProductionAnd(Object amount, Object amount2);

  /// No description provided for @youllChooseHowToPayM.
  ///
  /// In en, this message translates to:
  /// **'You\'ll choose how to pay (M-Pesa, card and more) on the next screen. Final prices are confirmed when the order is placed.'**
  String get youllChooseHowToPayM;

  /// No description provided for @decreaseQuantity.
  ///
  /// In en, this message translates to:
  /// **'Decrease quantity'**
  String get decreaseQuantity;

  /// No description provided for @increaseQuantity.
  ///
  /// In en, this message translates to:
  /// **'Increase quantity'**
  String get increaseQuantity;

  /// No description provided for @quantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get quantity;

  /// No description provided for @minimum.
  ///
  /// In en, this message translates to:
  /// **'Minimum {minQuantity}'**
  String minimum(Object minQuantity);

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @set.
  ///
  /// In en, this message translates to:
  /// **'Set'**
  String get set;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @itemDetails.
  ///
  /// In en, this message translates to:
  /// **'Item details'**
  String get itemDetails;

  /// No description provided for @failedToLoad.
  ///
  /// In en, this message translates to:
  /// **'Failed to load'**
  String get failedToLoad;

  /// No description provided for @itemNotFound.
  ///
  /// In en, this message translates to:
  /// **'Item not found'**
  String get itemNotFound;

  /// No description provided for @itMayHaveBeenRemovedOr.
  ///
  /// In en, this message translates to:
  /// **'It may have been removed or is no longer active.'**
  String get itMayHaveBeenRemovedOr;

  /// No description provided for @from.
  ///
  /// In en, this message translates to:
  /// **'From {amount}'**
  String from(Object amount);

  /// No description provided for @moq.
  ///
  /// In en, this message translates to:
  /// **'MOQ {moq}'**
  String moq(Object moq);

  /// No description provided for @dayLeadTime.
  ///
  /// In en, this message translates to:
  /// **'{leadTimeDays} day lead time'**
  String dayLeadTime(Object leadTimeDays);

  /// No description provided for @noDescriptionProvidedYet.
  ///
  /// In en, this message translates to:
  /// **'No description provided yet.'**
  String get noDescriptionProvidedYet;

  /// No description provided for @signInOrCreateAnAccount.
  ///
  /// In en, this message translates to:
  /// **'Sign in or create an account to add \"{item}\" to your cart.'**
  String signInOrCreateAnAccount(Object item);

  /// No description provided for @addedMinimumOrder.
  ///
  /// In en, this message translates to:
  /// **'{item} added (minimum order {moq})'**
  String addedMinimumOrder(Object item, Object moq);

  /// No description provided for @couldntAddToCart.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t add to cart: {error}'**
  String couldntAddToCart(Object error);

  /// No description provided for @ticketSentWellGetBackTo.
  ///
  /// In en, this message translates to:
  /// **'Ticket sent — we\'ll get back to you here.'**
  String get ticketSentWellGetBackTo;

  /// No description provided for @couldntSend.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send: {error}'**
  String couldntSend(Object error);

  /// No description provided for @tellUsAboutAnOrderA.
  ///
  /// In en, this message translates to:
  /// **'Tell us about an order, a design, or a complaint.'**
  String get tellUsAboutAnOrderA;

  /// No description provided for @subject.
  ///
  /// In en, this message translates to:
  /// **'Subject'**
  String get subject;

  /// No description provided for @enterASubject.
  ///
  /// In en, this message translates to:
  /// **'Enter a subject'**
  String get enterASubject;

  /// No description provided for @message.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get message;

  /// No description provided for @enterAMessage.
  ///
  /// In en, this message translates to:
  /// **'Enter a message'**
  String get enterAMessage;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @yourTickets.
  ///
  /// In en, this message translates to:
  /// **'Your tickets'**
  String get yourTickets;

  /// No description provided for @couldntLoadTickets.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load tickets'**
  String get couldntLoadTickets;

  /// No description provided for @noTicketsYet.
  ///
  /// In en, this message translates to:
  /// **'No tickets yet'**
  String get noTicketsYet;

  /// No description provided for @anythingYouSendAboveWillShow.
  ///
  /// In en, this message translates to:
  /// **'Anything you send above will show up here with our reply.'**
  String get anythingYouSendAboveWillShow;

  /// No description provided for @couldntLoadYourOrders.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your orders'**
  String get couldntLoadYourOrders;

  /// No description provided for @nothingOutForDelivery.
  ///
  /// In en, this message translates to:
  /// **'Nothing out for delivery'**
  String get nothingOutForDelivery;

  /// No description provided for @onceAnOrderIsOutFor.
  ///
  /// In en, this message translates to:
  /// **'Once an order is out for delivery, track it live here.'**
  String get onceAnOrderIsOutFor;

  /// No description provided for @myOrders.
  ///
  /// In en, this message translates to:
  /// **'My orders'**
  String get myOrders;

  /// No description provided for @myQuotes.
  ///
  /// In en, this message translates to:
  /// **'My quotes'**
  String get myQuotes;

  /// No description provided for @everyOrderYouvePlacedWithLive.
  ///
  /// In en, this message translates to:
  /// **'Every order you\'ve placed, with live status as it moves through production.'**
  String get everyOrderYouvePlacedWithLive;

  /// No description provided for @searchYourOrders.
  ///
  /// In en, this message translates to:
  /// **'Search your orders'**
  String get searchYourOrders;

  /// No description provided for @couldntLoadOrders.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load orders'**
  String get couldntLoadOrders;

  /// No description provided for @noOrdersYet.
  ///
  /// In en, this message translates to:
  /// **'No orders yet'**
  String get noOrdersYet;

  /// No description provided for @noMatches.
  ///
  /// In en, this message translates to:
  /// **'No matches'**
  String get noMatches;

  /// No description provided for @ordersYouPlaceFromTheCatalog.
  ///
  /// In en, this message translates to:
  /// **'Orders you place from the catalog will show up here with live status.'**
  String get ordersYouPlaceFromTheCatalog;

  /// No description provided for @tryADifferentSearchTerm.
  ///
  /// In en, this message translates to:
  /// **'Try a different search term.'**
  String get tryADifferentSearchTerm;

  /// No description provided for @orderDetails.
  ///
  /// In en, this message translates to:
  /// **'Order details'**
  String get orderDetails;

  /// No description provided for @orderNotFound.
  ///
  /// In en, this message translates to:
  /// **'Order not found'**
  String get orderNotFound;

  /// No description provided for @itMayHaveBeenRemoved.
  ///
  /// In en, this message translates to:
  /// **'It may have been removed.'**
  String get itMayHaveBeenRemoved;

  /// No description provided for @paymentReceivedThankYou.
  ///
  /// In en, this message translates to:
  /// **'Payment received — thank you!'**
  String get paymentReceivedThankYou;

  /// No description provided for @confirmingYourPaymentWithTheProvider.
  ///
  /// In en, this message translates to:
  /// **'Confirming your payment with the provider… this page updates automatically.'**
  String get confirmingYourPaymentWithTheProvider;

  /// No description provided for @paymentCancelledYouCanTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Payment cancelled. You can try again below.'**
  String get paymentCancelledYouCanTryAgain;

  /// No description provided for @thePaymentDidntGoThroughYou.
  ///
  /// In en, this message translates to:
  /// **'The payment didn\'t go through. You can try again below.'**
  String get thePaymentDidntGoThroughYou;

  /// No description provided for @nothingToReorderQuotedItemsNeed.
  ///
  /// In en, this message translates to:
  /// **'Nothing to reorder — quoted items need a new quote.'**
  String get nothingToReorderQuotedItemsNeed;

  /// No description provided for @addedItemSToYourCart.
  ///
  /// In en, this message translates to:
  /// **'Added {added} item(s) to your cart. Prices are updated at checkout.'**
  String addedItemSToYourCart(Object added);

  /// No description provided for @cancelThisOrder.
  ///
  /// In en, this message translates to:
  /// **'Cancel this order?'**
  String get cancelThisOrder;

  /// No description provided for @thisCantBeUndone.
  ///
  /// In en, this message translates to:
  /// **'This can\'t be undone.'**
  String get thisCantBeUndone;

  /// No description provided for @keepOrder.
  ///
  /// In en, this message translates to:
  /// **'Keep order'**
  String get keepOrder;

  /// No description provided for @couldntCancel.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t cancel: {error}'**
  String couldntCancel(Object error);

  /// No description provided for @thisPackageDoesntListSpecificCatalog.
  ///
  /// In en, this message translates to:
  /// **'This package doesn\'t list specific catalog items yet.'**
  String get thisPackageDoesntListSpecificCatalog;

  /// No description provided for @includesCatalogItemS.
  ///
  /// In en, this message translates to:
  /// **'Includes {count} catalog item(s).'**
  String includesCatalogItemS(Object count);

  /// No description provided for @signInOrCreateAnAccount2.
  ///
  /// In en, this message translates to:
  /// **'Sign in or create an account to order \"{package}\".'**
  String signInOrCreateAnAccount2(Object package);

  /// No description provided for @addedToCart2.
  ///
  /// In en, this message translates to:
  /// **'\"{package}\" added to cart'**
  String addedToCart2(Object package);

  /// No description provided for @customiseItRequestAQuote.
  ///
  /// In en, this message translates to:
  /// **'Customise it — request a quote'**
  String get customiseItRequestAQuote;

  /// No description provided for @seasonalPackages.
  ///
  /// In en, this message translates to:
  /// **'Seasonal packages'**
  String get seasonalPackages;

  /// No description provided for @curatedBundlesForCampaignsAndSeasons.
  ///
  /// In en, this message translates to:
  /// **'Curated bundles for campaigns and seasons — Valentine\'s, elections, and more.'**
  String get curatedBundlesForCampaignsAndSeasons;

  /// No description provided for @searchPackagesEGValentines.
  ///
  /// In en, this message translates to:
  /// **'Search packages, e.g. \"valentines\"'**
  String get searchPackagesEGValentines;

  /// No description provided for @couldntLoadPackages.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load packages'**
  String get couldntLoadPackages;

  /// No description provided for @noPackagesYet.
  ///
  /// In en, this message translates to:
  /// **'No packages yet'**
  String get noPackagesYet;

  /// No description provided for @seasonalPackagesSetUpByThe.
  ///
  /// In en, this message translates to:
  /// **'Seasonal packages set up by the System Manager will appear here live.'**
  String get seasonalPackagesSetUpByThe;

  /// No description provided for @filtersUpdated.
  ///
  /// In en, this message translates to:
  /// **'Filters updated.'**
  String get filtersUpdated;

  /// No description provided for @couldntReachTheAiAssistant.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reach the AI assistant: {error}'**
  String couldntReachTheAiAssistant(Object error);

  /// No description provided for @askWhatYouNeed.
  ///
  /// In en, this message translates to:
  /// **'Ask what you need'**
  String get askWhatYouNeed;

  /// No description provided for @describeTheOccasionOrItemIn.
  ///
  /// In en, this message translates to:
  /// **'Describe the occasion or item in your own words — e.g. \"something for a corporate summer picnic, 60 people\" — and we\'ll set the right filters.'**
  String get describeTheOccasionOrItemIn;

  /// No description provided for @whatAreYouBrandingAndFor.
  ///
  /// In en, this message translates to:
  /// **'What are you branding, and for what?'**
  String get whatAreYouBrandingAndFor;

  /// No description provided for @ask.
  ///
  /// In en, this message translates to:
  /// **'Ask'**
  String get ask;

  /// No description provided for @order.
  ///
  /// In en, this message translates to:
  /// **'Order {displayNumber}'**
  String order(Object displayNumber);

  /// No description provided for @itemS.
  ///
  /// In en, this message translates to:
  /// **'{itemCount} item(s) · {amount}'**
  String itemS(Object itemCount, Object amount);

  /// No description provided for @backToHome.
  ///
  /// In en, this message translates to:
  /// **'Back to home'**
  String get backToHome;

  /// No description provided for @starsFromReviews.
  ///
  /// In en, this message translates to:
  /// **'{avg} stars from {count} reviews'**
  String starsFromReviews(Object avg, Object count);

  /// No description provided for @removeFromWishlist.
  ///
  /// In en, this message translates to:
  /// **'Remove from wishlist'**
  String get removeFromWishlist;

  /// No description provided for @saveToWishlist.
  ///
  /// In en, this message translates to:
  /// **'Save to wishlist'**
  String get saveToWishlist;

  /// No description provided for @signInToSaveToYour.
  ///
  /// In en, this message translates to:
  /// **'Sign in to save \"{itemName}\" to your wishlist.'**
  String signInToSaveToYour(Object itemName);

  /// No description provided for @clearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get clearSearch;

  /// No description provided for @items2.
  ///
  /// In en, this message translates to:
  /// **'{category}, {count} items'**
  String items2(Object category, Object count);

  /// No description provided for @items3.
  ///
  /// In en, this message translates to:
  /// **'{count} items · {amount}'**
  String items3(Object count, Object amount);

  /// No description provided for @oneSystemForOrdersProductionDelivery.
  ///
  /// In en, this message translates to:
  /// **'One system for orders, production, delivery and the numbers behind every cap, hoodie and campaign package.'**
  String get oneSystemForOrdersProductionDelivery;

  /// No description provided for @somethingWentWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong ({code}).'**
  String somethingWentWrong(Object code);

  /// No description provided for @enterYourEmailAboveFirstThen.
  ///
  /// In en, this message translates to:
  /// **'Enter your email above first, then tap \"Forgot password?\".'**
  String get enterYourEmailAboveFirstThen;

  /// No description provided for @ifAnAccountExistsForA.
  ///
  /// In en, this message translates to:
  /// **'If an account exists for {email}, a reset link is on its way. Check your inbox and spam folder.'**
  String ifAnAccountExistsForA(Object email);

  /// No description provided for @pleaseAcceptTheTermsAndPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Please accept the Terms and Privacy Policy to continue.'**
  String get pleaseAcceptTheTermsAndPrivacy;

  /// No description provided for @createYourAccount.
  ///
  /// In en, this message translates to:
  /// **'Create your account'**
  String get createYourAccount;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @accessYourBrightbrushCreationsWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Access your BrightBrush Creations workspace.'**
  String get accessYourBrightbrushCreationsWorkspace;

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get fullName;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @enterAValidEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email'**
  String get enterAValidEmail;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @atLeast6Characters.
  ///
  /// In en, this message translates to:
  /// **'At least 6 characters'**
  String get atLeast6Characters;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPassword;

  /// No description provided for @iAgreeToThe.
  ///
  /// In en, this message translates to:
  /// **'I agree to the '**
  String get iAgreeToThe;

  /// No description provided for @terms.
  ///
  /// In en, this message translates to:
  /// **'Terms'**
  String get terms;

  /// No description provided for @and.
  ///
  /// In en, this message translates to:
  /// **' and '**
  String get and;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get createAccount;

  /// No description provided for @alreadyHaveAnAccountSignIn.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Sign in'**
  String get alreadyHaveAnAccountSignIn;

  /// No description provided for @dontHaveAnAccountSignUp.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? Sign up'**
  String get dontHaveAnAccountSignUp;

  /// No description provided for @signingUpHereAlwaysCreatesA.
  ///
  /// In en, this message translates to:
  /// **'Signing up here always creates a plain User account. Every other role is assigned afterward by an Admin/CEO or Developer.'**
  String get signingUpHereAlwaysCreatesA;

  /// No description provided for @verificationEmailSentTo.
  ///
  /// In en, this message translates to:
  /// **'Verification email sent to {email}.'**
  String verificationEmailSentTo(Object email);

  /// No description provided for @emailVerifiedThankYou.
  ///
  /// In en, this message translates to:
  /// **'Email verified — thank you!'**
  String get emailVerifiedThankYou;

  /// No description provided for @notVerifiedYetCheckYourInbox.
  ///
  /// In en, this message translates to:
  /// **'Not verified yet. Check your inbox (and spam folder).'**
  String get notVerifiedYetCheckYourInbox;

  /// No description provided for @verifyYourEmailSoWeCan.
  ///
  /// In en, this message translates to:
  /// **'Verify your email ({email}) so we can send receipts and order updates.'**
  String verifyYourEmailSoWeCan(Object email);

  /// No description provided for @sendLink.
  ///
  /// In en, this message translates to:
  /// **'Send link'**
  String get sendLink;

  /// No description provided for @iveVerified.
  ///
  /// In en, this message translates to:
  /// **'I\'ve verified'**
  String get iveVerified;

  /// No description provided for @privacyPolicy2.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get privacyPolicy2;

  /// No description provided for @termsOfService.
  ///
  /// In en, this message translates to:
  /// **'Terms of service'**
  String get termsOfService;

  /// No description provided for @deleteMyAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete my account'**
  String get deleteMyAccount;

  /// No description provided for @permanentlyRemovesYourProfileCartAnd.
  ///
  /// In en, this message translates to:
  /// **'Permanently removes your profile, cart and quotes.'**
  String get permanentlyRemovesYourProfileCartAnd;

  /// No description provided for @thatPasswordIsIncorrect.
  ///
  /// In en, this message translates to:
  /// **'That password is incorrect.'**
  String get thatPasswordIsIncorrect;

  /// No description provided for @couldntConfirmYourIdentity.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t confirm your identity.'**
  String get couldntConfirmYourIdentity;

  /// No description provided for @deleteYourAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete your account?'**
  String get deleteYourAccount;

  /// No description provided for @thisPermanentlyDeletesYourLoginProfile.
  ///
  /// In en, this message translates to:
  /// **'This permanently deletes your login, profile, cart and quote requests. Past orders are kept anonymised for our tax records. You can\'t delete your account while an order is still in progress.'**
  String get thisPermanentlyDeletesYourLoginProfile;

  /// No description provided for @yourPassword.
  ///
  /// In en, this message translates to:
  /// **'Your password'**
  String get yourPassword;

  /// No description provided for @typeDeleteToConfirm.
  ///
  /// In en, this message translates to:
  /// **'Type DELETE to confirm'**
  String get typeDeleteToConfirm;

  /// No description provided for @keepMyAccount.
  ///
  /// In en, this message translates to:
  /// **'Keep my account'**
  String get keepMyAccount;

  /// No description provided for @deleteForever.
  ///
  /// In en, this message translates to:
  /// **'Delete forever'**
  String get deleteForever;

  /// No description provided for @chatWithCustomer.
  ///
  /// In en, this message translates to:
  /// **'Chat with customer'**
  String get chatWithCustomer;

  /// No description provided for @filesMustBeUnder10Mb.
  ///
  /// In en, this message translates to:
  /// **'Files must be under 10 MB.'**
  String get filesMustBeUnder10Mb;

  /// No description provided for @messages.
  ///
  /// In en, this message translates to:
  /// **'Messages · {orderLabel}'**
  String messages(Object orderLabel);

  /// No description provided for @noMessagesYet.
  ///
  /// In en, this message translates to:
  /// **'No messages yet.'**
  String get noMessagesYet;

  /// No description provided for @questionsAboutSizesPlacementOrDelivery.
  ///
  /// In en, this message translates to:
  /// **'Questions about sizes, placement or delivery? Send us a message.'**
  String get questionsAboutSizesPlacementOrDelivery;

  /// No description provided for @attachPhotoOrPdf.
  ///
  /// In en, this message translates to:
  /// **'Attach photo or PDF'**
  String get attachPhotoOrPdf;

  /// No description provided for @writeAMessage.
  ///
  /// In en, this message translates to:
  /// **'Write a message'**
  String get writeAMessage;

  /// No description provided for @customise.
  ///
  /// In en, this message translates to:
  /// **'Customise'**
  String get customise;

  /// No description provided for @customise2.
  ///
  /// In en, this message translates to:
  /// **'Customise {item}'**
  String customise2(Object item);

  /// No description provided for @itemNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Item not available'**
  String get itemNotAvailable;

  /// No description provided for @itMayHaveBeenRemovedFrom.
  ///
  /// In en, this message translates to:
  /// **'It may have been removed from the catalog.'**
  String get itMayHaveBeenRemovedFrom;

  /// No description provided for @notCustomisable.
  ///
  /// In en, this message translates to:
  /// **'Not customisable'**
  String get notCustomisable;

  /// No description provided for @thisItemIsSoldAsIs.
  ///
  /// In en, this message translates to:
  /// **'This item is sold as-is. Add it from its page.'**
  String get thisItemIsSoldAsIs;

  /// No description provided for @signInToUploadYourLogo.
  ///
  /// In en, this message translates to:
  /// **'Sign in to upload your logo and save it to your library.'**
  String get signInToUploadYourLogo;

  /// No description provided for @signInOrCreateAnAccount3.
  ///
  /// In en, this message translates to:
  /// **'Sign in or create an account to add this to your cart.'**
  String get signInOrCreateAnAccount3;

  /// No description provided for @cartUpdated.
  ///
  /// In en, this message translates to:
  /// **'Cart updated'**
  String get cartUpdated;

  /// No description provided for @addedToYourCart.
  ///
  /// In en, this message translates to:
  /// **'{item} added to your cart'**
  String addedToYourCart(Object item);

  /// No description provided for @colour.
  ///
  /// In en, this message translates to:
  /// **'Colour'**
  String get colour;

  /// No description provided for @pieces.
  ///
  /// In en, this message translates to:
  /// **'Pieces'**
  String get pieces;

  /// No description provided for @branding.
  ///
  /// In en, this message translates to:
  /// **'Branding'**
  String get branding;

  /// No description provided for @addALogoOrTextAt.
  ///
  /// In en, this message translates to:
  /// **'Add a logo or text at each placement'**
  String get addALogoOrTextAt;

  /// No description provided for @addAnotherPlacement.
  ///
  /// In en, this message translates to:
  /// **'Add another placement'**
  String get addAnotherPlacement;

  /// No description provided for @namesOptional.
  ///
  /// In en, this message translates to:
  /// **'Names (optional)'**
  String get namesOptional;

  /// No description provided for @onePerLineEGStaff.
  ///
  /// In en, this message translates to:
  /// **'One per line, e.g. staff names — {amount} per piece'**
  String onePerLineEGStaff(Object amount);

  /// No description provided for @pcsEach.
  ///
  /// In en, this message translates to:
  /// **'{quantity} pcs · {amount} each'**
  String pcsEach(Object quantity, Object amount);

  /// No description provided for @updateCart.
  ///
  /// In en, this message translates to:
  /// **'Update cart'**
  String get updateCart;

  /// No description provided for @removePlacement.
  ///
  /// In en, this message translates to:
  /// **'Remove placement'**
  String get removePlacement;

  /// No description provided for @uploadChooseLogo.
  ///
  /// In en, this message translates to:
  /// **'Upload / choose logo'**
  String get uploadChooseLogo;

  /// No description provided for @removeLogo.
  ///
  /// In en, this message translates to:
  /// **'Remove logo'**
  String get removeLogo;

  /// No description provided for @alreadyDigitizedNoDigitizingFee.
  ///
  /// In en, this message translates to:
  /// **'Already digitized — no digitizing fee.'**
  String get alreadyDigitizedNoDigitizingFee;

  /// No description provided for @orTextToPrintStitch.
  ///
  /// In en, this message translates to:
  /// **'Or text to print/stitch'**
  String get orTextToPrintStitch;

  /// No description provided for @extraTextOptional.
  ///
  /// In en, this message translates to:
  /// **'Extra text (optional)'**
  String get extraTextOptional;

  /// No description provided for @threadColoursCommaSeparated.
  ///
  /// In en, this message translates to:
  /// **'Thread colours (comma separated)'**
  String get threadColoursCommaSeparated;

  /// No description provided for @eGWhiteGold.
  ///
  /// In en, this message translates to:
  /// **'e.g. White, Gold'**
  String get eGWhiteGold;

  /// No description provided for @brandingPerPiece.
  ///
  /// In en, this message translates to:
  /// **'Branding ({amount} per piece)'**
  String brandingPerPiece(Object amount);

  /// No description provided for @oneOffSetupDigitizing.
  ///
  /// In en, this message translates to:
  /// **'One-off setup / digitizing'**
  String get oneOffSetupDigitizing;

  /// No description provided for @names.
  ///
  /// In en, this message translates to:
  /// **'Names'**
  String get names;

  /// No description provided for @itemTotal.
  ///
  /// In en, this message translates to:
  /// **'Item total'**
  String get itemTotal;

  /// No description provided for @deliveryAndVatAreAddedAt.
  ///
  /// In en, this message translates to:
  /// **'Delivery and VAT are added at checkout. You\'ll approve a digital proof before we produce anything.'**
  String get deliveryAndVatAreAddedAt;

  /// No description provided for @addedToYourLibrary.
  ///
  /// In en, this message translates to:
  /// **'\"{art}\" added to your library'**
  String addedToYourLibrary(Object art);

  /// No description provided for @uploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Upload failed: {error}'**
  String uploadFailed(Object error);

  /// No description provided for @notDigitizedYet.
  ///
  /// In en, this message translates to:
  /// **'Not digitized yet'**
  String get notDigitizedYet;

  /// No description provided for @rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// No description provided for @deleteFromLibrary.
  ///
  /// In en, this message translates to:
  /// **'Delete from library'**
  String get deleteFromLibrary;

  /// No description provided for @pastOrdersKeepTheirCopy.
  ///
  /// In en, this message translates to:
  /// **'Past orders keep their copy.'**
  String get pastOrdersKeepTheirCopy;

  /// No description provided for @renameArtwork.
  ///
  /// In en, this message translates to:
  /// **'Rename artwork'**
  String get renameArtwork;

  /// No description provided for @deleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted'**
  String get deleted;

  /// No description provided for @myArtwork.
  ///
  /// In en, this message translates to:
  /// **'My artwork'**
  String get myArtwork;

  /// No description provided for @uploadLogo.
  ///
  /// In en, this message translates to:
  /// **'Upload logo'**
  String get uploadLogo;

  /// No description provided for @couldntLoadYourArtwork.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your artwork'**
  String get couldntLoadYourArtwork;

  /// No description provided for @noArtworkYet.
  ///
  /// In en, this message translates to:
  /// **'No artwork yet'**
  String get noArtworkYet;

  /// No description provided for @uploadYourLogoOnceAndReuse.
  ///
  /// In en, this message translates to:
  /// **'Upload your logo once and reuse it on caps, shirts, bottles and more.'**
  String get uploadYourLogoOnceAndReuse;

  /// No description provided for @thatFileIsOver25Mb.
  ///
  /// In en, this message translates to:
  /// **'That file is over 25 MB. Please upload a smaller one.'**
  String get thatFileIsOver25Mb;

  /// No description provided for @chooseYourArtwork.
  ///
  /// In en, this message translates to:
  /// **'Choose your artwork'**
  String get chooseYourArtwork;

  /// No description provided for @pngWithATransparentBackgroundGives.
  ///
  /// In en, this message translates to:
  /// **'PNG with a transparent background gives the best mockup. Vector files (SVG, AI, EPS, PDF) are welcome for production.'**
  String get pngWithATransparentBackgroundGives;

  /// No description provided for @uploadNewArtwork.
  ///
  /// In en, this message translates to:
  /// **'Upload new artwork'**
  String get uploadNewArtwork;

  /// No description provided for @yourLibrary.
  ///
  /// In en, this message translates to:
  /// **'Your library'**
  String get yourLibrary;

  /// No description provided for @digitizedNoSetupFeeForEmbroidery.
  ///
  /// In en, this message translates to:
  /// **'Digitized — no setup fee for embroidery'**
  String get digitizedNoSetupFeeForEmbroidery;

  /// No description provided for @pcs2.
  ///
  /// In en, this message translates to:
  /// **'{e} pcs'**
  String pcs2(Object e);

  /// No description provided for @dragADesignToAdjustIts.
  ///
  /// In en, this message translates to:
  /// **'Drag a design to adjust its position. Final placement is confirmed on your proof.'**
  String get dragADesignToAdjustIts;

  /// No description provided for @logo.
  ///
  /// In en, this message translates to:
  /// **'Logo'**
  String get logo;

  /// No description provided for @yourDesign.
  ///
  /// In en, this message translates to:
  /// **'Your design'**
  String get yourDesign;

  /// No description provided for @tellUsWhatYoudLikeChanged.
  ///
  /// In en, this message translates to:
  /// **'Tell us what you\'d like changed.'**
  String get tellUsWhatYoudLikeChanged;

  /// No description provided for @approvedProductionCanBegin.
  ///
  /// In en, this message translates to:
  /// **'Approved — production can begin.'**
  String get approvedProductionCanBegin;

  /// No description provided for @thanksWellSendARevisedProof.
  ///
  /// In en, this message translates to:
  /// **'Thanks — we\'ll send a revised proof.'**
  String get thanksWellSendARevisedProof;

  /// No description provided for @designProof.
  ///
  /// In en, this message translates to:
  /// **'Design proof'**
  String get designProof;

  /// No description provided for @ourDesignersArePreparingADigital.
  ///
  /// In en, this message translates to:
  /// **'Our designers are preparing a digital proof of your branding. You\'ll approve it here before anything is produced.'**
  String get ourDesignersArePreparingADigital;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version {version} · {proofStatus}'**
  String version(Object version, Object proofStatus);

  /// No description provided for @stitches.
  ///
  /// In en, this message translates to:
  /// **'{amount} stitches'**
  String stitches(Object amount);

  /// No description provided for @commentsRequiredToRequestChanges.
  ///
  /// In en, this message translates to:
  /// **'Comments (required to request changes)'**
  String get commentsRequiredToRequestChanges;

  /// No description provided for @approveProof.
  ///
  /// In en, this message translates to:
  /// **'Approve proof'**
  String get approveProof;

  /// No description provided for @requestChanges.
  ///
  /// In en, this message translates to:
  /// **'Request changes'**
  String get requestChanges;

  /// No description provided for @yourComment.
  ///
  /// In en, this message translates to:
  /// **'Your comment: {customerComment}'**
  String yourComment(Object customerComment);

  /// No description provided for @earlierVersions.
  ///
  /// In en, this message translates to:
  /// **'Earlier versions ({length})'**
  String earlierVersions(Object length);

  /// No description provided for @version2.
  ///
  /// In en, this message translates to:
  /// **'Version {version} · {status}'**
  String version2(Object version, Object status);

  /// No description provided for @proofSentToTheCustomer.
  ///
  /// In en, this message translates to:
  /// **'Proof sent to the customer'**
  String get proofSentToTheCustomer;

  /// No description provided for @proof.
  ///
  /// In en, this message translates to:
  /// **'Proof · {displayNumber}'**
  String proof(Object displayNumber);

  /// No description provided for @status.
  ///
  /// In en, this message translates to:
  /// **'Status: {proofStatus}'**
  String status(Object proofStatus);

  /// No description provided for @customer.
  ///
  /// In en, this message translates to:
  /// **'Customer: {customerComment}'**
  String customer(Object customerComment);

  /// No description provided for @sendANewVersion.
  ///
  /// In en, this message translates to:
  /// **'Send a new version'**
  String get sendANewVersion;

  /// No description provided for @addMockupStitchOutPhotos.
  ///
  /// In en, this message translates to:
  /// **'Add mockup / stitch-out photos'**
  String get addMockupStitchOutPhotos;

  /// No description provided for @stitchCountEmbroideryOptional.
  ///
  /// In en, this message translates to:
  /// **'Stitch count (embroidery, optional)'**
  String get stitchCountEmbroideryOptional;

  /// No description provided for @noteToCustomerSizesThreadColours.
  ///
  /// In en, this message translates to:
  /// **'Note to customer (sizes, thread colours, placement)'**
  String get noteToCustomerSizesThreadColours;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @sendProof.
  ///
  /// In en, this message translates to:
  /// **'Send proof'**
  String get sendProof;

  /// No description provided for @newRequest.
  ///
  /// In en, this message translates to:
  /// **'New request'**
  String get newRequest;

  /// No description provided for @couldntLoadYourQuotes.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your quotes'**
  String get couldntLoadYourQuotes;

  /// No description provided for @noQuoteRequestsYet.
  ///
  /// In en, this message translates to:
  /// **'No quote requests yet'**
  String get noQuoteRequestsYet;

  /// No description provided for @needACustomJobABig.
  ///
  /// In en, this message translates to:
  /// **'Need a custom job, a big quantity or a package tailored to you? Request a quote.'**
  String get needACustomJobABig;

  /// No description provided for @turnDownThisPrice.
  ///
  /// In en, this message translates to:
  /// **'Turn down this price?'**
  String get turnDownThisPrice;

  /// No description provided for @withdrawThisRequest.
  ///
  /// In en, this message translates to:
  /// **'Withdraw this request?'**
  String get withdrawThisRequest;

  /// No description provided for @keep.
  ///
  /// In en, this message translates to:
  /// **'Keep'**
  String get keep;

  /// No description provided for @turnDown.
  ///
  /// In en, this message translates to:
  /// **'Turn down'**
  String get turnDown;

  /// No description provided for @withdraw.
  ///
  /// In en, this message translates to:
  /// **'Withdraw'**
  String get withdraw;

  /// No description provided for @expired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get expired;

  /// No description provided for @pcsRequested.
  ///
  /// In en, this message translates to:
  /// **'{quantity} pcs · requested {amount}'**
  String pcsRequested(Object quantity, Object amount);

  /// No description provided for @quotedPrice.
  ///
  /// In en, this message translates to:
  /// **'Quoted price'**
  String get quotedPrice;

  /// No description provided for @validUntilIncludesDelivery.
  ///
  /// In en, this message translates to:
  /// **'Valid until {amount} · includes delivery'**
  String validUntilIncludesDelivery(Object amount);

  /// No description provided for @acceptOrder.
  ///
  /// In en, this message translates to:
  /// **'Accept & order'**
  String get acceptOrder;

  /// No description provided for @quotePdf.
  ///
  /// In en, this message translates to:
  /// **'Quote PDF'**
  String get quotePdf;

  /// No description provided for @viewOrder.
  ///
  /// In en, this message translates to:
  /// **'View order'**
  String get viewOrder;

  /// No description provided for @acceptQuote.
  ///
  /// In en, this message translates to:
  /// **'Accept quote'**
  String get acceptQuote;

  /// No description provided for @enterAName.
  ///
  /// In en, this message translates to:
  /// **'Enter a name'**
  String get enterAName;

  /// No description provided for @enterAnAddress.
  ///
  /// In en, this message translates to:
  /// **'Enter an address'**
  String get enterAnAddress;

  /// No description provided for @notesOptional.
  ///
  /// In en, this message translates to:
  /// **'Notes (optional)'**
  String get notesOptional;

  /// No description provided for @totalPayNow.
  ///
  /// In en, this message translates to:
  /// **'Total {amount} · pay {amount2} now'**
  String totalPayNow(Object amount, Object amount2);

  /// No description provided for @total2.
  ///
  /// In en, this message translates to:
  /// **'Total {amount}'**
  String total2(Object amount);

  /// No description provided for @signInOrCreateAnAccount4.
  ///
  /// In en, this message translates to:
  /// **'Sign in or create an account to request a quote.'**
  String get signInOrCreateAnAccount4;

  /// No description provided for @quoteRequestSentWellPriceIt.
  ///
  /// In en, this message translates to:
  /// **'Quote request sent — we\'ll price it and notify you under My Quotes.'**
  String get quoteRequestSentWellPriceIt;

  /// No description provided for @view.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get view;

  /// No description provided for @couldntSendRequest.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send request: {error}'**
  String couldntSendRequest(Object error);

  /// No description provided for @tellUsWhatYouNeedAnd.
  ///
  /// In en, this message translates to:
  /// **'Tell us what you need and we\'ll send you a price.'**
  String get tellUsWhatYouNeedAnd;

  /// No description provided for @whatDoYouNeed.
  ///
  /// In en, this message translates to:
  /// **'What do you need?'**
  String get whatDoYouNeed;

  /// No description provided for @eG200EmbroideredPoloShirts.
  ///
  /// In en, this message translates to:
  /// **'e.g. 200 embroidered polo shirts'**
  String get eG200EmbroideredPoloShirts;

  /// No description provided for @describeTheItem.
  ///
  /// In en, this message translates to:
  /// **'Describe the item'**
  String get describeTheItem;

  /// No description provided for @details.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get details;

  /// No description provided for @logoPlacementColoursSizesDeadlineDelivery.
  ///
  /// In en, this message translates to:
  /// **'Logo placement, colours, sizes, deadline, delivery location…'**
  String get logoPlacementColoursSizesDeadlineDelivery;

  /// No description provided for @sendRequest.
  ///
  /// In en, this message translates to:
  /// **'Send request'**
  String get sendRequest;

  /// No description provided for @accountDiscount2.
  ///
  /// In en, this message translates to:
  /// **'Account discount'**
  String get accountDiscount2;

  /// No description provided for @delivery2.
  ///
  /// In en, this message translates to:
  /// **'Delivery ({deliveryZoneName})'**
  String delivery2(Object deliveryZoneName);

  /// No description provided for @storePickup.
  ///
  /// In en, this message translates to:
  /// **'Store pickup'**
  String get storePickup;

  /// No description provided for @includesVat2.
  ///
  /// In en, this message translates to:
  /// **'Includes VAT ({vatPercent}%)'**
  String includesVat2(Object vatPercent);

  /// No description provided for @vat2.
  ///
  /// In en, this message translates to:
  /// **'VAT ({vatPercent}%)'**
  String vat2(Object vatPercent);

  /// No description provided for @paid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get paid;

  /// No description provided for @refunded.
  ///
  /// In en, this message translates to:
  /// **'Refunded'**
  String get refunded;

  /// No description provided for @cancellationFeeKept.
  ///
  /// In en, this message translates to:
  /// **'Cancellation fee kept'**
  String get cancellationFeeKept;

  /// No description provided for @balanceDue.
  ///
  /// In en, this message translates to:
  /// **'Balance due'**
  String get balanceDue;

  /// No description provided for @depositReceivedProductionCanStart.
  ///
  /// In en, this message translates to:
  /// **'Deposit received — production can start.'**
  String get depositReceivedProductionCanStart;

  /// No description provided for @depositOfDueBeforeProductionStarts.
  ///
  /// In en, this message translates to:
  /// **'Deposit of {amount} due before production starts.'**
  String depositOfDueBeforeProductionStarts(Object amount);

  /// No description provided for @couldntOpenThePaymentPage.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the payment page.'**
  String get couldntOpenThePaymentPage;

  /// No description provided for @onlinePaymentIsntAvailableYetWell.
  ///
  /// In en, this message translates to:
  /// **'Online payment isn\'t available yet. We\'ll send you an invoice with payment details.'**
  String get onlinePaymentIsntAvailableYetWell;

  /// No description provided for @deposit2.
  ///
  /// In en, this message translates to:
  /// **'Deposit {amount}'**
  String deposit2(Object amount);

  /// No description provided for @full.
  ///
  /// In en, this message translates to:
  /// **'Full {amount}'**
  String full(Object amount);

  /// No description provided for @mPesaPhoneNumber.
  ///
  /// In en, this message translates to:
  /// **'M-Pesa phone number'**
  String get mPesaPhoneNumber;

  /// No description provided for @testModeNoRealMoneyWill.
  ///
  /// In en, this message translates to:
  /// **'Test mode — no real money will be charged.'**
  String get testModeNoRealMoneyWill;

  /// No description provided for @ref.
  ///
  /// In en, this message translates to:
  /// **'Ref: {receipt}'**
  String ref(Object receipt);

  /// No description provided for @charged.
  ///
  /// In en, this message translates to:
  /// **'Charged {chargedCurrency} {chargedAmount}'**
  String charged(Object chargedCurrency, Object chargedAmount);

  /// No description provided for @checkStatus.
  ///
  /// In en, this message translates to:
  /// **'Check status'**
  String get checkStatus;

  /// No description provided for @checkYourPhone.
  ///
  /// In en, this message translates to:
  /// **'Check your phone'**
  String get checkYourPhone;

  /// No description provided for @paymentReceived.
  ///
  /// In en, this message translates to:
  /// **'Payment received'**
  String get paymentReceived;

  /// No description provided for @paymentFailed.
  ///
  /// In en, this message translates to:
  /// **'Payment failed'**
  String get paymentFailed;

  /// No description provided for @paymentCancelled.
  ///
  /// In en, this message translates to:
  /// **'Payment cancelled'**
  String get paymentCancelled;

  /// No description provided for @amount.
  ///
  /// In en, this message translates to:
  /// **'{message}\n\nAmount: {amount}'**
  String amount(Object message, Object amount);

  /// No description provided for @thePaymentDidNotGoThrough.
  ///
  /// In en, this message translates to:
  /// **'The payment did not go through.'**
  String get thePaymentDidNotGoThrough;

  /// No description provided for @ivePaidCheck.
  ///
  /// In en, this message translates to:
  /// **'I\'ve paid — check'**
  String get ivePaidCheck;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @getYourCustomBrandingFromUse.
  ///
  /// In en, this message translates to:
  /// **'Get your custom branding from {context}! Use my code {code} when you sign up and we both get {referralBonusPoints} points after your first order. {base}'**
  String getYourCustomBrandingFromUse(
    Object context,
    Object code,
    Object referralBonusPoints,
    Object base,
  );

  /// No description provided for @enterAFriendsCode.
  ///
  /// In en, this message translates to:
  /// **'Enter a friend\'s code'**
  String get enterAFriendsCode;

  /// No description provided for @onlyBeforeYourFirstOrder.
  ///
  /// In en, this message translates to:
  /// **'Only before your first order.'**
  String get onlyBeforeYourFirstOrder;

  /// No description provided for @codeAppliedYoullBothGetBonus.
  ///
  /// In en, this message translates to:
  /// **'Code applied — you\'ll both get bonus points after your first order.'**
  String get codeAppliedYoullBothGetBonus;

  /// No description provided for @pts.
  ///
  /// In en, this message translates to:
  /// **'{points} pts'**
  String pts(Object points);

  /// No description provided for @worthOffYouEarnPointS.
  ///
  /// In en, this message translates to:
  /// **'Worth {amount} off. You earn {pointsPerHundred} point(s) for every KES 100 you spend.'**
  String worthOffYouEarnPointS(Object amount, Object pointsPerHundred);

  /// No description provided for @referAFriendPtsEach.
  ///
  /// In en, this message translates to:
  /// **'Refer a friend (+{referralBonusPoints} pts each)'**
  String referAFriendPtsEach(Object referralBonusPoints);

  /// No description provided for @iHaveACode.
  ///
  /// In en, this message translates to:
  /// **'I have a code'**
  String get iHaveACode;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @copied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get copied;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @thanksForYourReview.
  ///
  /// In en, this message translates to:
  /// **'Thanks for your review'**
  String get thanksForYourReview;

  /// No description provided for @rateYourOrder.
  ///
  /// In en, this message translates to:
  /// **'Rate your order'**
  String get rateYourOrder;

  /// No description provided for @qualityFitDeliveryAnythingToShare.
  ///
  /// In en, this message translates to:
  /// **'Quality, fit, delivery… anything to share?'**
  String get qualityFitDeliveryAnythingToShare;

  /// No description provided for @photos4.
  ///
  /// In en, this message translates to:
  /// **'Photos ({count}/4)'**
  String photos4(Object count);

  /// No description provided for @reviewsAppearPubliclyAfterAQuick.
  ///
  /// In en, this message translates to:
  /// **'Reviews appear publicly after a quick check.'**
  String get reviewsAppearPubliclyAfterAQuick;

  /// No description provided for @submit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get submit;

  /// No description provided for @reviews.
  ///
  /// In en, this message translates to:
  /// **'Reviews'**
  String get reviews;

  /// No description provided for @nothingSavedYet.
  ///
  /// In en, this message translates to:
  /// **'Nothing saved yet'**
  String get nothingSavedYet;

  /// No description provided for @tapTheHeartOnAnyItem.
  ///
  /// In en, this message translates to:
  /// **'Tap the heart on any item to save it for later.'**
  String get tapTheHeartOnAnyItem;

  /// No description provided for @brandingWeveProducedForSchoolsCompanies.
  ///
  /// In en, this message translates to:
  /// **'Branding we\'ve produced for schools, companies, events and teams.'**
  String get brandingWeveProducedForSchoolsCompanies;

  /// No description provided for @comingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get comingSoon;

  /// No description provided for @ourGalleryOfRecentJobsWill.
  ///
  /// In en, this message translates to:
  /// **'Our gallery of recent jobs will appear here.'**
  String get ourGalleryOfRecentJobsWill;

  /// No description provided for @portfolio.
  ///
  /// In en, this message translates to:
  /// **'Portfolio'**
  String get portfolio;

  /// No description provided for @noReviewsYet.
  ///
  /// In en, this message translates to:
  /// **'No reviews yet'**
  String get noReviewsYet;

  /// No description provided for @customersAreAskedToReviewEach.
  ///
  /// In en, this message translates to:
  /// **'Customers are asked to review each completed order.'**
  String get customersAreAskedToReviewEach;

  /// No description provided for @reply.
  ///
  /// In en, this message translates to:
  /// **'Reply: {reply}'**
  String reply(Object reply);

  /// No description provided for @publicReply.
  ///
  /// In en, this message translates to:
  /// **'Public reply'**
  String get publicReply;

  /// No description provided for @approvePublish.
  ///
  /// In en, this message translates to:
  /// **'Approve (publish)'**
  String get approvePublish;

  /// No description provided for @hide.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get hide;

  /// No description provided for @replyPublicly.
  ///
  /// In en, this message translates to:
  /// **'Reply publicly'**
  String get replyPublicly;

  /// No description provided for @newPortfolioEntryPhotoS.
  ///
  /// In en, this message translates to:
  /// **'New portfolio entry ({count} photo(s))'**
  String newPortfolioEntryPhotoS(Object count);

  /// No description provided for @title.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get title;

  /// No description provided for @description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @tagsCommaSeparated.
  ///
  /// In en, this message translates to:
  /// **'Tags (comma separated)'**
  String get tagsCommaSeparated;

  /// No description provided for @publish.
  ///
  /// In en, this message translates to:
  /// **'Publish'**
  String get publish;

  /// No description provided for @addWork.
  ///
  /// In en, this message translates to:
  /// **'Add work'**
  String get addWork;

  /// No description provided for @unfeature.
  ///
  /// In en, this message translates to:
  /// **'Unfeature'**
  String get unfeature;

  /// No description provided for @feature.
  ///
  /// In en, this message translates to:
  /// **'Feature'**
  String get feature;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @dropAPinOnYourDelivery.
  ///
  /// In en, this message translates to:
  /// **'Drop a pin on your delivery point'**
  String get dropAPinOnYourDelivery;

  /// No description provided for @useThisSpot.
  ///
  /// In en, this message translates to:
  /// **'Use this spot'**
  String get useThisSpot;

  /// No description provided for @uniforms.
  ///
  /// In en, this message translates to:
  /// **'{company} uniforms'**
  String uniforms(Object company);

  /// No description provided for @approvedBrandedItemsForYourTeam.
  ///
  /// In en, this message translates to:
  /// **'Approved branded items for your team — just choose sizes.'**
  String get approvedBrandedItemsForYourTeam;

  /// No description provided for @newCompany.
  ///
  /// In en, this message translates to:
  /// **'New company'**
  String get newCompany;

  /// No description provided for @couldntLoadCompanies.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load companies'**
  String get couldntLoadCompanies;

  /// No description provided for @noCompaniesYet.
  ///
  /// In en, this message translates to:
  /// **'No companies yet'**
  String get noCompaniesYet;

  /// No description provided for @groupBuyersFromTheSameOrganisation.
  ///
  /// In en, this message translates to:
  /// **'Group buyers from the same organisation: shared discount, credit and uniform programs.'**
  String get groupBuyersFromTheSameOrganisation;

  /// No description provided for @buyerS.
  ///
  /// In en, this message translates to:
  /// **'{count} buyer(s)'**
  String buyerS(Object count);

  /// No description provided for @off.
  ///
  /// In en, this message translates to:
  /// **'{discountPercent}% off'**
  String off(Object discountPercent);

  /// No description provided for @editCompanyBuyers.
  ///
  /// In en, this message translates to:
  /// **'Edit company & buyers'**
  String get editCompanyBuyers;

  /// No description provided for @newUniformProgram.
  ///
  /// In en, this message translates to:
  /// **'New uniform program'**
  String get newUniformProgram;

  /// No description provided for @edit2.
  ///
  /// In en, this message translates to:
  /// **'Edit {existing}'**
  String edit2(Object existing);

  /// No description provided for @companyName.
  ///
  /// In en, this message translates to:
  /// **'Company name'**
  String get companyName;

  /// No description provided for @kraPinForInvoicesEtims.
  ///
  /// In en, this message translates to:
  /// **'KRA PIN (for invoices / eTIMS)'**
  String get kraPinForInvoicesEtims;

  /// No description provided for @discountForAllBuyers.
  ///
  /// In en, this message translates to:
  /// **'Discount for all buyers (%)'**
  String get discountForAllBuyers;

  /// No description provided for @creditTerms.
  ///
  /// In en, this message translates to:
  /// **'Credit terms'**
  String get creditTerms;

  /// No description provided for @paymentTermsDays.
  ///
  /// In en, this message translates to:
  /// **'Payment terms (days)'**
  String get paymentTermsDays;

  /// No description provided for @companyCreditLimitKes0None.
  ///
  /// In en, this message translates to:
  /// **'Company credit limit (KES, 0 = none)'**
  String get companyCreditLimitKes0None;

  /// No description provided for @buyers.
  ///
  /// In en, this message translates to:
  /// **'Buyers ({count})'**
  String buyers(Object count);

  /// No description provided for @findCustomersByNameOrEmail.
  ///
  /// In en, this message translates to:
  /// **'Find customers by name or email'**
  String get findCustomersByNameOrEmail;

  /// No description provided for @editProgram.
  ///
  /// In en, this message translates to:
  /// **'Edit program'**
  String get editProgram;

  /// No description provided for @programName.
  ///
  /// In en, this message translates to:
  /// **'Program name'**
  String get programName;

  /// No description provided for @eG2027StaffUniforms.
  ///
  /// In en, this message translates to:
  /// **'e.g. 2027 staff uniforms'**
  String get eG2027StaffUniforms;

  /// No description provided for @notesForBuyers.
  ///
  /// In en, this message translates to:
  /// **'Notes for buyers'**
  String get notesForBuyers;

  /// No description provided for @active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// No description provided for @itemsComeFromCustomisedOrdersThis.
  ///
  /// In en, this message translates to:
  /// **'Items come from customised orders this company has placed. Once a buyer orders a branded item, it can be added here.'**
  String get itemsComeFromCustomisedOrdersThis;

  /// No description provided for @from2.
  ///
  /// In en, this message translates to:
  /// **'{c} (from {order})'**
  String from2(Object c, Object order);

  /// No description provided for @addFromAPastOrder.
  ///
  /// In en, this message translates to:
  /// **'Add from a past order'**
  String get addFromAPastOrder;

  /// No description provided for @saved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get saved;

  /// No description provided for @loyaltyReferrals.
  ///
  /// In en, this message translates to:
  /// **'Loyalty & referrals'**
  String get loyaltyReferrals;

  /// No description provided for @loyaltyProgrammeOn.
  ///
  /// In en, this message translates to:
  /// **'Loyalty programme on'**
  String get loyaltyProgrammeOn;

  /// No description provided for @pointsPerKes100Spent.
  ///
  /// In en, this message translates to:
  /// **'Points per KES 100 spent'**
  String get pointsPerKes100Spent;

  /// No description provided for @kesValueOf1Point.
  ///
  /// In en, this message translates to:
  /// **'KES value of 1 point'**
  String get kesValueOf1Point;

  /// No description provided for @referralBonusPointsEach.
  ///
  /// In en, this message translates to:
  /// **'Referral bonus (points each)'**
  String get referralBonusPointsEach;

  /// No description provided for @maxOfAnOrderPaidWith.
  ///
  /// In en, this message translates to:
  /// **'Max % of an order paid with points'**
  String get maxOfAnOrderPaidWith;

  /// No description provided for @displayCurrencies.
  ///
  /// In en, this message translates to:
  /// **'Display currencies'**
  String get displayCurrencies;

  /// No description provided for @kesPer1UnitCustomersCan.
  ///
  /// In en, this message translates to:
  /// **'KES per 1 unit. Customers can see approximate prices in these; everything is still charged in KES.'**
  String get kesPer1UnitCustomersCan;

  /// No description provided for @kesPer1.
  ///
  /// In en, this message translates to:
  /// **'KES per 1 {c}'**
  String kesPer1(Object c);

  /// No description provided for @saveLoyaltyCurrencies.
  ///
  /// In en, this message translates to:
  /// **'Save loyalty & currencies'**
  String get saveLoyaltyCurrencies;

  /// No description provided for @alsoShowPricesIn.
  ///
  /// In en, this message translates to:
  /// **'Also show prices in'**
  String get alsoShowPricesIn;

  /// No description provided for @approximateOnlyYouPayInKes.
  ///
  /// In en, this message translates to:
  /// **'Approximate only — you pay in KES.'**
  String get approximateOnlyYouPayInKes;

  /// No description provided for @kesOnly.
  ///
  /// In en, this message translates to:
  /// **'KES only'**
  String get kesOnly;

  /// No description provided for @couldntLoadNotifications.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load notifications'**
  String get couldntLoadNotifications;

  /// No description provided for @unread.
  ///
  /// In en, this message translates to:
  /// **'{count} unread'**
  String unread(Object count);

  /// No description provided for @notificationSettings.
  ///
  /// In en, this message translates to:
  /// **'Notification settings'**
  String get notificationSettings;

  /// No description provided for @orderUpdatesProofsPaymentsAndMessages.
  ///
  /// In en, this message translates to:
  /// **'Order updates, proofs, payments and messages will appear here.'**
  String get orderUpdatesProofsPaymentsAndMessages;

  /// No description provided for @getAlertsOnThisDevice.
  ///
  /// In en, this message translates to:
  /// **'Get alerts on this device'**
  String get getAlertsOnThisDevice;

  /// No description provided for @orderUpdatesAndMessagesEvenWhen.
  ///
  /// In en, this message translates to:
  /// **'Order updates and messages, even when the app is closed.'**
  String get orderUpdatesAndMessagesEvenWhen;

  /// No description provided for @alertsSwitchedOnForThisDevice.
  ///
  /// In en, this message translates to:
  /// **'Alerts switched on for this device'**
  String get alertsSwitchedOnForThisDevice;

  /// No description provided for @couldntSwitchOnAlertsCheckYour.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t switch on alerts — check your browser/phone notification permission.'**
  String get couldntSwitchOnAlertsCheckYour;

  /// No description provided for @turnOn.
  ///
  /// In en, this message translates to:
  /// **'Turn on'**
  String get turnOn;

  /// No description provided for @howShouldWeReachYou.
  ///
  /// In en, this message translates to:
  /// **'How should we reach you?'**
  String get howShouldWeReachYou;

  /// No description provided for @theInAppInboxAlwaysGets.
  ///
  /// In en, this message translates to:
  /// **'The in-app inbox always gets everything.'**
  String get theInAppInboxAlwaysGets;

  /// No description provided for @pushNotifications.
  ///
  /// In en, this message translates to:
  /// **'Push notifications'**
  String get pushNotifications;

  /// No description provided for @usesThePhoneNumberOnYour.
  ///
  /// In en, this message translates to:
  /// **'Uses the phone number on your profile'**
  String get usesThePhoneNumberOnYour;

  /// No description provided for @remindersOffers.
  ///
  /// In en, this message translates to:
  /// **'Reminders & offers'**
  String get remindersOffers;

  /// No description provided for @cartRemindersAndPromotions.
  ///
  /// In en, this message translates to:
  /// **'Cart reminders and promotions'**
  String get cartRemindersAndPromotions;

  /// No description provided for @notificationChannelsSaved.
  ///
  /// In en, this message translates to:
  /// **'Notification channels saved'**
  String get notificationChannelsSaved;

  /// No description provided for @testSentCheckYourInboxEmail.
  ///
  /// In en, this message translates to:
  /// **'Test sent — check your inbox, email and WhatsApp.'**
  String get testSentCheckYourInboxEmail;

  /// No description provided for @couldntLoadNotificationSettings.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load notification settings: {error}'**
  String couldntLoadNotificationSettings(Object error);

  /// No description provided for @inAppAndPushNotificationsWork.
  ///
  /// In en, this message translates to:
  /// **'In-app and push notifications work out of the box. Add email and WhatsApp below; customers choose their channels in their inbox.'**
  String get inAppAndPushNotificationsWork;

  /// No description provided for @emailProvider.
  ///
  /// In en, this message translates to:
  /// **'Email provider'**
  String get emailProvider;

  /// No description provided for @fromAddress.
  ///
  /// In en, this message translates to:
  /// **'From address'**
  String get fromAddress;

  /// No description provided for @mustBeASenderDomainVerified.
  ///
  /// In en, this message translates to:
  /// **'Must be a sender/domain verified with the provider.'**
  String get mustBeASenderDomainVerified;

  /// No description provided for @apiKey.
  ///
  /// In en, this message translates to:
  /// **'API key'**
  String get apiKey;

  /// No description provided for @whatsappMetaCloudApi.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp (Meta Cloud API)'**
  String get whatsappMetaCloudApi;

  /// No description provided for @phoneNumberId.
  ///
  /// In en, this message translates to:
  /// **'Phone number ID'**
  String get phoneNumberId;

  /// No description provided for @metaForDevelopersWhatsappApiSetup.
  ///
  /// In en, this message translates to:
  /// **'Meta for Developers → WhatsApp → API Setup'**
  String get metaForDevelopersWhatsappApiSetup;

  /// No description provided for @permanentAccessToken.
  ///
  /// In en, this message translates to:
  /// **'Permanent access token'**
  String get permanentAccessToken;

  /// No description provided for @createASystemUserTokenWith.
  ///
  /// In en, this message translates to:
  /// **'Create a System User token with whatsapp_business_messaging.'**
  String get createASystemUserTokenWith;

  /// No description provided for @templateName.
  ///
  /// In en, this message translates to:
  /// **'Template name'**
  String get templateName;

  /// No description provided for @templateLanguageCode.
  ///
  /// In en, this message translates to:
  /// **'Template language code'**
  String get templateLanguageCode;

  /// No description provided for @sendMeATest.
  ///
  /// In en, this message translates to:
  /// **'Send me a test'**
  String get sendMeATest;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @followYourDeviceOrLockIt.
  ///
  /// In en, this message translates to:
  /// **'Follow your device, or lock it to light or dark.'**
  String get followYourDeviceOrLockIt;

  /// No description provided for @system.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get system;

  /// No description provided for @light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get light;

  /// No description provided for @dark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get dark;

  /// No description provided for @font.
  ///
  /// In en, this message translates to:
  /// **'Font'**
  String get font;

  /// No description provided for @pickWhicheverReadsBestToYou.
  ///
  /// In en, this message translates to:
  /// **'Pick whichever reads best to you — applies everywhere, instantly.'**
  String get pickWhicheverReadsBestToYou;

  /// No description provided for @accessibility.
  ///
  /// In en, this message translates to:
  /// **'Accessibility'**
  String get accessibility;

  /// No description provided for @textSize.
  ///
  /// In en, this message translates to:
  /// **'Text size'**
  String get textSize;

  /// No description provided for @appliesAcrossTheWholeAppIndependent.
  ///
  /// In en, this message translates to:
  /// **'Applies across the whole app, independent of your device\'s own text size.'**
  String get appliesAcrossTheWholeAppIndependent;

  /// No description provided for @reduceMotion.
  ///
  /// In en, this message translates to:
  /// **'Reduce motion'**
  String get reduceMotion;

  /// No description provided for @skipEntranceStaggerAnimationsOnLists.
  ///
  /// In en, this message translates to:
  /// **'Skip entrance/stagger animations on lists and grids.'**
  String get skipEntranceStaggerAnimationsOnLists;

  /// No description provided for @inAppNotifications.
  ///
  /// In en, this message translates to:
  /// **'In-app notifications'**
  String get inAppNotifications;

  /// No description provided for @showTheAnnouncementBannerOnHome.
  ///
  /// In en, this message translates to:
  /// **'Show the announcement banner on Home. This doesn\'t send push alerts.'**
  String get showTheAnnouncementBannerOnHome;

  /// No description provided for @languageCurrency.
  ///
  /// In en, this message translates to:
  /// **'Language & currency'**
  String get languageCurrency;

  /// No description provided for @aboutSupport.
  ///
  /// In en, this message translates to:
  /// **'About & support'**
  String get aboutSupport;

  /// No description provided for @contactSupport.
  ///
  /// In en, this message translates to:
  /// **'Contact support'**
  String get contactSupport;

  /// No description provided for @getHelpWithAnOrderA.
  ///
  /// In en, this message translates to:
  /// **'Get help with an order, a design, or anything else.'**
  String get getHelpWithAnOrderA;

  /// No description provided for @loadingVersion.
  ///
  /// In en, this message translates to:
  /// **'Loading version…'**
  String get loadingVersion;

  /// No description provided for @version3.
  ///
  /// In en, this message translates to:
  /// **'Version {version} ({buildNumber})'**
  String version3(Object version, Object buildNumber);

  /// No description provided for @answer.
  ///
  /// In en, this message translates to:
  /// **'Answer'**
  String get answer;

  /// No description provided for @savedAnswerShownWhileOffline.
  ///
  /// In en, this message translates to:
  /// **'Saved answer — shown while offline'**
  String get savedAnswerShownWhileOffline;

  /// No description provided for @gotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get gotIt;

  /// No description provided for @nothingHereYet.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet'**
  String get nothingHereYet;

  /// No description provided for @askAQuestionBelowAndThe.
  ///
  /// In en, this message translates to:
  /// **'Ask a question below and the assistant will help.'**
  String get askAQuestionBelowAndThe;

  /// No description provided for @tryADifferentSearchOrAsk.
  ///
  /// In en, this message translates to:
  /// **'Try a different search, or ask below.'**
  String get tryADifferentSearchOrAsk;

  /// No description provided for @guide.
  ///
  /// In en, this message translates to:
  /// **'Guide'**
  String get guide;

  /// No description provided for @answersForWhatYouCanDo.
  ///
  /// In en, this message translates to:
  /// **'Answers for what you can do here — search below, or ask your own question.'**
  String get answersForWhatYouCanDo;

  /// No description provided for @searchQuestionsEGAssignOrder.
  ///
  /// In en, this message translates to:
  /// **'Search questions, e.g. \"assign order\"'**
  String get searchQuestionsEGAssignOrder;

  /// No description provided for @couldntLoadTheGuide.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the guide'**
  String get couldntLoadTheGuide;

  /// No description provided for @youreOfflineShowingSavedAnswersAsking.
  ///
  /// In en, this message translates to:
  /// **'You\'re offline — showing saved answers. Asking something new needs a connection.'**
  String get youreOfflineShowingSavedAnswersAsking;

  /// No description provided for @askSomethingElseNeedsInternet.
  ///
  /// In en, this message translates to:
  /// **'Ask something else — needs internet'**
  String get askSomethingElseNeedsInternet;

  /// No description provided for @typeYourQuestion.
  ///
  /// In en, this message translates to:
  /// **'Type your question…'**
  String get typeYourQuestion;

  /// No description provided for @switchViewDeveloper.
  ///
  /// In en, this message translates to:
  /// **'Switch view (Developer)'**
  String get switchViewDeveloper;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @createAnAccountToContinue.
  ///
  /// In en, this message translates to:
  /// **'Create an account to continue'**
  String get createAnAccountToContinue;

  /// No description provided for @signInOrCreateAccount.
  ///
  /// In en, this message translates to:
  /// **'Sign in or create account'**
  String get signInOrCreateAccount;

  /// No description provided for @orderStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Order status: cancelled'**
  String get orderStatusCancelled;

  /// No description provided for @orderStatusStepOf.
  ///
  /// In en, this message translates to:
  /// **'Order status: {context}, step {currentIndex} of {count}'**
  String orderStatusStepOf(Object context, Object currentIndex, Object count);

  /// No description provided for @couldntUploadPhoto.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t upload photo: {error}'**
  String couldntUploadPhoto(Object error);

  /// No description provided for @profileUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile updated'**
  String get profileUpdated;

  /// No description provided for @couldntSave.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save: {error}'**
  String couldntSave(Object error);

  /// No description provided for @couldntLoadYourProfile.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your profile'**
  String get couldntLoadYourProfile;

  /// No description provided for @noProfileFound.
  ///
  /// In en, this message translates to:
  /// **'No profile found'**
  String get noProfileFound;

  /// No description provided for @signInAgainToLoadYour.
  ///
  /// In en, this message translates to:
  /// **'Sign in again to load your account details.'**
  String get signInAgainToLoadYour;

  /// No description provided for @yourAccountDetails.
  ///
  /// In en, this message translates to:
  /// **'Your account details.'**
  String get yourAccountDetails;

  /// No description provided for @displayName.
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get displayName;

  /// No description provided for @required.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get required;

  /// No description provided for @phoneOptional.
  ///
  /// In en, this message translates to:
  /// **'Phone (optional)'**
  String get phoneOptional;

  /// No description provided for @vehiclePlateOptional.
  ///
  /// In en, this message translates to:
  /// **'Vehicle plate (optional)'**
  String get vehiclePlateOptional;

  /// No description provided for @availableForDeliveries.
  ///
  /// In en, this message translates to:
  /// **'Available for deliveries'**
  String get availableForDeliveries;

  /// No description provided for @dailyWageDaySetByAdmin.
  ///
  /// In en, this message translates to:
  /// **'Daily wage: {amount}/day (set by Admin)'**
  String dailyWageDaySetByAdmin(Object amount);

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get saveChanges;

  /// No description provided for @security.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get security;

  /// No description provided for @changePassword.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get changePassword;

  /// No description provided for @yourSavedLogosForBrandingOrders.
  ///
  /// In en, this message translates to:
  /// **'Your saved logos for branding orders'**
  String get yourSavedLogosForBrandingOrders;

  /// No description provided for @passwordChanged.
  ///
  /// In en, this message translates to:
  /// **'Password changed'**
  String get passwordChanged;

  /// No description provided for @couldntChangePassword.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t change password'**
  String get couldntChangePassword;

  /// No description provided for @currentPassword.
  ///
  /// In en, this message translates to:
  /// **'Current password'**
  String get currentPassword;

  /// No description provided for @newPassword.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get newPassword;

  /// No description provided for @locatingMoreStopS.
  ///
  /// In en, this message translates to:
  /// **'Locating {count} more stop(s)…'**
  String locatingMoreStopS(Object count);

  /// No description provided for @stops.
  ///
  /// In en, this message translates to:
  /// **'Stops ({count})'**
  String stops(Object count);

  /// No description provided for @pageNotFound.
  ///
  /// In en, this message translates to:
  /// **'Page not found'**
  String get pageNotFound;

  /// No description provided for @thatLinkDoesntLeadAnywhereIn.
  ///
  /// In en, this message translates to:
  /// **'That link doesn\'t lead anywhere in BrightBrush.'**
  String get thatLinkDoesntLeadAnywhereIn;

  /// No description provided for @goHome.
  ///
  /// In en, this message translates to:
  /// **'Go home'**
  String get goHome;

  /// No description provided for @noValidWhatsappNumberForThis.
  ///
  /// In en, this message translates to:
  /// **'No valid WhatsApp number for this contact.'**
  String get noValidWhatsappNumberForThis;

  /// No description provided for @couldntOpenWhatsappOnThisDevice.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open WhatsApp on this device.'**
  String get couldntOpenWhatsappOnThisDevice;

  /// No description provided for @auto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get auto;

  /// No description provided for @browsingAsGuest.
  ///
  /// In en, this message translates to:
  /// **'Browsing as guest'**
  String get browsingAsGuest;

  /// No description provided for @developerView.
  ///
  /// In en, this message translates to:
  /// **'{role} · Developer view'**
  String developerView(Object role);

  /// No description provided for @invoiceNothingNow.
  ///
  /// In en, this message translates to:
  /// **'Nothing to pay now — we\'ll invoice {account}, due in {days} days.'**
  String invoiceNothingNow(Object account, Object days);

  /// No description provided for @yourAccount.
  ///
  /// In en, this message translates to:
  /// **'your account'**
  String get yourAccount;

  /// No description provided for @volumePricing.
  ///
  /// In en, this message translates to:
  /// **'Volume pricing: {tiers}'**
  String volumePricing(Object tiers);

  /// No description provided for @tierPcs.
  ///
  /// In en, this message translates to:
  /// **'{minQty}+ pcs {price}'**
  String tierPcs(Object minQty, Object price);

  /// No description provided for @piecesCount.
  ///
  /// In en, this message translates to:
  /// **'{quantity} pcs'**
  String piecesCount(Object quantity);

  /// No description provided for @inclSetup.
  ///
  /// In en, this message translates to:
  /// **' · incl. {amount} setup'**
  String inclSetup(Object amount);

  /// No description provided for @minimumPcs.
  ///
  /// In en, this message translates to:
  /// **'Minimum {moq} pcs'**
  String minimumPcs(Object moq);

  /// No description provided for @tierAt.
  ///
  /// In en, this message translates to:
  /// **'{minQty}+ @ {price}'**
  String tierAt(Object minQty, Object price);

  /// No description provided for @blanksLine.
  ///
  /// In en, this message translates to:
  /// **'Blanks ({quantity} × {price}{surcharges})'**
  String blanksLine(Object quantity, Object price, Object surcharges);

  /// No description provided for @plusSizeSurcharges.
  ///
  /// In en, this message translates to:
  /// **' + size surcharges'**
  String get plusSizeSurcharges;

  /// No description provided for @digitized.
  ///
  /// In en, this message translates to:
  /// **'Digitized'**
  String get digitized;

  /// No description provided for @stitchesSuffix.
  ///
  /// In en, this message translates to:
  /// **' · {count} stitches'**
  String stitchesSuffix(Object count);

  /// No description provided for @threadsList.
  ///
  /// In en, this message translates to:
  /// **'threads {colours}'**
  String threadsList(Object colours);

  /// No description provided for @namesList.
  ///
  /// In en, this message translates to:
  /// **'Names ({count}): {names}'**
  String namesList(Object count, Object names);

  /// No description provided for @overdueWasDue.
  ///
  /// In en, this message translates to:
  /// **'Overdue — was due {date}'**
  String overdueWasDue(Object date);

  /// No description provided for @onAccountDue.
  ///
  /// In en, this message translates to:
  /// **'On account · due {date}'**
  String onAccountDue(Object date);

  /// No description provided for @thankYouReceived.
  ///
  /// In en, this message translates to:
  /// **'Thank you! {amount} received{reference}.'**
  String thankYouReceived(Object amount, Object reference);

  /// No description provided for @mpesaRefSuffix.
  ///
  /// In en, this message translates to:
  /// **' (M-Pesa ref {receipt})'**
  String mpesaRefSuffix(Object receipt);

  /// No description provided for @photosCount.
  ///
  /// In en, this message translates to:
  /// **'{count} photo(s)'**
  String photosCount(Object count);

  /// No description provided for @featuredSuffix.
  ///
  /// In en, this message translates to:
  /// **' · featured'**
  String get featuredSuffix;

  /// No description provided for @memberSince.
  ///
  /// In en, this message translates to:
  /// **'Member since {date}'**
  String memberSince(Object date);
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
