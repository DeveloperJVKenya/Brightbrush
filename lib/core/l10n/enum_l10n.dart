import 'package:flutter/widgets.dart';

import '../auth/app_role.dart';

import '../../features/catalog/domain/catalog_category.dart';
import '../../features/customization/domain/customization_options.dart';
import '../../features/orders/domain/order_status.dart';
import '../../features/payments/domain/payment_models.dart';
import '../../features/quotes/domain/quote_request.dart';
import '../../features/support/domain/support_ticket.dart';

/// Kiswahili names for the fixed choices the app shows (categories,
/// statuses, decoration methods, placements). The English names live on the
/// enums themselves; `.tr(context)` returns the one for the app language.
/// (Order statuses use `localized(context)` in language.dart.)
bool _isSw(BuildContext context) =>
    Localizations.localeOf(context).languageCode == 'sw';

extension CatalogCategoryL10n on CatalogCategory {
  /// Kiswahili name.
  String get sw => switch (this) {
    CatalogCategory.caps => 'Kofia',
    CatalogCategory.tshirts => 'Fulana',
    CatalogCategory.hoodies => 'Hoodie',
    CatalogCategory.twoPiece => 'Seti za vipande viwili',
    CatalogCategory.waterBottles => 'Chupa za maji',
    CatalogCategory.cutlery => 'Vyombo vya kulia',
    CatalogCategory.embroidery => 'Ushonaji wa nembo',
    CatalogCategory.other => 'Nyingine',
  };

  String tr(BuildContext context) => _isSw(context) ? sw : label;
}

extension DecorationMethodL10n on DecorationMethod {
  /// Kiswahili name.
  String get sw => switch (this) {
    DecorationMethod.embroidery => 'Ushonaji wa nembo',
    DecorationMethod.screenPrint => 'Uchapishaji wa skrini',
    DecorationMethod.dtf => 'Uchapishaji wa DTF',
    DecorationMethod.heatTransfer => 'Uhamishaji kwa joto',
    DecorationMethod.sublimation => 'Usablimishaji',
    DecorationMethod.laserEngraving => 'Uchoraji kwa leza',
  };

  String tr(BuildContext context) => _isSw(context) ? sw : label;

  String trDescription(BuildContext context) => !_isSw(context)
      ? description
      : switch (this) {
          DecorationMethod.embroidery =>
            'Nembo ya kushonwa kwa uzi — hudumu, na mwonekano wa hadhi.',
          DecorationMethod.screenPrint =>
            'Thamani bora kwa idadi kubwa ya michoro rahisi.',
          DecorationMethod.dtf =>
            'Picha za rangi kamili, picha halisi na mchanganyiko wa rangi.',
          DecorationMethod.heatTransfer => 'Majina na namba za vinyl.',
          DecorationMethod.sublimation =>
            'Rangi kila mahali kwenye polyester na vikombe.',
          DecorationMethod.laserEngraving =>
            'Alama za kudumu kwenye chupa na vyombo vya kulia.',
        };
}

extension PlacementL10n on Placement {
  /// Kiswahili name.
  String get sw => switch (this) {
    Placement.leftChest => 'Kifua cha kushoto',
    Placement.rightChest => 'Kifua cha kulia',
    Placement.centerChest => 'Katikati ya kifua',
    Placement.fullFront => 'Mbele yote',
    Placement.upperBack => 'Juu ya mgongo',
    Placement.fullBack => 'Mgongo wote',
    Placement.leftSleeve => 'Mkono wa kushoto',
    Placement.rightSleeve => 'Mkono wa kulia',
    Placement.capFront => 'Mbele ya kofia',
    Placement.capSide => 'Ubavuni mwa kofia',
    Placement.capBack => 'Nyuma ya kofia',
    Placement.productFront => 'Mbele',
    Placement.productBack => 'Nyuma',
    Placement.wrapAround => 'Kuzunguka',
  };

  String tr(BuildContext context) => _isSw(context) ? sw : label;
}

extension SizeClassL10n on SizeClass {
  /// Kiswahili name.
  String get sw => switch (this) {
    SizeClass.small => 'Ndogo',
    SizeClass.medium => 'Wastani',
    SizeClass.large => 'Kubwa',
  };

  String tr(BuildContext context) => _isSw(context) ? sw : label;

  String trHint(BuildContext context) => !_isSw(context)
      ? hint
      : switch (this) {
          SizeClass.small => 'hadi sm 10',
          SizeClass.medium => 'hadi sm 20',
          SizeClass.large => 'hadi sm 30',
        };
}

