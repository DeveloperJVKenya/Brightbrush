import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' show LatLng;
import '../../../core/monitoring/monitoring.dart';

import '../../../core/errors/user_facing_error.dart';
import '../../../core/firebase/firebase_providers.dart';
import '../../../core/formatting/currency.dart';
import '../../../core/logging/app_logger.dart';
import '../../../shared/widgets/catalog_image.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../catalog/application/catalog_providers.dart';
import '../../commerce/application/commerce_providers.dart';
import '../../commerce/data/commerce_repository.dart';
import '../../growth/growth_providers.dart';
import '../../growth/growth_settings.dart';
import '../../growth/map_pin_picker.dart';
import '../../customization/application/customization_providers.dart';
import '../../customization/domain/customization_pricing.dart';
import '../../customization/presentation/widgets/customization_summary.dart';
import '../../orders/application/orders_providers.dart';
import '../../payments/application/payments_providers.dart';
import '../../payments/domain/business_settings.dart';
import '../../../l10n/app_localizations.dart';
import '../application/cart_providers.dart';

/// One resolved cart row — a catalog item or a package — with what the
/// checkout needs to render and validate it. [available] is false when the
/// item was deactivated/deleted since it was added (the server would reject
/// the order, so the customer is asked to remove it first).
class _CartLine {
  const _CartLine({
    required this.key,
    required this.name,
    required this.unitPrice,
    required this.quantity,
    required this.minQuantity,
    required this.imageUrls,
    required this.icon,
    required this.isPackage,
    required this.available,
    this.custom,
    this.itemId,
    this.customTotal = 0,
    this.problem,
  });

  final String key;
  final String name;
  final num unitPrice;
  final int quantity;
  final int minQuantity;
  final List<String> imageUrls;
  final IconData icon;
  final bool isPackage;
  final bool available;

  /// Set for customised lines ([key] is then the cart line id).
  final CustomLineConfig? custom;
  final String? itemId;
  final num customTotal;

  /// Why a customised line can't be ordered as configured.
  final String? problem;

  bool get isCustom => custom != null;
  num get lineTotal => isCustom ? customTotal : unitPrice * quantity;
  bool get belowMinimum => !isCustom && quantity < minQuantity;
}

class CartCheckoutScreen extends ConsumerWidget {
  const CartCheckoutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartAsync = ref.watch(cartProvider);
    final customLines =
        ref.watch(cartStateProvider).valueOrNull?.lines ?? const {};
    final decorationPricing =
        ref.watch(decorationPricingProvider).valueOrNull ??
        DecorationPricing.defaults;
    final library = {
      for (final a in ref.watch(myArtworksProvider).valueOrNull ?? const [])
        a.id: a,
    };
    final catalogAsync = ref.watch(activeCatalogItemsProvider);
    final packagesAsync = ref.watch(activePackagesProvider);

