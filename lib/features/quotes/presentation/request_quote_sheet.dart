import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/errors/user_facing_error.dart';
import '../../../core/firebase/firebase_providers.dart';
import '../../../shared/widgets/auth_required_sheet.dart';
import '../application/quotes_providers.dart';

/// Ask BrightBrush for a custom price — for a package, a catalog item in an
/// unusual quantity/finish, or a fully custom job ([title] editable). The
/// request is saved to QuoteRequests and lands in the manager's Quotes
/// inbox; the customer follows it under My Quotes.
Future<void> showRequestQuoteSheet(
  BuildContext context, {
  String? title,
  String? packageId,
  String? itemId,
  int initialQuantity = 1,
}) async {
  final container = ProviderScope.containerOf(context);
  if (container.read(currentUidProvider) == null) {
    showAuthRequiredSheet(
      context,
      message: 'Sign in or create an account to request a quote.',
    );
    return;
  }
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (context) => _RequestQuoteForm(
      title: title,
      packageId: packageId,
      itemId: itemId,
      initialQuantity: initialQuantity,
    ),
  );
}

class _RequestQuoteForm extends ConsumerStatefulWidget {
  const _RequestQuoteForm({
    required this.title,
    required this.packageId,
    required this.itemId,
    required this.initialQuantity,
  });

  final String? title;
  final String? packageId;
  final String? itemId;
  final int initialQuantity;

  @override
  ConsumerState<_RequestQuoteForm> createState() => _RequestQuoteFormState();
}

class _RequestQuoteFormState extends ConsumerState<_RequestQuoteForm> {
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.title ?? '');
  late final _quantity = TextEditingController(
    text: '${widget.initialQuantity}',
  );
  final _details = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _title.dispose();
    _quantity.dispose();
    _details.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    setState(() => _sending = true);
    try {
      final profile = ref.read(myProfileProvider).valueOrNull;
      await ref
          .read(quotesRepositoryProvider)
          .create(
            uid: user.uid,
            customerName:
                profile?.displayName ?? user.displayName ?? user.email ?? 'Customer',
            customerEmail: user.email ?? '',
            title: _title.text.trim(),
            quantity: int.parse(_quantity.text.trim()),
            details: _details.text.trim(),
            packageId: widget.packageId,
            itemId: widget.itemId,
          );
      if (!mounted) return;
      // Captured before pop: this sheet's context is gone afterwards.
      final messenger = ScaffoldMessenger.of(context);
      final router = GoRouter.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(
          content: const Text(
            'Quote request sent — we\'ll price it and notify you under My Quotes.',
          ),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'View',
            onPressed: () => router.push('/customer/quotes'),
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Couldn\'t send request: ${friendlyError(error)}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Request a quote',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Tell us what you need and we\'ll send you a price.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(
                  labelText: 'What do you need?',
                  hintText: 'e.g. 200 embroidered polo shirts',
                ),
                maxLength: 120,
                validator: (v) =>
                    (v ?? '').trim().length < 2 ? 'Describe the item' : null,
              ),
              TextFormField(
                controller: _quantity,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'Quantity'),
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  return n == null || n < 1 || n > 100000
                      ? 'Enter a quantity between 1 and 100,000'
                      : null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _details,
                decoration: const InputDecoration(
                  labelText: 'Details',
                  hintText:
                      'Logo placement, colours, sizes, deadline, delivery location…',
                  alignLabelWithHint: true,
                ),
                maxLines: 5,
                maxLength: 2000,
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _sending ? null : _submit,
                icon: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded),
                label: const Text('Send request'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