extension PaymentStatusL10n on PaymentStatus {
  /// Kiswahili name.
  String get sw => switch (this) {
    PaymentStatus.unpaid => 'Haijalipwa',
    PaymentStatus.invoiced => 'Ankara imetumwa',
    PaymentStatus.partiallyPaid => 'Imelipwa kiasi',
    PaymentStatus.paid => 'Imelipwa',
    PaymentStatus.partiallyRefunded => 'Imerejeshwa kiasi',
    PaymentStatus.refunded => 'Imerejeshwa',
  };

  String tr(BuildContext context) => _isSw(context) ? sw : label;
}

extension ProofStatusL10n on ProofStatus {
  /// Kiswahili name.
  String get sw => switch (this) {
    ProofStatus.notRequired => 'Sampuli haihitajiki',
    ProofStatus.required => 'Sampuli itatumwa',
    ProofStatus.pending => 'Inasubiri idhini yako',
    ProofStatus.approved => 'Sampuli imeidhinishwa',
    ProofStatus.changesRequested => 'Mabadiliko yameombwa',
  };

  String tr(BuildContext context) => _isSw(context) ? sw : label;
}

extension PaymentStateL10n on PaymentState {
  /// Kiswahili name.
  String get sw => switch (this) {
    PaymentState.pending => 'Inasubiri',
    PaymentState.succeeded => 'Imelipwa',
    PaymentState.failed => 'Imeshindwa',
    PaymentState.cancelled => 'Imeghairiwa',
  };

  String tr(BuildContext context) => _isSw(context) ? sw : label;
}

extension QuoteStatusL10n on QuoteStatus {
  /// Kiswahili name.
  String get sw => switch (this) {
    QuoteStatus.newRequest => 'Inasubiri bei',
    QuoteStatus.quoted => 'Bei iko tayari',
    QuoteStatus.accepted => 'Imekubaliwa',
    QuoteStatus.declined => 'Tumeikataa',
    QuoteStatus.rejected => 'Uliikataa',
    QuoteStatus.cancelled => 'Imeondolewa',
  };

  String tr(BuildContext context) => _isSw(context) ? sw : label;
}

extension TicketStatusL10n on TicketStatus {
  /// Kiswahili name.
  String get sw => switch (this) {
    TicketStatus.open => 'Wazi',
    TicketStatus.inProgress => 'Inashughulikiwa',
    TicketStatus.resolved => 'Imetatuliwa',
  };

  String tr(BuildContext context) => _isSw(context) ? sw : label;
}

extension AppRoleL10n on AppRole {
  /// Kiswahili name.
  String get sw => switch (this) {
    AppRole.user => 'Mtumiaji',
    AppRole.deliveryStaff => 'Mfanyakazi wa ufikishaji',
    AppRole.systemManager => 'Meneja wa mfumo',
    AppRole.admin => 'Msimamizi / Mkurugenzi',
    AppRole.developer => 'Msanidi',
  };

  String tr(BuildContext context) => _isSw(context) ? sw : label;
}

/// Hover/long-press descriptions of the customer menu (staff menus stay in
/// English). Null means "use the module's own description".
String? localizedModuleDescription(BuildContext context, String path) {
  if (!_isSw(context)) return null;
  return switch (path) {
    '/customer' =>
      'Tazama bidhaa za nembo — kofia, fulana, hoodie, seti za vipande viwili, chupa za maji, vyombo vya kulia na nyinginezo — pamoja na bei, kiwango cha chini na muda wa kuandaa.',
    '/customer/packages' =>
      'Vifurushi vya nembo vya msimu na kampeni vilivyoandaliwa na Meneja wa Mfumo.',
    '/customer/portfolio' =>
      'Kazi za nembo tulizotengeneza kwa shule, makampuni, hafla na timu.',
    '/customer/orders' =>
      'Weka oda kubwa au binafsi, na ufuatilie kila oda kuanzia idhini ya muundo, uzalishaji hadi kufikishwa.',
    '/customer/tracking' =>
      'Ramani ya moja kwa moja ya oda yako ikiwa njiani kufikishwa.',
    '/customer/cart' => 'Kagua bidhaa, chagua idadi na uthibitishe oda yako.',
    '/customer/notifications' =>
      'Mabadiliko ya hali ya oda, taarifa za ufikishaji na ofa za msimu.',
    '/customer/support' =>
      'Zungumza na BrightBrush kuhusu oda, muundo au malalamiko.',
    '/customer/profile' =>
      'Maelezo ya akaunti, anwani zilizohifadhiwa na historia ya oda.',
    _ => null,
  };
}
