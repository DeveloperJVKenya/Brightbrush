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

  @override
  String get netOfflineTitle => 'You\'re offline';

  @override
  String get netOfflineBody =>
      'Showing what was saved on this device. Turn on Wi-Fi or mobile data to see updates and place orders.';

  @override
  String get netOfflineNoInternetBody =>
      'Connected, but the internet isn\'t reachable. Check your data bundle or switch to a better Wi-Fi. Showing saved data.';

  @override
  String get netWeakTitle => 'Weak connection';

  @override
  String get netWeakBody =>
      'Things may load slowly. Move to a stronger signal or connect to Wi-Fi.';

  @override
  String get netBackOnline => 'Back online';

  @override
  String get netOpenSettings => 'Open settings';

  @override
  String get netDismiss => 'Dismiss';

  @override
  String get netActionNeedsInternet =>
      'You\'re offline. Connect to the internet and try again.';

  @override
  String get netSavedCopyTag => 'Saved copy';

  @override
  String get errNetwork =>
      'Please check your internet connection and try again.';

  @override
  String get errPermission =>
      'You don\'t have permission to do this. Contact an admin if you think this is a mistake.';

  @override
  String get errAssistant =>
      'The assistant is temporarily unavailable right now. Please try again shortly.';

  @override
  String get errSlow =>
      'That\'s taking longer than expected. Please try again.';

  @override
  String get errNotFound =>
      'That couldn\'t be found — it may have been removed.';

  @override
  String get errGeneric => 'Something went wrong. Please try again.';

  @override
  String get couldntLoadYourCart => 'Couldn\'t load your cart';

  @override
  String get loading => 'Loading';

  @override
  String get addItemsOrSeasonalPackagesFrom =>
      'Add items or seasonal packages from the catalog to start an order.';

  @override
  String get packageNoLongerAvailable => 'Package no longer available';

  @override
  String get itemNoLongerAvailable => 'Item no longer available';

  @override
  String get removeTheItemsThatAreNo =>
      'Remove the items that are no longer available to continue.';

  @override
  String tapEditToFixIt(Object invalid, Object problem) {
    return '\"$invalid\": $problem Tap edit to fix it.';
  }

  @override
  String hasAMinimumOrderOf(Object below, Object minQuantity) {
    return '\"$below\" has a minimum order of $minQuantity.';
  }

  @override
  String get orderPlacedYouCanPayFor =>
      'Order placed — you can pay for it right here.';

  @override
  String couldntPlaceOrder(Object error) {
    return 'Couldn\'t place order: $error';
  }

  @override
  String get chooseYourDeliveryArea => 'Choose your delivery area.';

  @override
  String pcs(Object quantity, Object amount) {
    return '$quantity pcs · $amount';
  }

  @override
  String get package => 'Package';

  @override
  String min(Object minQuantity) {
    return 'min $minQuantity';
  }

  @override
  String get removeThisToContinue => 'Remove this to continue';

  @override
  String get edit => 'Edit';

  @override
  String get remove => 'Remove';

  @override
  String get deliverToMe => 'Deliver to me';

  @override
  String get illPickUp => 'I\'ll pick up';

  @override
  String pickUpAt(Object pickupAddress) {
    return 'Pick up at: $pickupAddress';
  }

  @override
  String get deliveryArea => 'Delivery area';

  @override
  String get enterYourName => 'Enter your name';

  @override
  String get enterAPhoneNumber => 'Enter a phone number';

  @override
  String get dropAPinForTheDriver => 'Drop a pin for the driver (optional)';

  @override
  String get pinSetTapToAdjust => 'Pin set — tap to adjust';

  @override
  String get save => 'Save';

  @override
  String get enterADeliveryAddress => 'Enter a delivery address';

  @override
  String get notesArtworkDetailsColoursSizes =>
      'Notes (artwork details, colours, sizes...)';

  @override
  String get cartChangedApplyAgain => 'Cart changed — apply again';

  @override
  String get codeApplied => 'Code applied';

  @override
  String accountDiscount(Object discountPercent) {
    return 'Account discount ($discountPercent%)';
  }

  @override
  String useMyPointsAvailable(Object myPoints) {
    return 'Use my points ($myPoints available)';
  }

  @override
  String upToOfTheOrder(Object maxRedeemPercent) {
    return 'Up to $maxRedeemPercent% of the order';
  }

  @override
  String points(Object points) {
    return 'Points ($points)';
  }

  @override
  String promo(Object text) {
    return 'Promo $text';
  }

  @override
  String get delivery => 'Delivery';

  @override
  String get deliveryFree => 'Delivery (free)';

  @override
  String includesVat(Object taxRate) {
    return 'Includes VAT ($taxRate%)';
  }

  @override
  String vat(Object taxRate) {
    return 'VAT ($taxRate%)';
  }

  @override
  String deposit(Object depositPercent) {
    return '$depositPercent% deposit';
  }

  @override
  String onAccountD(Object paymentTermsDays) {
    return 'On account (${paymentTermsDays}d)';
  }

  @override
  String payNowToStartProductionAnd(Object amount, Object amount2) {
    return 'Pay $amount now to start production, and $amount2 before delivery.';
  }

  @override
  String get youllChooseHowToPayM =>
      'You\'ll choose how to pay (M-Pesa, card and more) on the next screen. Final prices are confirmed when the order is placed.';

  @override
  String get decreaseQuantity => 'Decrease quantity';

  @override
  String get increaseQuantity => 'Increase quantity';

  @override
  String get quantity => 'Quantity';

  @override
  String minimum(Object minQuantity) {
    return 'Minimum $minQuantity';
  }

  @override
  String get cancel => 'Cancel';

  @override
  String get set => 'Set';

  @override
  String get back => 'Back';

  @override
  String get itemDetails => 'Item details';

  @override
  String get failedToLoad => 'Failed to load';

  @override
  String get itemNotFound => 'Item not found';

  @override
  String get itMayHaveBeenRemovedOr =>
      'It may have been removed or is no longer active.';

  @override
  String from(Object amount) {
    return 'From $amount';
  }

  @override
  String moq(Object moq) {
    return 'MOQ $moq';
  }

  @override
  String dayLeadTime(Object leadTimeDays) {
    return '$leadTimeDays day lead time';
  }

  @override
  String get noDescriptionProvidedYet => 'No description provided yet.';

  @override
  String signInOrCreateAnAccount(Object item) {
    return 'Sign in or create an account to add \"$item\" to your cart.';
  }

  @override
  String addedMinimumOrder(Object item, Object moq) {
    return '$item added (minimum order $moq)';
  }

  @override
  String couldntAddToCart(Object error) {
    return 'Couldn\'t add to cart: $error';
  }

  @override
  String get ticketSentWellGetBackTo =>
      'Ticket sent — we\'ll get back to you here.';

  @override
  String couldntSend(Object error) {
    return 'Couldn\'t send: $error';
  }

  @override
  String get tellUsAboutAnOrderA =>
      'Tell us about an order, a design, or a complaint.';

  @override
  String get subject => 'Subject';

  @override
  String get enterASubject => 'Enter a subject';

  @override
  String get message => 'Message';

  @override
  String get enterAMessage => 'Enter a message';

  @override
  String get send => 'Send';

  @override
  String get yourTickets => 'Your tickets';

  @override
  String get couldntLoadTickets => 'Couldn\'t load tickets';

  @override
  String get noTicketsYet => 'No tickets yet';

  @override
  String get anythingYouSendAboveWillShow =>
      'Anything you send above will show up here with our reply.';

  @override
  String get couldntLoadYourOrders => 'Couldn\'t load your orders';

  @override
  String get nothingOutForDelivery => 'Nothing out for delivery';

  @override
  String get onceAnOrderIsOutFor =>
      'Once an order is out for delivery, track it live here.';

  @override
  String get myOrders => 'My orders';

  @override
  String get myQuotes => 'My quotes';

  @override
  String get everyOrderYouvePlacedWithLive =>
      'Every order you\'ve placed, with live status as it moves through production.';

  @override
  String get searchYourOrders => 'Search your orders';

  @override
  String get couldntLoadOrders => 'Couldn\'t load orders';

  @override
  String get noOrdersYet => 'No orders yet';

  @override
  String get noMatches => 'No matches';

  @override
  String get ordersYouPlaceFromTheCatalog =>
      'Orders you place from the catalog will show up here with live status.';

  @override
  String get tryADifferentSearchTerm => 'Try a different search term.';

  @override
  String get orderDetails => 'Order details';

  @override
  String get orderNotFound => 'Order not found';

  @override
  String get itMayHaveBeenRemoved => 'It may have been removed.';

  @override
  String get paymentReceivedThankYou => 'Payment received — thank you!';

  @override
  String get confirmingYourPaymentWithTheProvider =>
      'Confirming your payment with the provider… this page updates automatically.';

  @override
  String get paymentCancelledYouCanTryAgain =>
      'Payment cancelled. You can try again below.';

  @override
  String get thePaymentDidntGoThroughYou =>
      'The payment didn\'t go through. You can try again below.';

  @override
  String get nothingToReorderQuotedItemsNeed =>
      'Nothing to reorder — quoted items need a new quote.';

  @override
  String addedItemSToYourCart(Object added) {
    return 'Added $added item(s) to your cart. Prices are updated at checkout.';
  }

  @override
  String get cancelThisOrder => 'Cancel this order?';

  @override
  String get thisCantBeUndone => 'This can\'t be undone.';

  @override
  String get keepOrder => 'Keep order';

  @override
  String couldntCancel(Object error) {
    return 'Couldn\'t cancel: $error';
  }

  @override
  String get thisPackageDoesntListSpecificCatalog =>
      'This package doesn\'t list specific catalog items yet.';

  @override
  String includesCatalogItemS(Object count) {
    return 'Includes $count catalog item(s).';
  }

  @override
  String signInOrCreateAnAccount2(Object package) {
    return 'Sign in or create an account to order \"$package\".';
  }

  @override
  String addedToCart2(Object package) {
    return '\"$package\" added to cart';
  }

  @override
  String get customiseItRequestAQuote => 'Customise it — request a quote';

  @override
  String get seasonalPackages => 'Seasonal packages';

  @override
  String get curatedBundlesForCampaignsAndSeasons =>
      'Curated bundles for campaigns and seasons — Valentine\'s, elections, and more.';

  @override
  String get searchPackagesEGValentines =>
      'Search packages, e.g. \"valentines\"';

  @override
  String get couldntLoadPackages => 'Couldn\'t load packages';

  @override
  String get noPackagesYet => 'No packages yet';

  @override
  String get seasonalPackagesSetUpByThe =>
      'Seasonal packages set up by the System Manager will appear here live.';

  @override
  String get filtersUpdated => 'Filters updated.';

  @override
  String couldntReachTheAiAssistant(Object error) {
    return 'Couldn\'t reach the AI assistant: $error';
  }

  @override
  String get askWhatYouNeed => 'Ask what you need';

  @override
  String get describeTheOccasionOrItemIn =>
      'Describe the occasion or item in your own words — e.g. \"something for a corporate summer picnic, 60 people\" — and we\'ll set the right filters.';

  @override
  String get whatAreYouBrandingAndFor => 'What are you branding, and for what?';

  @override
  String get ask => 'Ask';

  @override
  String order(Object displayNumber) {
    return 'Order $displayNumber';
  }

  @override
  String itemS(Object itemCount, Object amount) {
    return '$itemCount item(s) · $amount';
  }

  @override
  String get backToHome => 'Back to home';

  @override
  String starsFromReviews(Object avg, Object count) {
    return '$avg stars from $count reviews';
  }

  @override
  String get removeFromWishlist => 'Remove from wishlist';

  @override
  String get saveToWishlist => 'Save to wishlist';

  @override
  String signInToSaveToYour(Object itemName) {
    return 'Sign in to save \"$itemName\" to your wishlist.';
  }

  @override
  String get clearSearch => 'Clear search';

  @override
  String items2(Object category, Object count) {
    return '$category, $count items';
  }

  @override
  String items3(Object count, Object amount) {
    return '$count items · $amount';
  }

  @override
  String get oneSystemForOrdersProductionDelivery =>
      'One system for orders, production, delivery and the numbers behind every cap, hoodie and campaign package.';

  @override
  String somethingWentWrong(Object code) {
    return 'Something went wrong ($code).';
  }

  @override
  String get enterYourEmailAboveFirstThen =>
      'Enter your email above first, then tap \"Forgot password?\".';

  @override
  String ifAnAccountExistsForA(Object email) {
    return 'If an account exists for $email, a reset link is on its way. Check your inbox and spam folder.';
  }

  @override
  String get pleaseAcceptTheTermsAndPrivacy =>
      'Please accept the Terms and Privacy Policy to continue.';

  @override
  String get createYourAccount => 'Create your account';

  @override
  String get signIn => 'Sign in';

  @override
  String get accessYourBrightbrushCreationsWorkspace =>
      'Access your BrightBrush Creations workspace.';

  @override
  String get fullName => 'Full name';

  @override
  String get email => 'Email';

  @override
  String get enterAValidEmail => 'Enter a valid email';

  @override
  String get password => 'Password';

  @override
  String get atLeast6Characters => 'At least 6 characters';

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String get iAgreeToThe => 'I agree to the ';

  @override
  String get terms => 'Terms';

  @override
  String get and => ' and ';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get createAccount => 'Create account';

  @override
  String get alreadyHaveAnAccountSignIn => 'Already have an account? Sign in';

  @override
  String get dontHaveAnAccountSignUp => 'Don\'t have an account? Sign up';

  @override
  String get signingUpHereAlwaysCreatesA =>
      'Signing up here always creates a plain User account. Every other role is assigned afterward by an Admin/CEO or Developer.';

  @override
  String verificationEmailSentTo(Object email) {
    return 'Verification email sent to $email.';
  }

  @override
  String get emailVerifiedThankYou => 'Email verified — thank you!';

  @override
  String get notVerifiedYetCheckYourInbox =>
      'Not verified yet. Check your inbox (and spam folder).';

  @override
  String verifyYourEmailSoWeCan(Object email) {
    return 'Verify your email ($email) so we can send receipts and order updates.';
  }

  @override
  String get sendLink => 'Send link';

  @override
  String get iveVerified => 'I\'ve verified';

  @override
  String get privacyPolicy2 => 'Privacy policy';

  @override
  String get termsOfService => 'Terms of service';

  @override
  String get deleteMyAccount => 'Delete my account';

  @override
  String get permanentlyRemovesYourProfileCartAnd =>
      'Permanently removes your profile, cart and quotes.';

  @override
  String get thatPasswordIsIncorrect => 'That password is incorrect.';

  @override
  String get couldntConfirmYourIdentity => 'Couldn\'t confirm your identity.';

  @override
  String get deleteYourAccount => 'Delete your account?';

  @override
  String get thisPermanentlyDeletesYourLoginProfile =>
      'This permanently deletes your login, profile, cart and quote requests. Past orders are kept anonymised for our tax records. You can\'t delete your account while an order is still in progress.';

  @override
  String get yourPassword => 'Your password';

  @override
  String get typeDeleteToConfirm => 'Type DELETE to confirm';

  @override
  String get keepMyAccount => 'Keep my account';

  @override
  String get deleteForever => 'Delete forever';

  @override
  String get chatWithCustomer => 'Chat with customer';

  @override
  String get filesMustBeUnder10Mb => 'Files must be under 10 MB.';

  @override
  String messages(Object orderLabel) {
    return 'Messages · $orderLabel';
  }

  @override
  String get noMessagesYet => 'No messages yet.';

  @override
  String get questionsAboutSizesPlacementOrDelivery =>
      'Questions about sizes, placement or delivery? Send us a message.';

  @override
  String get attachPhotoOrPdf => 'Attach photo or PDF';

  @override
  String get writeAMessage => 'Write a message';

  @override
  String get customise => 'Customise';

  @override
  String customise2(Object item) {
    return 'Customise $item';
  }

  @override
  String get itemNotAvailable => 'Item not available';

  @override
  String get itMayHaveBeenRemovedFrom =>
      'It may have been removed from the catalog.';

  @override
  String get notCustomisable => 'Not customisable';

  @override
  String get thisItemIsSoldAsIs =>
      'This item is sold as-is. Add it from its page.';

  @override
  String get signInToUploadYourLogo =>
      'Sign in to upload your logo and save it to your library.';

  @override
  String get signInOrCreateAnAccount3 =>
      'Sign in or create an account to add this to your cart.';

  @override
  String get cartUpdated => 'Cart updated';

  @override
  String addedToYourCart(Object item) {
    return '$item added to your cart';
  }

  @override
  String get colour => 'Colour';

  @override
  String get pieces => 'Pieces';

  @override
  String get branding => 'Branding';

  @override
  String get addALogoOrTextAt => 'Add a logo or text at each placement';

  @override
  String get addAnotherPlacement => 'Add another placement';

  @override
  String get namesOptional => 'Names (optional)';

  @override
  String onePerLineEGStaff(Object amount) {
    return 'One per line, e.g. staff names — $amount per piece';
  }

  @override
  String pcsEach(Object quantity, Object amount) {
    return '$quantity pcs · $amount each';
  }

  @override
  String get updateCart => 'Update cart';

  @override
  String get removePlacement => 'Remove placement';

  @override
  String get uploadChooseLogo => 'Upload / choose logo';

  @override
  String get removeLogo => 'Remove logo';

  @override
  String get alreadyDigitizedNoDigitizingFee =>
      'Already digitized — no digitizing fee.';

  @override
  String get orTextToPrintStitch => 'Or text to print/stitch';

  @override
  String get extraTextOptional => 'Extra text (optional)';

  @override
  String get threadColoursCommaSeparated => 'Thread colours (comma separated)';

  @override
  String get eGWhiteGold => 'e.g. White, Gold';

  @override
  String brandingPerPiece(Object amount) {
    return 'Branding ($amount per piece)';
  }

  @override
  String get oneOffSetupDigitizing => 'One-off setup / digitizing';

  @override
  String get names => 'Names';

  @override
  String get itemTotal => 'Item total';

  @override
  String get deliveryAndVatAreAddedAt =>
      'Delivery and VAT are added at checkout. You\'ll approve a digital proof before we produce anything.';

  @override
  String addedToYourLibrary(Object art) {
    return '\"$art\" added to your library';
  }

  @override
  String uploadFailed(Object error) {
    return 'Upload failed: $error';
  }

  @override
  String get notDigitizedYet => 'Not digitized yet';

  @override
  String get rename => 'Rename';

  @override
  String get deleteFromLibrary => 'Delete from library';

  @override
  String get pastOrdersKeepTheirCopy => 'Past orders keep their copy.';

  @override
  String get renameArtwork => 'Rename artwork';

  @override
  String get deleted => 'Deleted';

  @override
  String get myArtwork => 'My artwork';

  @override
  String get uploadLogo => 'Upload logo';

  @override
  String get couldntLoadYourArtwork => 'Couldn\'t load your artwork';

  @override
  String get noArtworkYet => 'No artwork yet';

  @override
  String get uploadYourLogoOnceAndReuse =>
      'Upload your logo once and reuse it on caps, shirts, bottles and more.';

  @override
  String get thatFileIsOver25Mb =>
      'That file is over 25 MB. Please upload a smaller one.';

  @override
  String get chooseYourArtwork => 'Choose your artwork';

  @override
  String get pngWithATransparentBackgroundGives =>
      'PNG with a transparent background gives the best mockup. Vector files (SVG, AI, EPS, PDF) are welcome for production.';

  @override
  String get uploadNewArtwork => 'Upload new artwork';

  @override
  String get yourLibrary => 'Your library';

  @override
  String get digitizedNoSetupFeeForEmbroidery =>
      'Digitized — no setup fee for embroidery';

  @override
  String pcs2(Object e) {
    return '$e pcs';
  }

  @override
  String get dragADesignToAdjustIts =>
      'Drag a design to adjust its position. Final placement is confirmed on your proof.';

  @override
  String get logo => 'Logo';

  @override
  String get yourDesign => 'Your design';

  @override
  String get tellUsWhatYoudLikeChanged => 'Tell us what you\'d like changed.';

  @override
  String get approvedProductionCanBegin => 'Approved — production can begin.';

  @override
  String get thanksWellSendARevisedProof =>
      'Thanks — we\'ll send a revised proof.';

  @override
  String get designProof => 'Design proof';

  @override
  String get ourDesignersArePreparingADigital =>
      'Our designers are preparing a digital proof of your branding. You\'ll approve it here before anything is produced.';

  @override
  String version(Object version, Object proofStatus) {
    return 'Version $version · $proofStatus';
  }

  @override
  String stitches(Object amount) {
    return '$amount stitches';
  }

  @override
  String get commentsRequiredToRequestChanges =>
      'Comments (required to request changes)';

  @override
  String get approveProof => 'Approve proof';

  @override
  String get requestChanges => 'Request changes';

  @override
  String yourComment(Object customerComment) {
    return 'Your comment: $customerComment';
  }

  @override
  String earlierVersions(Object length) {
    return 'Earlier versions ($length)';
  }

  @override
  String version2(Object version, Object status) {
    return 'Version $version · $status';
  }

  @override
  String get proofSentToTheCustomer => 'Proof sent to the customer';

  @override
  String proof(Object displayNumber) {
    return 'Proof · $displayNumber';
  }

  @override
  String status(Object proofStatus) {
    return 'Status: $proofStatus';
  }

  @override
  String customer(Object customerComment) {
    return 'Customer: $customerComment';
  }

  @override
  String get sendANewVersion => 'Send a new version';

  @override
  String get addMockupStitchOutPhotos => 'Add mockup / stitch-out photos';

  @override
  String get stitchCountEmbroideryOptional =>
      'Stitch count (embroidery, optional)';

  @override
  String get noteToCustomerSizesThreadColours =>
      'Note to customer (sizes, thread colours, placement)';

  @override
  String get close => 'Close';

  @override
  String get sendProof => 'Send proof';

  @override
  String get newRequest => 'New request';

  @override
  String get couldntLoadYourQuotes => 'Couldn\'t load your quotes';

  @override
  String get noQuoteRequestsYet => 'No quote requests yet';

  @override
  String get needACustomJobABig =>
      'Need a custom job, a big quantity or a package tailored to you? Request a quote.';

  @override
  String get turnDownThisPrice => 'Turn down this price?';

  @override
  String get withdrawThisRequest => 'Withdraw this request?';

  @override
  String get keep => 'Keep';

  @override
  String get turnDown => 'Turn down';

  @override
  String get withdraw => 'Withdraw';

  @override
  String get expired => 'Expired';

  @override
  String pcsRequested(Object quantity, Object amount) {
    return '$quantity pcs · requested $amount';
  }

  @override
  String get quotedPrice => 'Quoted price';

  @override
  String validUntilIncludesDelivery(Object amount) {
    return 'Valid until $amount · includes delivery';
  }

  @override
  String get acceptOrder => 'Accept & order';

  @override
  String get quotePdf => 'Quote PDF';

  @override
  String get viewOrder => 'View order';

  @override
  String get acceptQuote => 'Accept quote';

  @override
  String get enterAName => 'Enter a name';

  @override
  String get enterAnAddress => 'Enter an address';

  @override
  String get notesOptional => 'Notes (optional)';

  @override
  String totalPayNow(Object amount, Object amount2) {
    return 'Total $amount · pay $amount2 now';
  }

  @override
  String total2(Object amount) {
    return 'Total $amount';
  }

  @override
  String get signInOrCreateAnAccount4 =>
      'Sign in or create an account to request a quote.';

  @override
  String get quoteRequestSentWellPriceIt =>
      'Quote request sent — we\'ll price it and notify you under My Quotes.';

  @override
  String get view => 'View';

  @override
  String couldntSendRequest(Object error) {
    return 'Couldn\'t send request: $error';
  }

  @override
  String get tellUsWhatYouNeedAnd =>
      'Tell us what you need and we\'ll send you a price.';

  @override
  String get whatDoYouNeed => 'What do you need?';

  @override
  String get eG200EmbroideredPoloShirts => 'e.g. 200 embroidered polo shirts';

  @override
  String get describeTheItem => 'Describe the item';

  @override
  String get details => 'Details';

  @override
  String get logoPlacementColoursSizesDeadlineDelivery =>
      'Logo placement, colours, sizes, deadline, delivery location…';

  @override
  String get sendRequest => 'Send request';

  @override
  String get accountDiscount2 => 'Account discount';

  @override
  String delivery2(Object deliveryZoneName) {
    return 'Delivery ($deliveryZoneName)';
  }

  @override
  String get storePickup => 'Store pickup';

  @override
  String includesVat2(Object vatPercent) {
    return 'Includes VAT ($vatPercent%)';
  }

  @override
  String vat2(Object vatPercent) {
    return 'VAT ($vatPercent%)';
  }

  @override
  String get paid => 'Paid';

  @override
  String get refunded => 'Refunded';

  @override
  String get cancellationFeeKept => 'Cancellation fee kept';

  @override
  String get balanceDue => 'Balance due';

  @override
  String get depositReceivedProductionCanStart =>
      'Deposit received — production can start.';

  @override
  String depositOfDueBeforeProductionStarts(Object amount) {
    return 'Deposit of $amount due before production starts.';
  }

  @override
  String get couldntOpenThePaymentPage => 'Couldn\'t open the payment page.';

  @override
  String get onlinePaymentIsntAvailableYetWell =>
      'Online payment isn\'t available yet. We\'ll send you an invoice with payment details.';

  @override
  String deposit2(Object amount) {
    return 'Deposit $amount';
  }

  @override
  String full(Object amount) {
    return 'Full $amount';
  }

  @override
  String get mPesaPhoneNumber => 'M-Pesa phone number';

  @override
  String get testModeNoRealMoneyWill =>
      'Test mode — no real money will be charged.';

  @override
  String ref(Object receipt) {
    return 'Ref: $receipt';
  }

  @override
  String charged(Object chargedCurrency, Object chargedAmount) {
    return 'Charged $chargedCurrency $chargedAmount';
  }

  @override
  String get checkStatus => 'Check status';

  @override
  String get checkYourPhone => 'Check your phone';

  @override
  String get paymentReceived => 'Payment received';

  @override
  String get paymentFailed => 'Payment failed';

  @override
  String get paymentCancelled => 'Payment cancelled';

  @override
  String amount(Object message, Object amount) {
    return '$message\n\nAmount: $amount';
  }

  @override
  String get thePaymentDidNotGoThrough => 'The payment did not go through.';

  @override
  String get ivePaidCheck => 'I\'ve paid — check';

  @override
  String get done => 'Done';

  @override
  String getYourCustomBrandingFromUse(
    Object context,
    Object code,
    Object referralBonusPoints,
    Object base,
  ) {
    return 'Get your custom branding from $context! Use my code $code when you sign up and we both get $referralBonusPoints points after your first order. $base';
  }

  @override
  String get enterAFriendsCode => 'Enter a friend\'s code';

  @override
  String get onlyBeforeYourFirstOrder => 'Only before your first order.';

  @override
  String get codeAppliedYoullBothGetBonus =>
      'Code applied — you\'ll both get bonus points after your first order.';

  @override
  String pts(Object points) {
    return '$points pts';
  }

  @override
  String worthOffYouEarnPointS(Object amount, Object pointsPerHundred) {
    return 'Worth $amount off. You earn $pointsPerHundred point(s) for every KES 100 you spend.';
  }

  @override
  String referAFriendPtsEach(Object referralBonusPoints) {
    return 'Refer a friend (+$referralBonusPoints pts each)';
  }

  @override
  String get iHaveACode => 'I have a code';

  @override
  String get copy => 'Copy';

  @override
  String get copied => 'Copied';

  @override
  String get share => 'Share';

  @override
  String get thanksForYourReview => 'Thanks for your review';

  @override
  String get rateYourOrder => 'Rate your order';

  @override
  String get qualityFitDeliveryAnythingToShare =>
      'Quality, fit, delivery… anything to share?';

  @override
  String photos4(Object count) {
    return 'Photos ($count/4)';
  }

  @override
  String get reviewsAppearPubliclyAfterAQuick =>
      'Reviews appear publicly after a quick check.';

  @override
  String get submit => 'Submit';

  @override
  String get reviews => 'Reviews';

  @override
  String get nothingSavedYet => 'Nothing saved yet';

  @override
  String get tapTheHeartOnAnyItem =>
      'Tap the heart on any item to save it for later.';

  @override
  String get brandingWeveProducedForSchoolsCompanies =>
      'Branding we\'ve produced for schools, companies, events and teams.';

  @override
  String get comingSoon => 'Coming soon';

  @override
  String get ourGalleryOfRecentJobsWill =>
      'Our gallery of recent jobs will appear here.';

  @override
  String get portfolio => 'Portfolio';

  @override
  String get noReviewsYet => 'No reviews yet';

  @override
  String get customersAreAskedToReviewEach =>
      'Customers are asked to review each completed order.';

  @override
  String reply(Object reply) {
    return 'Reply: $reply';
  }

  @override
  String get publicReply => 'Public reply';

  @override
  String get approvePublish => 'Approve (publish)';

  @override
  String get hide => 'Hide';

  @override
  String get replyPublicly => 'Reply publicly';

  @override
  String newPortfolioEntryPhotoS(Object count) {
    return 'New portfolio entry ($count photo(s))';
  }

  @override
  String get title => 'Title';

  @override
  String get description => 'Description';

  @override
  String get tagsCommaSeparated => 'Tags (comma separated)';

  @override
  String get publish => 'Publish';

  @override
  String get addWork => 'Add work';

  @override
  String get unfeature => 'Unfeature';

  @override
  String get feature => 'Feature';

  @override
  String get delete => 'Delete';

  @override
  String get dropAPinOnYourDelivery => 'Drop a pin on your delivery point';

  @override
  String get useThisSpot => 'Use this spot';

  @override
  String uniforms(Object company) {
    return '$company uniforms';
  }

  @override
  String get approvedBrandedItemsForYourTeam =>
      'Approved branded items for your team — just choose sizes.';

  @override
  String get newCompany => 'New company';

  @override
  String get couldntLoadCompanies => 'Couldn\'t load companies';

  @override
  String get noCompaniesYet => 'No companies yet';

  @override
  String get groupBuyersFromTheSameOrganisation =>
      'Group buyers from the same organisation: shared discount, credit and uniform programs.';

  @override
  String buyerS(Object count) {
    return '$count buyer(s)';
  }

  @override
  String off(Object discountPercent) {
    return '$discountPercent% off';
  }

  @override
  String get editCompanyBuyers => 'Edit company & buyers';

  @override
  String get newUniformProgram => 'New uniform program';

  @override
  String edit2(Object existing) {
    return 'Edit $existing';
  }

  @override
  String get companyName => 'Company name';

  @override
  String get kraPinForInvoicesEtims => 'KRA PIN (for invoices / eTIMS)';

  @override
  String get discountForAllBuyers => 'Discount for all buyers (%)';

  @override
  String get creditTerms => 'Credit terms';

  @override
  String get paymentTermsDays => 'Payment terms (days)';

  @override
  String get companyCreditLimitKes0None =>
      'Company credit limit (KES, 0 = none)';

  @override
  String buyers(Object count) {
    return 'Buyers ($count)';
  }

  @override
  String get findCustomersByNameOrEmail => 'Find customers by name or email';

  @override
  String get editProgram => 'Edit program';

  @override
  String get programName => 'Program name';

  @override
  String get eG2027StaffUniforms => 'e.g. 2027 staff uniforms';

  @override
  String get notesForBuyers => 'Notes for buyers';

  @override
  String get active => 'Active';

  @override
  String get itemsComeFromCustomisedOrdersThis =>
      'Items come from customised orders this company has placed. Once a buyer orders a branded item, it can be added here.';

  @override
  String from2(Object c, Object order) {
    return '$c (from $order)';
  }

  @override
  String get addFromAPastOrder => 'Add from a past order';

  @override
  String get saved => 'Saved';

  @override
  String get loyaltyReferrals => 'Loyalty & referrals';

  @override
  String get loyaltyProgrammeOn => 'Loyalty programme on';

  @override
  String get pointsPerKes100Spent => 'Points per KES 100 spent';

  @override
  String get kesValueOf1Point => 'KES value of 1 point';

  @override
  String get referralBonusPointsEach => 'Referral bonus (points each)';

  @override
  String get maxOfAnOrderPaidWith => 'Max % of an order paid with points';

  @override
  String get displayCurrencies => 'Display currencies';

  @override
  String get kesPer1UnitCustomersCan =>
      'KES per 1 unit. Customers can see approximate prices in these; everything is still charged in KES.';

  @override
  String kesPer1(Object c) {
    return 'KES per 1 $c';
  }

  @override
  String get saveLoyaltyCurrencies => 'Save loyalty & currencies';

  @override
  String get alsoShowPricesIn => 'Also show prices in';

  @override
  String get approximateOnlyYouPayInKes => 'Approximate only — you pay in KES.';

  @override
  String get kesOnly => 'KES only';

  @override
  String get couldntLoadNotifications => 'Couldn\'t load notifications';

  @override
  String unread(Object count) {
    return '$count unread';
  }

  @override
  String get notificationSettings => 'Notification settings';

  @override
  String get orderUpdatesProofsPaymentsAndMessages =>
      'Order updates, proofs, payments and messages will appear here.';

  @override
  String get getAlertsOnThisDevice => 'Get alerts on this device';

  @override
  String get orderUpdatesAndMessagesEvenWhen =>
      'Order updates and messages, even when the app is closed.';

  @override
  String get alertsSwitchedOnForThisDevice =>
      'Alerts switched on for this device';

  @override
  String get couldntSwitchOnAlertsCheckYour =>
      'Couldn\'t switch on alerts — check your browser/phone notification permission.';

  @override
  String get turnOn => 'Turn on';

  @override
  String get howShouldWeReachYou => 'How should we reach you?';

  @override
  String get theInAppInboxAlwaysGets =>
      'The in-app inbox always gets everything.';

  @override
  String get pushNotifications => 'Push notifications';

  @override
  String get usesThePhoneNumberOnYour =>
      'Uses the phone number on your profile';

  @override
  String get remindersOffers => 'Reminders & offers';

  @override
  String get cartRemindersAndPromotions => 'Cart reminders and promotions';

  @override
  String get notificationChannelsSaved => 'Notification channels saved';

  @override
  String get testSentCheckYourInboxEmail =>
      'Test sent — check your inbox, email and WhatsApp.';

  @override
  String couldntLoadNotificationSettings(Object error) {
    return 'Couldn\'t load notification settings: $error';
  }

  @override
  String get inAppAndPushNotificationsWork =>
      'In-app and push notifications work out of the box. Add email and WhatsApp below; customers choose their channels in their inbox.';

  @override
  String get emailProvider => 'Email provider';

  @override
  String get fromAddress => 'From address';

  @override
  String get mustBeASenderDomainVerified =>
      'Must be a sender/domain verified with the provider.';

  @override
  String get apiKey => 'API key';

  @override
  String get whatsappMetaCloudApi => 'WhatsApp (Meta Cloud API)';

  @override
  String get phoneNumberId => 'Phone number ID';

  @override
  String get metaForDevelopersWhatsappApiSetup =>
      'Meta for Developers → WhatsApp → API Setup';

  @override
  String get permanentAccessToken => 'Permanent access token';

  @override
  String get createASystemUserTokenWith =>
      'Create a System User token with whatsapp_business_messaging.';

  @override
  String get templateName => 'Template name';

  @override
  String get templateLanguageCode => 'Template language code';

  @override
  String get sendMeATest => 'Send me a test';

  @override
  String get settings => 'Settings';

  @override
  String get appearance => 'Appearance';

  @override
  String get theme => 'Theme';

  @override
  String get followYourDeviceOrLockIt =>
      'Follow your device, or lock it to light or dark.';

  @override
  String get system => 'System';

  @override
  String get light => 'Light';

  @override
  String get dark => 'Dark';

  @override
  String get font => 'Font';

  @override
  String get pickWhicheverReadsBestToYou =>
      'Pick whichever reads best to you — applies everywhere, instantly.';

  @override
  String get accessibility => 'Accessibility';

  @override
  String get textSize => 'Text size';

  @override
  String get appliesAcrossTheWholeAppIndependent =>
      'Applies across the whole app, independent of your device\'s own text size.';

  @override
  String get reduceMotion => 'Reduce motion';

  @override
  String get skipEntranceStaggerAnimationsOnLists =>
      'Skip entrance/stagger animations on lists and grids.';

  @override
  String get inAppNotifications => 'In-app notifications';

  @override
  String get showTheAnnouncementBannerOnHome =>
      'Show the announcement banner on Home. This doesn\'t send push alerts.';

  @override
  String get languageCurrency => 'Language & currency';

  @override
  String get aboutSupport => 'About & support';

  @override
  String get contactSupport => 'Contact support';

  @override
  String get getHelpWithAnOrderA =>
      'Get help with an order, a design, or anything else.';

  @override
  String get loadingVersion => 'Loading version…';

  @override
  String version3(Object version, Object buildNumber) {
    return 'Version $version ($buildNumber)';
  }

  @override
  String get answer => 'Answer';

  @override
  String get savedAnswerShownWhileOffline =>
      'Saved answer — shown while offline';

  @override
  String get gotIt => 'Got it';

  @override
  String get nothingHereYet => 'Nothing here yet';

  @override
  String get askAQuestionBelowAndThe =>
      'Ask a question below and the assistant will help.';

  @override
  String get tryADifferentSearchOrAsk =>
      'Try a different search, or ask below.';

  @override
  String get guide => 'Guide';

  @override
  String get answersForWhatYouCanDo =>
      'Answers for what you can do here — search below, or ask your own question.';

  @override
  String get searchQuestionsEGAssignOrder =>
      'Search questions, e.g. \"assign order\"';

  @override
  String get couldntLoadTheGuide => 'Couldn\'t load the guide';

  @override
  String get youreOfflineShowingSavedAnswersAsking =>
      'You\'re offline — showing saved answers. Asking something new needs a connection.';

  @override
  String get askSomethingElseNeedsInternet =>
      'Ask something else — needs internet';

  @override
  String get typeYourQuestion => 'Type your question…';

  @override
  String get switchViewDeveloper => 'Switch view (Developer)';

  @override
  String get signOut => 'Sign out';

  @override
  String get createAnAccountToContinue => 'Create an account to continue';

  @override
  String get signInOrCreateAccount => 'Sign in or create account';

  @override
  String get orderStatusCancelled => 'Order status: cancelled';

  @override
  String orderStatusStepOf(Object context, Object currentIndex, Object count) {
    return 'Order status: $context, step $currentIndex of $count';
  }

  @override
  String couldntUploadPhoto(Object error) {
    return 'Couldn\'t upload photo: $error';
  }

  @override
  String get profileUpdated => 'Profile updated';

  @override
  String couldntSave(Object error) {
    return 'Couldn\'t save: $error';
  }

  @override
  String get couldntLoadYourProfile => 'Couldn\'t load your profile';

  @override
  String get noProfileFound => 'No profile found';

  @override
  String get signInAgainToLoadYour =>
      'Sign in again to load your account details.';

  @override
  String get yourAccountDetails => 'Your account details.';

  @override
  String get displayName => 'Display name';

  @override
  String get required => 'Required';

  @override
  String get phoneOptional => 'Phone (optional)';

  @override
  String get vehiclePlateOptional => 'Vehicle plate (optional)';

  @override
  String get availableForDeliveries => 'Available for deliveries';

  @override
  String dailyWageDaySetByAdmin(Object amount) {
    return 'Daily wage: $amount/day (set by Admin)';
  }

  @override
  String get saveChanges => 'Save changes';

  @override
  String get security => 'Security';

  @override
  String get changePassword => 'Change password';

  @override
  String get yourSavedLogosForBrandingOrders =>
      'Your saved logos for branding orders';

  @override
  String get passwordChanged => 'Password changed';

  @override
  String get couldntChangePassword => 'Couldn\'t change password';

  @override
  String get currentPassword => 'Current password';

  @override
  String get newPassword => 'New password';

  @override
  String locatingMoreStopS(Object count) {
    return 'Locating $count more stop(s)…';
  }

  @override
  String stops(Object count) {
    return 'Stops ($count)';
  }

  @override
  String get pageNotFound => 'Page not found';

  @override
  String get thatLinkDoesntLeadAnywhereIn =>
      'That link doesn\'t lead anywhere in BrightBrush.';

  @override
  String get goHome => 'Go home';

  @override
  String get noValidWhatsappNumberForThis =>
      'No valid WhatsApp number for this contact.';

  @override
  String get couldntOpenWhatsappOnThisDevice =>
      'Couldn\'t open WhatsApp on this device.';

  @override
  String get auto => 'Auto';

  @override
  String get browsingAsGuest => 'Browsing as guest';

  @override
  String developerView(Object role) {
    return '$role · Developer view';
  }

  @override
  String invoiceNothingNow(Object account, Object days) {
    return 'Nothing to pay now — we\'ll invoice $account, due in $days days.';
  }

  @override
  String get yourAccount => 'your account';

  @override
  String volumePricing(Object tiers) {
    return 'Volume pricing: $tiers';
  }

  @override
  String tierPcs(Object minQty, Object price) {
    return '$minQty+ pcs $price';
  }

  @override
  String piecesCount(Object quantity) {
    return '$quantity pcs';
  }

  @override
  String inclSetup(Object amount) {
    return ' · incl. $amount setup';
  }

  @override
  String minimumPcs(Object moq) {
    return 'Minimum $moq pcs';
  }

  @override
  String tierAt(Object minQty, Object price) {
    return '$minQty+ @ $price';
  }

  @override
  String blanksLine(Object quantity, Object price, Object surcharges) {
    return 'Blanks ($quantity × $price$surcharges)';
  }

  @override
  String get plusSizeSurcharges => ' + size surcharges';

  @override
  String get digitized => 'Digitized';

  @override
  String stitchesSuffix(Object count) {
    return ' · $count stitches';
  }

  @override
  String threadsList(Object colours) {
    return 'threads $colours';
  }

  @override
  String namesList(Object count, Object names) {
    return 'Names ($count): $names';
  }

  @override
  String overdueWasDue(Object date) {
    return 'Overdue — was due $date';
  }

  @override
  String onAccountDue(Object date) {
    return 'On account · due $date';
  }

  @override
  String thankYouReceived(Object amount, Object reference) {
    return 'Thank you! $amount received$reference.';
  }

  @override
  String mpesaRefSuffix(Object receipt) {
    return ' (M-Pesa ref $receipt)';
  }

  @override
  String photosCount(Object count) {
    return '$count photo(s)';
  }

  @override
  String get featuredSuffix => ' · featured';

  @override
  String memberSince(Object date) {
    return 'Member since $date';
  }
}