    final error = cartAsync.error ?? catalogAsync.error ?? packagesAsync.error;
    if (error != null) {
      appLogger.e('[checkout] Failed to load cart', error: error);
      return EmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'Couldn\'t load your cart',
        message: friendlyError(error),
        action: TextButton.icon(
          onPressed: () {
            ref.invalidate(cartProvider);
            ref.invalidate(activeCatalogItemsProvider);
            ref.invalidate(activePackagesProvider);
          },
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Retry'),
        ),
      );
    }
    if (!cartAsync.hasValue ||
        !catalogAsync.hasValue ||
        !packagesAsync.hasValue) {
      return const Center(
        child: CircularProgressIndicator(semanticsLabel: 'Loading'),
      );
    }

    final cart = cartAsync.value!;
    if (cart.isEmpty && customLines.isEmpty) {
      return EmptyState(
        icon: Icons.shopping_cart_outlined,
        title: AppLocalizations.of(context).cartEmpty,
        message:
            'Add items or seasonal packages from the catalog to start an order.',
      );
    }

    final items = {for (final i in catalogAsync.value!) i.id: i};
    final packages = {for (final p in packagesAsync.value!) p.id: p};
    final lines = <_CartLine>[];
    for (final entry in cart.entries) {
      if (entry.key.startsWith(packageCartKeyPrefix)) {
        final pkg = packages[entry.key.substring(packageCartKeyPrefix.length)];
        lines.add(
          _CartLine(
            key: entry.key,
            name: pkg?.name ?? 'Package no longer available',
            unitPrice: pkg?.price ?? 0,
            quantity: entry.value,
            minQuantity: 1,
            imageUrls: pkg?.imageUrl == null ? const [] : [pkg!.imageUrl!],
            icon: Icons.card_giftcard_rounded,
            isPackage: true,
            available: pkg != null,
          ),
        );
      } else {
        final item = items[entry.key];
        lines.add(
          _CartLine(
            key: entry.key,
            name: item?.name ?? 'Item no longer available',
            unitPrice: item?.basePrice ?? 0,
            quantity: entry.value,
            minQuantity: item == null || item.moq < 1 ? 1 : item.moq,
            imageUrls: item?.imageUrls ?? const [],
            icon: item?.category.icon ?? Icons.inventory_2_outlined,
            isPackage: false,
            available: item != null,
          ),
        );
      }
    }
    for (final entry in customLines.entries) {
      final item = items[entry.value.itemId];
      // Mirror the server: digitized/stitch facts come from the library.
      final config = entry.value.copyWith(
        decorations: [
          for (final d in entry.value.decorations)
            if (d.artworkId != null && library[d.artworkId] != null)
              d.copyWith(
                stitchCount: library[d.artworkId]!.stitchCount,
                digitized: library[d.artworkId]!.digitized,
              )
            else
              d,
        ],
      );
      final price = item == null
          ? null
          : CustomizationPricing.price(item, config, decorationPricing);
      lines.add(
        _CartLine(
          key: entry.key,
          itemId: entry.value.itemId,
          name: item?.name ?? 'Item no longer available',
          unitPrice: price?.unitPrice ?? 0,
          quantity: config.quantity,
          minQuantity: 1,
          imageUrls: item?.imageUrls ?? const [],
          icon: item?.category.icon ?? Icons.inventory_2_outlined,
          isPackage: false,
          available: item != null && item.isCustomizable,
          custom: config,
          customTotal: price?.lineTotal ?? 0,
          problem: item == null
              ? null
              : CustomizationPricing.validate(item, config, decorationPricing),
        ),
      );
    }
    return _CheckoutBody(lines: lines);
  }
}

class _CheckoutBody extends ConsumerStatefulWidget {
  const _CheckoutBody({required this.lines});

  final List<_CartLine> lines;

  @override
  ConsumerState<_CheckoutBody> createState() => _CheckoutBodyState();
}

class _CheckoutBodyState extends ConsumerState<_CheckoutBody> {
  final _formKey = GlobalKey<FormState>();
  final _contactName = TextEditingController();
  final _contactPhone = TextEditingController();
  final _deliveryAddress = TextEditingController();
  final _notes = TextEditingController();
  final _coupon = TextEditingController();
  String _paymentPlan = 'full';
  String _deliveryMethod = 'delivery';
  String? _zoneId;
  bool _placing = false;

  /// Result of checking the coupon against the server, and the subtotal it
  /// was checked for (a changed cart needs a re-check).
  DiscountPreview? _couponPreview;
  num? _couponCheckedFor;
  bool _checkingCoupon = false;

  double? _pinLat;
  double? _pinLng;
  bool _saveAddress = false;
  bool _usePoints = false;

  @override
  void initState() {
    super.initState();
    Monitoring.beginCheckout(
      widget.lines.fold<num>(0, (t, l) => t + l.unitPrice * l.quantity),
    );
    final user = ref.read(currentUserProvider);
    _contactName.text = user?.displayName ?? '';
    _contactPhone.text = user?.phoneNumber ?? '';
  }

  @override
  void dispose() {
    _contactName.dispose();
    _contactPhone.dispose();
    _deliveryAddress.dispose();
    _notes.dispose();
    _coupon.dispose();
    super.dispose();
  }

