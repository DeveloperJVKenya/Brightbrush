import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/formatting/currency.dart';

import '../../../core/errors/user_facing_error.dart';
import '../../../core/firebase/firebase_providers.dart';
import '../../../core/logging/app_logger.dart';
import '../../../shared/widgets/catalog_image.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../catalog/application/catalog_providers.dart';
import '../../catalog/domain/catalog_item.dart';
import '../../orders/application/orders_providers.dart';
import '../../orders/domain/order_model.dart';
import '../../orders/domain/order_status.dart';
import '../application/cart_providers.dart';

class CartCheckoutScreen extends ConsumerWidget {
  const CartCheckoutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final catalogAsync = ref.watch(activeCatalogItemsProvider);

    if (cart.isEmpty) {
      return const EmptyState(
        icon: Icons.shopping_cart_outlined,
        title: 'Your cart is empty',
        message: 'Add items from the catalog to start building an order.',
      );
    }

    return catalogAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) {
        appLogger.e('[checkout] Failed to load cart', error: error, stackTrace: stack);
        return EmptyState(
            icon: Icons.cloud_off_rounded, title: 'Couldn\'t load your cart', message: friendlyError(error));
      },
      data: (catalogItems) {
        final byId = {for (final item in catalogItems) item.id: item};
        final lines = <MapEntry<CatalogItem, int>>[];
        for (final entry in cart.entries) {
          final item = byId[entry.key];
          if (item != null) lines.add(MapEntry(item, entry.value));
        }
        return _CheckoutBody(lines: lines);
      },
    );
  }
}

class _CheckoutBody extends ConsumerStatefulWidget {
  const _CheckoutBody({required this.lines});

  final List<MapEntry<CatalogItem, int>> lines;

  @override
  ConsumerState<_CheckoutBody> createState() => _CheckoutBodyState();
}

class _CheckoutBodyState extends ConsumerState<_CheckoutBody> {
  final _formKey = GlobalKey<FormState>();
  final _contactName = TextEditingController();
  final _contactPhone = TextEditingController();
  final _deliveryAddress = TextEditingController();
  final _notes = TextEditingController();
  bool _placing = false;


  @override
  void dispose() {
    _contactName.dispose();
    _contactPhone.dispose();
    _deliveryAddress.dispose();
    _notes.dispose();
    super.dispose();
  }

  num get _total => widget.lines.fold(0, (sum, e) => sum + e.key.basePrice * e.value);

  Future<void> _placeOrder() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _placing = true);
    try {
      final uid = ref.read(currentUidProvider);
      if (uid == null) {
        appLogger.w('[checkout] _placeOrder called with no signed-in uid — aborting before a doomed Firestore write');
        throw StateError('You need to be signed in to place an order.');
      }
      appLogger.i('[checkout] Placing order for uid=$uid, ${widget.lines.length} line item group(s), total=$_total');
      final items = [
        for (final entry in widget.lines)
          OrderLineItem(
            itemId: entry.key.id,
            name: entry.key.name,
            category: entry.key.category.name,
            unitPrice: entry.key.basePrice,
            quantity: entry.value,
          ),
      ];
      final order = OrderModel(
        id: '',
        customerId: uid,
        contactName: _contactName.text.trim(),
        contactPhone: _contactPhone.text.trim(),
        deliveryAddress: _deliveryAddress.text.trim(),
        notes: _notes.text.trim(),
        items: items,
        subtotal: _total,
        total: _total,
        status: OrderStatus.pendingReview,
        paymentStatus: PaymentStatus.unpaid,
        assignedStaffId: null,
        deliveryLat: null,
        deliveryLng: null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final orderId = await ref.read(ordersRepositoryProvider).create(order);
      appLogger.i('[checkout] Order $orderId created for uid=$uid');
      ref.read(cartProvider.notifier).clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order placed — track it under My Orders.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.go('/customer/orders');
      }
    } catch (error, stack) {
      appLogger.e('[checkout] Failed to place order', error: error, stackTrace: stack);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Couldn\'t place order: ${friendlyError(error)}'), behavior: SnackBarBehavior.floating),
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

    final itemsList = ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      itemCount: widget.lines.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = widget.lines[index].key;
        final qty = widget.lines[index].value;
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
                    imageUrls: item.imageUrls,
                    placeholderIcon: item.category.icon,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.name, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                      Text(
                        currencyFormat.format(item.basePrice),
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                _QuantityStepper(
                  quantity: qty,
                  onChanged: (next) {
                    if (next <= 0) {
                      ref.read(cartProvider.notifier).remove(item.id);
                    } else {
                      ref.read(cartProvider.notifier).add(item.id, quantity: next - qty);
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );

    final form = Padding(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Delivery details', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            TextFormField(
              controller: _contactName,
              decoration: const InputDecoration(labelText: 'Contact name'),
              validator: (v) => (v == null || v.trim().length < 2) ? 'Enter your name' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _contactPhone,
              decoration: const InputDecoration(labelText: 'Contact phone'),
              validator: (v) => (v == null || v.trim().length < 3) ? 'Enter a phone number' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _deliveryAddress,
              decoration: const InputDecoration(labelText: 'Delivery address'),
              maxLines: 2,
              validator: (v) => (v == null || v.trim().length < 5) ? 'Enter a delivery address' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notes,
              decoration: const InputDecoration(labelText: 'Notes (artwork details, special requests...)'),
              maxLines: 3,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Text('Total', style: theme.textTheme.titleMedium),
                const Spacer(),
                Text(
                  currencyFormat.format(_total),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'No payment gateway yet — this places the order as unpaid, and BrightBrush will invoice you '
              'directly to confirm payment.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _placing ? null : _placeOrder,
                icon: _placing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send_rounded),
                label: const Text('Place order'),
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
  const _QuantityStepper({required this.quantity, required this.onChanged});

  final int quantity;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.remove_circle_outline_rounded),
          onPressed: () => onChanged(quantity - 1),
        ),
        Text('$quantity', style: const TextStyle(fontWeight: FontWeight.w600)),
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.add_circle_outline_rounded),
          onPressed: () => onChanged(quantity + 1),
        ),
      ],
    );
  }
}
