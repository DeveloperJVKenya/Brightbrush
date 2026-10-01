import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/user_facing_error.dart';
import '../../../core/firebase/firebase_providers.dart';
import '../../orders/domain/order_model.dart';
import '../../orders/domain/order_status.dart';
import '../data/proofs_repository.dart';
import '../../../core/l10n/l10n_ext.dart';
import '../../../core/l10n/enum_l10n.dart';

final proofsRepositoryProvider = Provider<ProofsRepository>((ref) {
  return ProofsRepository(
    ref.watch(firestoreProvider),
    ref.watch(firebaseStorageProvider),
    ref.watch(firebaseFunctionsProvider),
  );
});

final orderProofsProvider = StreamProvider.autoDispose
    .family<List<OrderProof>, String>((ref, orderId) {
      return ref.watch(proofsRepositoryProvider).streamProofs(orderId);
    });

void _snack(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
    );

/// Customer view: the latest proof with approve / request-changes, and the
/// earlier versions underneath.
class CustomerProofPanel extends ConsumerStatefulWidget {
  const CustomerProofPanel({super.key, required this.order});

  final OrderModel order;

  @override
  ConsumerState<CustomerProofPanel> createState() => _CustomerProofPanelState();
}

class _CustomerProofPanelState extends ConsumerState<CustomerProofPanel> {
  final _comment = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _respond(OrderProof proof, bool approve) async {
    if (!approve && _comment.text.trim().isEmpty) {
      _snack(context, context.l10n.tellUsWhatYoudLikeChanged);
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(proofsRepositoryProvider)
          .respond(
            orderId: widget.order.id,
            proofId: proof.id,
            approve: approve,
            comment: _comment.text.trim(),
          );
      _comment.clear();
      if (mounted) {
        _snack(
          context,
          approve
              ? context.l10n.approvedProductionCanBegin
              : context.l10n.thanksWellSendARevisedProof,
        );
      }
    } catch (error) {
      if (mounted) _snack(context, friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    if (!order.requiresProof && order.proofVersion == 0) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final proofs =
        ref.watch(orderProofsProvider(order.id)).valueOrNull ?? const [];
    final latest = proofs.firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.designProof,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: latest == null
                ? Row(
                    children: [
                      const Icon(Icons.brush_outlined),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          context.l10n.ourDesignersArePreparingADigital,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Chip(
                            label: Text(
                              context.l10n.version(
                                latest.version,
                                order.proofStatus.tr(context),
                              ),
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                      ProofImages(urls: latest.imageUrls),
                      if (latest.note.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(latest.note),
                      ],
                      if (latest.stitchCount != null)
                        Text(
                          context.l10n.stitches(
                            NumberFormat.decimalPattern().format(
                              latest.stitchCount,
                            ),
                          ),
                          style: theme.textTheme.bodySmall,
                        ),
                      if (latest.status == ProofResponse.pending &&
                          order.status != OrderStatus.cancelled) ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: _comment,
                          maxLines: 3,
                          maxLength: 2000,
                          decoration: InputDecoration(
                            labelText:
                                context.l10n.commentsRequiredToRequestChanges,
                          ),
                        ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilledButton.icon(
                              onPressed: _busy
                                  ? null
                                  : () => _respond(latest, true),
                              icon: const Icon(Icons.check_rounded),
                              label: Text(context.l10n.approveProof),
                            ),
                            OutlinedButton.icon(
                              onPressed: _busy
                                  ? null
                                  : () => _respond(latest, false),
                              icon: const Icon(Icons.edit_note_rounded),
                              label: Text(context.l10n.requestChanges),
                            ),
                          ],
                        ),
                      ] else if (latest.customerComment != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            context.l10n.yourComment(latest.customerComment!),
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      if (proofs.length > 1)
                        ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          title: Text(
                            context.l10n.earlierVersions(proofs.length - 1),
                          ),
                          children: [
                            for (final p in proofs.skip(1))
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  context.l10n.version2(
                                    p.version,
                                    p.status.name,
                                  ),
                                ),
                                subtitle: Text(p.customerComment ?? p.note),
                              ),
                          ],
                        ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

class ProofImages extends StatelessWidget {
  const ProofImages({super.key, required this.urls});

  final List<String> urls;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 180,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: urls.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, i) => GestureDetector(
          onTap: () => showDialog<void>(
            context: context,
            builder: (context) => Dialog(
              child: InteractiveViewer(
                child: Image(image: CachedNetworkImageProvider(urls[i])),
              ),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image(
              image: CachedNetworkImageProvider(urls[i]),
              height: 180,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) => const SizedBox(
                width: 120,
                child: Icon(Icons.broken_image_outlined),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Staff: upload proof images for an order and see previous responses.
Future<void> showSendProofDialog(BuildContext context, OrderModel order) {
  return showDialog<void>(
    context: context,
    builder: (context) => _SendProofDialog(order: order),
  );
}

class _SendProofDialog extends ConsumerStatefulWidget {
  const _SendProofDialog({required this.order});

  final OrderModel order;

  @override
  ConsumerState<_SendProofDialog> createState() => _SendProofDialogState();
}

class _SendProofDialogState extends ConsumerState<_SendProofDialog> {
  final _note = TextEditingController();
  final _stitches = TextEditingController();
  final List<(Uint8List, String)> _images = [];
  bool _sending = false;

  @override
  void dispose() {
    _note.dispose();
    _stitches.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final files = await ImagePicker().pickMultiImage(
      imageQuality: 85,
      limit: 8,
    );
    for (final f in files.take(8 - _images.length)) {
      final mime =
          f.mimeType ??
          (f.name.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg');
      _images.add((await f.readAsBytes(), mime));
    }
    if (mounted) setState(() {});
  }

  Future<void> _send() async {
    setState(() => _sending = true);
    try {
      await ref
          .read(proofsRepositoryProvider)
          .sendProof(
            orderId: widget.order.id,
            images: _images,
            note: _note.text.trim(),
            stitchCount: int.tryParse(_stitches.text.trim()),
          );
      if (mounted) {
        Navigator.pop(context);
        _snack(context, context.l10n.proofSentToTheCustomer);
      }
    } catch (error) {
      if (mounted) _snack(context, friendlyError(error));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final proofs =
        ref.watch(orderProofsProvider(widget.order.id)).valueOrNull ?? const [];
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(context.l10n.proof(widget.order.displayNumber)),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.status(widget.order.proofStatus.tr(context)),
                style: theme.textTheme.labelLarge,
              ),
              for (final p in proofs.take(3))
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(switch (p.status) {
                    ProofResponse.approved => Icons.check_circle_rounded,
                    ProofResponse.changesRequested => Icons.edit_note_rounded,
                    ProofResponse.pending => Icons.hourglass_top_rounded,
                  }),
                  title: Text(context.l10n.version2(p.version, p.status.name)),
                  subtitle: p.customerComment == null
                      ? null
                      : Text(context.l10n.customer(p.customerComment!)),
                ),
              const Divider(),
              Text(
                context.l10n.sendANewVersion,
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (i, (bytes, _)) in _images.indexed)
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            bytes,
                            width: 90,
                            height: 90,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: IconButton.filledTonal(
                            iconSize: 14,
                            visualDensity: VisualDensity.compact,
                            onPressed: () =>
                                setState(() => _images.removeAt(i)),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ),
                      ],
                    ),
                  if (_images.length < 8)
                    OutlinedButton.icon(
                      onPressed: _pick,
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: Text(context.l10n.addMockupStitchOutPhotos),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _stitches,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: context.l10n.stitchCountEmbroideryOptional,
                ),
              ),
              TextField(
                controller: _note,
                maxLines: 3,
                maxLength: 2000,
                decoration: InputDecoration(
                  labelText: context.l10n.noteToCustomerSizesThreadColours,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.close),
        ),
        FilledButton.icon(
          onPressed: _sending || _images.isEmpty ? null : _send,
          icon: _sending
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send_rounded),
          label: Text(context.l10n.sendProof),
        ),
      ],
    );
  }
}