  Future<void> _applyCoupon() async {
    final code = _coupon.text.trim();
    if (code.isEmpty) {
      setState(() {
        _couponPreview = null;
        _couponCheckedFor = null;
      });
      return;
    }
    setState(() => _checkingCoupon = true);
    try {
      final preview = await ref
          .read(commerceRepositoryProvider)
          .previewDiscount(subtotal: _subtotal, couponCode: code);
      setState(() {
        _couponPreview = preview;
        _couponCheckedFor = _subtotal;
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendlyError(error)),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _checkingCoupon = false);
    }
  }

  num get _subtotal => widget.lines
      .where((l) => l.available)
      .fold<num>(0, (sum, l) => sum + l.lineTotal);

  String? get _blockingProblem {
    if (widget.lines.any((l) => !l.available)) {
      return 'Remove the items that are no longer available to continue.';
    }
    final invalid = widget.lines.where((l) => l.problem != null).firstOrNull;
    if (invalid != null) {
      return '"${invalid.name}": ${invalid.problem} Tap edit to fix it.';
    }
    final below = widget.lines.where((l) => l.belowMinimum).firstOrNull;
    if (below != null) {
      return '"${below.name}" has a minimum order of ${below.minQuantity}.';
    }
    return null;
  }

  Future<void> _placeOrder() async {
    if (!_formKey.currentState!.validate()) return;
    if (_blockingProblem != null) return;
    setState(() => _placing = true);
    try {
      final orderId = await ref
          .read(ordersRepositoryProvider)
          .placeFromCart(
            contactName: _contactName.text.trim(),
            contactPhone: _contactPhone.text.trim(),
            deliveryAddress: _deliveryAddress.text.trim(),
            notes: _notes.text.trim(),
            paymentPlan: _paymentPlan,
            deliveryMethod: _deliveryMethod,
            deliveryZoneId: _deliveryMethod == 'delivery' ? _zoneId : null,
            couponCode: _couponPreview?.valid == true
                ? _coupon.text.trim()
                : '',
            deliveryLat: _deliveryMethod == 'delivery' ? _pinLat : null,
            deliveryLng: _deliveryMethod == 'delivery' ? _pinLng : null,
            redeemPoints: _usePoints
                ? (ref.read(myPointsProvider).valueOrNull ?? 0)
                : 0,
          );
      if (_saveAddress && _deliveryMethod == 'delivery') {
        await ref
            .read(addressActionsProvider)
            .save(
              SavedAddress(
                id: '',
                label: 'Delivery address',
                address: _deliveryAddress.text.trim(),
                contactName: _contactName.text.trim(),
                contactPhone: _contactPhone.text.trim(),
                lat: _pinLat,
                lng: _pinLng,
              ),
            )
            .catchError((Object _) {});
      }
      // placeOrder empties the saved cart server-side in the same
      // transaction that creates the order.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order placed — you can pay for it right here.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.go('/customer/orders/$orderId');
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Couldn\'t place order: ${friendlyError(error)}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isWide = MediaQuery.sizeOf(context).width >= 900;
    final settings =
        ref.watch(businessSettingsProvider).valueOrNull ??
        const BusinessSettings();
    final account = ref.watch(myAccountProvider).valueOrNull;
    final zones = settings.deliveryZones;
    final zone = zones.where((z) => z.id == _zoneId).firstOrNull;
    final couponCurrent =
        _couponPreview != null && _couponCheckedFor == _subtotal;
    // Corporate discount is known locally; the coupon amount comes from
    // the server check. placeOrder recomputes both authoritatively.
    final corporate = account == null
        ? 0
        : (_subtotal * account.discountPercent / 100).round();
    final couponAmount = couponCurrent && _couponPreview!.valid
        ? _couponPreview!.coupon
        : 0;
    final loyalty =
        ref.watch(loyaltySettingsProvider).valueOrNull ??
        const LoyaltySettings();
    final myPoints = ref.watch(myPointsProvider).valueOrNull ?? 0;
    final points = _usePoints
        ? loyalty.redeemable(myPoints, _subtotal - corporate - couponAmount)
        : (points: 0, value: 0);
    final addresses = ref.watch(savedAddressesProvider).valueOrNull ?? const [];
    final pricing = OrderPricing.compute(
      _subtotal,
      settings,
      paymentPlan: _paymentPlan,
      includeDelivery: _deliveryMethod == 'delivery',
      deliveryFee: zone?.fee,
      discount: corporate + couponAmount + points.value,
      creditAllowed: account?.creditEnabled ?? false,
    );
    final problem =
        _blockingProblem ??
        (_deliveryMethod == 'delivery' && zones.isNotEmpty && zone == null
            ? 'Choose your delivery area.'
            : null);

    final itemsList = ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      itemCount: widget.lines.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final line = widget.lines[index];
        return Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                SizedBox(
                  width: 52,
                  height: 52,
                  child: CatalogImage(
                    imageUrls: line.imageUrls,
                    placeholderIcon: line.icon,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        line.name,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (line.isCustom && line.available) ...[
                        Text(
                          '${line.quantity} pcs · ${currencyFormat.format(line.lineTotal)}',
                          style: theme.textTheme.bodySmall,
                        ),
                        CustomizationSummary(config: line.custom!),
                        if (line.problem != null)
                          Text(
                            line.problem!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.error,
                            ),
                          ),
                      ] else
                        Text(
                          line.available
                              ? [
                                  if (line.isPackage) 'Package',
                                  currencyFormat.format(line.unitPrice),
                                  if (line.minQuantity > 1)
                                    'min ${line.minQuantity}',
                                ].join(' · ')
                              : 'Remove this to continue',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: line.available && !line.belowMinimum
                                ? theme.colorScheme.onSurfaceVariant
                                : theme.colorScheme.error,
                          ),
                        ),
                    ],
                  ),
                ),
                if (line.isCustom && line.available)
                  IconButton(
                    tooltip: 'Edit',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => context.push(
                      '/customer/catalog/${line.itemId}/customize?line=${line.key}',
                    ),
                  )
                else if (line.available)
                  _QuantityStepper(
                    quantity: line.quantity,
                    minQuantity: line.minQuantity,
                    onChanged: (next) => ref
                        .read(cartActionsProvider)
                        .setQuantity(line.key, next),
                  ),
                IconButton(
                  tooltip: 'Remove',
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: () => line.isCustom
                      ? ref.read(cartActionsProvider).removeCustomLine(line.key)
                      : ref.read(cartActionsProvider).remove(line.key),
                ),
              ],
            ),
          ),
        );
      },
    );

    Widget moneyRow(String label, num value, {bool bold = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(label, style: bold ? theme.textTheme.titleMedium : null),
          const Spacer(),
          Text(
            currencyFormat.format(value),
            style: bold
                ? theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
                  )
                : null,
          ),
        ],
      ),
    );

    final form = Padding(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context).deliveryDetails,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (settings.allowPickup) ...[
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'delivery',
                    label: Text('Deliver to me'),
                    icon: Icon(Icons.local_shipping_outlined),
                  ),
                  ButtonSegment(
                    value: 'pickup',
                    label: Text('I\'ll pick up'),
                    icon: Icon(Icons.storefront_outlined),
                  ),
                ],
                selected: {_deliveryMethod},
                onSelectionChanged: (v) =>
                    setState(() => _deliveryMethod = v.first),
              ),
              if (_deliveryMethod == 'pickup' &&
                  settings.pickupAddress.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Pick up at: ${settings.pickupAddress}',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
            ],
            if (_deliveryMethod == 'delivery' && zones.isNotEmpty) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _zoneId,
                decoration: const InputDecoration(labelText: 'Delivery area'),
                items: [
                  for (final z in zones)
                    DropdownMenuItem(
                      value: z.id,
                      child: Text(
                        '${z.name} · ${z.fee > 0 ? currencyFormat.format(z.fee) : 'free'}'
                        '${z.etaDays > 0 ? ' · ~${z.etaDays} day(s)' : ''}',
                      ),
                    ),
                ],
                onChanged: (v) => setState(() => _zoneId = v),
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: _contactName,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).contactName,
              ),
              maxLength: 80,
              validator: (v) =>
                  (v == null || v.trim().length < 2) ? 'Enter your name' : null,
            ),
            TextFormField(
              controller: _contactPhone,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).contactPhone,
              ),
              validator: (v) => (v == null || v.trim().length < 9)
                  ? 'Enter a phone number'
                  : null,
            ),
            const SizedBox(height: 12),
            if (_deliveryMethod == 'delivery' && addresses.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final a in addresses)
                      ActionChip(
                        avatar: Icon(
                          a.hasPin ? Icons.place_rounded : Icons.home_outlined,
                          size: 18,
                        ),
                        label: Text(a.label.isEmpty ? a.address : a.label),
                        onPressed: () => setState(() {
                          _deliveryAddress.text = a.address;
                          if (a.contactName.isNotEmpty) {
                            _contactName.text = a.contactName;
                          }
                          if (a.contactPhone.isNotEmpty) {
                            _contactPhone.text = a.contactPhone;
                          }
                          _pinLat = a.lat;
                          _pinLng = a.lng;
                        }),
                      ),
                  ],
                ),
              ),
            if (_deliveryMethod == 'delivery')
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () async {
                        final p = await pickLocationOnMap(
                          context,
                          initial: _pinLat == null
                              ? null
                              : LatLng(_pinLat!, _pinLng!),
                        );
                        if (p != null) {
                          setState(() {
                            _pinLat = p.latitude;
                            _pinLng = p.longitude;
                          });
                        }
                      },
                      icon: Icon(
                        _pinLat == null
                            ? Icons.add_location_alt_outlined
                            : Icons.place_rounded,
                      ),
                      label: Text(
                        _pinLat == null
                            ? 'Drop a pin for the driver (optional)'
                            : 'Pin set — tap to adjust',
                      ),
                    ),
                  ),
                  Checkbox(
                    value: _saveAddress,
                    onChanged: (v) => setState(() => _saveAddress = v ?? false),
                  ),
                  const Text('Save'),
                ],
              ),
            if (_deliveryMethod == 'delivery')
              TextFormField(
                controller: _deliveryAddress,
                decoration: const InputDecoration(
                  labelText: 'Delivery address',
                ),
                maxLines: 2,
                maxLength: 300,
                validator: (v) => (v == null || v.trim().length < 5)
                    ? 'Enter a delivery address'
                    : null,
              ),
            TextFormField(
              controller: _notes,
              decoration: const InputDecoration(
                labelText: 'Notes (artwork details, colours, sizes...)',
              ),
              maxLines: 3,
              maxLength: 1000,
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _coupon,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      labelText: 'Promo code',
                      helperText: _couponPreview == null
                          ? null
                          : !couponCurrent
                          ? 'Cart changed — apply again'
                          : _couponPreview!.valid
                          ? (_couponPreview!.message.isEmpty
                                ? 'Code applied'
                                : _couponPreview!.message)
                          : null,
                      errorText: couponCurrent && !_couponPreview!.valid
                          ? _couponPreview!.message
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: OutlinedButton(
                    onPressed: _checkingCoupon ? null : _applyCoupon,
                    child: const Text('Apply'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            moneyRow(AppLocalizations.of(context).subtotal, pricing.subtotal),
            if (corporate > 0)
              moneyRow(
                'Account discount (${account!.discountPercent}%)',
                -corporate,
              ),
            if (loyalty.enabled && myPoints > 0)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _usePoints,
                onChanged: (v) => setState(() => _usePoints = v ?? false),
                title: Text('Use my points ($myPoints available)'),
                subtitle: Text(
                  'Up to ${loyalty.maxRedeemPercent}% of the order',
                ),
              ),
            if (points.value > 0)
              moneyRow('Points (${points.points})', -points.value),
            if (couponAmount > 0)
              moneyRow(
                'Promo ${_coupon.text.trim().toUpperCase()}',
                -couponAmount,
              ),
            if (pricing.deliveryFee > 0)
              moneyRow('Delivery', pricing.deliveryFee)
            else if (settings.deliveryFlatFee > 0)
              moneyRow('Delivery (free)', 0),
            if (pricing.taxAmount > 0)
              moneyRow(
                pricing.pricesIncludeVat
                    ? 'Includes VAT (${(pricing.taxRate * 100).toStringAsFixed(0)}%)'
                    : 'VAT (${(pricing.taxRate * 100).toStringAsFixed(0)}%)',
                pricing.taxAmount,
              ),
            const Divider(),
            moneyRow(
              AppLocalizations.of(context).total,
              pricing.total,
              bold: true,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: ApproxPrice(kes: pricing.total),
            ),
            if (settings.depositsAvailable ||
                (account?.creditEnabled ?? false)) ...[
              const SizedBox(height: 12),
              Text(
                'How would you like to pay?',
                style: theme.textTheme.labelLarge,
              ),
              const SizedBox(height: 6),
              SegmentedButton<String>(
                segments: [
                  const ButtonSegment(
                    value: 'full',
                    label: Text('Pay in full'),
                  ),
                  if (settings.depositsAvailable)
                    ButtonSegment(
                      value: 'deposit',
                      label: Text('${settings.depositPercent}% deposit'),
                    ),
                  if (account?.creditEnabled ?? false)
                    ButtonSegment(
                      value: 'credit',
                      label: Text('On account (${account!.paymentTermsDays}d)'),
                    ),
                ],
                selected: {_paymentPlan},
                onSelectionChanged: (v) =>
                    setState(() => _paymentPlan = v.first),
              ),
              if (pricing.paymentPlan == 'credit')
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Nothing to pay now — we\'ll invoice ${account?.companyName.isNotEmpty == true ? account!.companyName : 'your account'}, due in ${account?.paymentTermsDays ?? 30} days.',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              if (pricing.paymentPlan == 'deposit')
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Pay ${currencyFormat.format(pricing.depositAmount)} now to start production, '
                    'and ${currencyFormat.format(pricing.total - pricing.depositAmount)} before delivery.',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
            ],
            const SizedBox(height: 8),
            Text(
              'You\'ll choose how to pay (M-Pesa, card and more) on the next screen. '
              'Final prices are confirmed when the order is placed.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (problem != null) ...[
              const SizedBox(height: 8),
              Text(
                problem,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _placing || problem != null ? null : _placeOrder,
                icon: _placing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(AppLocalizations.of(context).placeOrder),
              ),
            ),
          ],
        ),
      ),
    );

    if (isWide) {
      return Row(
        children: [
          Expanded(child: itemsList),
          const VerticalDivider(width: 1),
          Expanded(child: SingleChildScrollView(child: form)),
        ],
      );
    }
    return Column(
      children: [
        Expanded(child: itemsList),
        const Divider(height: 1),
        Expanded(child: SingleChildScrollView(child: form)),
      ],
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({
    required this.quantity,
    required this.minQuantity,
    required this.onChanged,
  });

  final int quantity;
  final int minQuantity;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    // Bulk items step by 1 but never below their minimum order quantity;
    // removing the line entirely is the separate delete button.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Decrease quantity',
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.remove_circle_outline_rounded),
          onPressed: quantity > minQuantity
              ? () => onChanged(quantity - 1)
              : null,
        ),
        InkWell(
          onTap: () async {
            final next = await _askQuantity(context);
            if (next != null) {
              onChanged(next < minQuantity ? minQuantity : next);
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '$quantity',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
        IconButton(
          tooltip: 'Increase quantity',
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.add_circle_outline_rounded),
          onPressed: () => onChanged(quantity + 1),
        ),
      ],
    );
  }

  /// Typing "250" beats tapping + 200 times for bulk branding orders.
  Future<int?> _askQuantity(BuildContext context) {
    final controller = TextEditingController(text: '$quantity');
    return showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quantity'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            helperText: minQuantity > 1 ? 'Minimum $minQuantity' : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, int.tryParse(controller.text.trim())),
            child: const Text('Set'),
          ),
        ],
      ),
    );
  }
}
