import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/errors/user_facing_error.dart';
import '../../core/firebase/firebase_providers.dart';
import '../../core/logging/stream_error_logger.dart';
import '../../shared/widgets/catalog_image.dart';
import '../../shared/widgets/empty_state.dart';
import '../catalog/application/catalog_providers.dart';
import '../orders/domain/order_model.dart';
import '../../l10n/app_localizations.dart';
import 'growth_providers.dart';
import '../../core/l10n/l10n_ext.dart';

class Review {
  const Review({
    required this.orderId,
    required this.customerName,
    required this.rating,
    required this.comment,
    required this.photoUrls,
    required this.status,
    required this.reply,
    required this.createdAt,
  });

  final String orderId;
  final String customerName;
  final int rating;
  final String comment;
  final List<String> photoUrls;
  final String status;
  final String? reply;
  final DateTime createdAt;

  factory Review.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return Review(
      orderId: doc.id,
      customerName: d['customerName'] as String? ?? '',
      rating: (d['rating'] as num?)?.toInt() ?? 0,
      comment: d['comment'] as String? ?? '',
      photoUrls: (d['photoUrls'] as List?)?.cast<String>() ?? const [],
      status: d['status'] as String? ?? 'pending',
      reply: d['reply'] as String?,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

/// Approved reviews for a catalog item (public).
final itemReviewsProvider = StreamProvider.autoDispose
    .family<List<Review>, String>(
      (ref, itemId) => ref
          .watch(firestoreProvider)
          .collection('Reviews')
          .where('itemIds', arrayContains: itemId)
          .where('status', isEqualTo: 'approved')
          .limit(20)
          .snapshots()
          .map((s) => s.docs.map(Review.fromFirestore).toList())
          .transform(logStreamErrors('[reviews] item $itemId failed')),
    );

final myReviewProvider = StreamProvider.autoDispose.family<Review?, String>(
  (ref, orderId) => ref
      .watch(firestoreProvider)
      .collection('Reviews')
      .doc(orderId)
      .snapshots()
      .map((s) => s.exists ? Review.fromFirestore(s) : null)
      .handleError((Object _) => null),
);

class StarRow extends StatelessWidget {
  const StarRow({super.key, required this.rating, this.size = 16, this.onTap});

  final num rating;
  final double size;
  final ValueChanged<int>? onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          GestureDetector(
            onTap: onTap == null ? null : () => onTap!(i),
            child: Icon(
              rating >= i
                  ? Icons.star_rounded
                  : rating >= i - 0.5
                  ? Icons.star_half_rounded
                  : Icons.star_outline_rounded,
              size: size,
              color: Colors.amber,
            ),
          ),
      ],
    );
  }
}

/// On a completed order: leave a review (or see the one you left).
class OrderReviewCard extends ConsumerWidget {
  const OrderReviewCard({super.key, required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (order.status.name != 'completed') return const SizedBox.shrink();
    final review = ref.watch(myReviewProvider(order.id)).valueOrNull;
    return Card(
      margin: EdgeInsets.zero,
      child: review != null
          ? ListTile(
              leading: const Icon(Icons.rate_review_outlined),
              title: Text(context.l10n.thanksForYourReview),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StarRow(rating: review.rating),
                  if (review.comment.isNotEmpty) Text(review.comment),
                  if (review.reply != null)
                    Text(
                      'BrightBrush: ${review.reply}',
                      style: const TextStyle(fontStyle: FontStyle.italic),
                    ),
                ],
              ),
            )
          : ListTile(
              leading: const Icon(
                Icons.star_outline_rounded,
                color: Colors.amber,
              ),
              title: Text(AppLocalizations.of(context).rateOrderTitle),
              subtitle: Text(context.l10n.rateOrderSubtitle),
              trailing: FilledButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => _ReviewDialog(order: order),
                ),
                child: Text(AppLocalizations.of(context).review),
              ),
            ),
    );
  }
}

class _ReviewDialog extends ConsumerStatefulWidget {
  const _ReviewDialog({required this.order});

  final OrderModel order;

  @override
  ConsumerState<_ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends ConsumerState<_ReviewDialog> {
  int _rating = 5;
  final _comment = TextEditingController();
  final List<Uint8List> _photos = [];
  bool _saving = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    setState(() => _saving = true);
    try {
      final urls = <String>[];
      for (final (i, bytes) in _photos.indexed) {
        final task = await ref
            .read(firebaseStorageProvider)
            .ref('reviews/${user.uid}/${widget.order.id}_$i.jpg')
            .putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
        urls.add(await task.ref.getDownloadURL());
      }
      final name = (user.displayName ?? widget.order.contactName)
          .split(' ')
          .first;
      await ref
          .read(firestoreProvider)
          .collection('Reviews')
          .doc(widget.order.id)
          .set({
            'customerId': user.uid,
            'customerName': name.substring(0, name.length.clamp(0, 80)),
            'rating': _rating,
            'comment': _comment.text.trim(),
            'photoUrls': urls,
            'itemIds': widget.order.items
                .map((i) => i.itemId)
                .toSet()
                .take(50)
                .toList(),
            'status': 'pending',
            'createdAt': FieldValue.serverTimestamp(),
          });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendlyError(e)),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.l10n.rateYourOrder),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            StarRow(
              rating: _rating,
              size: 36,
              onTap: (v) => setState(() => _rating = v),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _comment,
              maxLines: 3,
              maxLength: 1000,
              decoration: InputDecoration(
                hintText: context.l10n.qualityFitDeliveryAnythingToShare,
              ),
            ),
            Row(
              children: [
                TextButton.icon(
                  onPressed: _photos.length >= 4
                      ? null
                      : () async {
                          final f = await ImagePicker().pickImage(
                            source: ImageSource.gallery,
                            imageQuality: 75,
                            maxWidth: 1600,
                          );
                          if (f != null) {
                            final b = await f.readAsBytes();
                            setState(() => _photos.add(b));
                          }
                        },
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: Text(context.l10n.photos4(_photos.length)),
                ),
              ],
            ),
            Text(
              context.l10n.reviewsAppearPubliclyAfterAQuick,
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: Text(context.l10n.submit),
        ),
      ],
    );
  }
}

/// Reviews block on an item's page.
class ItemReviewsSection extends ConsumerWidget {
  const ItemReviewsSection({super.key, required this.itemId});

  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviews =
        ref.watch(itemReviewsProvider(itemId)).valueOrNull ?? const [];
    if (reviews.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final avg = reviews.fold<int>(0, (s, r) => s + r.rating) / reviews.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Row(
          children: [
            Text(
              context.l10n.reviews,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            StarRow(rating: avg),
            Text(' ${avg.toStringAsFixed(1)} (${reviews.length})'),
          ],
        ),
        for (final r in reviews.take(5))
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Row(
              children: [
                StarRow(rating: r.rating, size: 14),
                const SizedBox(width: 6),
                Text(r.customerName),
              ],
            ),
            subtitle: Text(
              [
                r.comment,
                if (r.reply != null) 'BrightBrush: ${r.reply}',
              ].where((s) => s.isNotEmpty).join('\n'),
            ),
          ),
      ],
    );
  }
}

/// Heart toggle for the wishlist.
class WishlistButton extends ConsumerWidget {
  const WishlistButton({super.key, required this.itemId});

  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(currentUidProvider) == null) return const SizedBox.shrink();
    final saved =
        ref.watch(wishlistProvider).valueOrNull?.contains(itemId) ?? false;
    return IconButton(
      tooltip: saved
          ? context.l10n.removeFromWishlist
          : context.l10n.saveToWishlist,
      icon: Icon(
        saved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
        color: saved ? Colors.pink : null,
      ),
      onPressed: () => toggleWishlist(ref, itemId, !saved),
    );
  }
}

class WishlistScreen extends ConsumerWidget {
  const WishlistScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ids = ref.watch(wishlistProvider).valueOrNull ?? const {};
    final items =
        (ref.watch(activeCatalogItemsProvider).valueOrNull ?? const [])
            .where((i) => ids.contains(i.id))
            .toList();
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/customer'),
        ),
        title: Text(context.l10n.wishlist),
      ),
      body: items.isEmpty
          ? EmptyState(
              icon: Icons.favorite_border_rounded,
              title: context.l10n.nothingSavedYet,
              message: context.l10n.tapTheHeartOnAnyItem,
            )
          : GridView.extent(
              padding: const EdgeInsets.all(16),
              maxCrossAxisExtent: 220,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              children: [
                for (final i in items)
                  InkWell(
                    onTap: () => context.push('/customer/catalog/${i.id}'),
                    child: Card(
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: CatalogImage(
                              imageUrls: i.imageUrls,
                              placeholderIcon: i.category.icon,
                              borderRadius: BorderRadius.zero,
                            ),
                          ),
                          ListTile(
                            dense: true,
                            title: Text(
                              i.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: WishlistButton(itemId: i.id),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

// ----------------------------------------------------------- Portfolio

class PortfolioWork {
  const PortfolioWork({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrls,
    required this.tags,
    required this.featured,
  });

  final String id;
  final String title;
  final String description;
  final List<String> imageUrls;
  final List<String> tags;
  final bool featured;

  factory PortfolioWork.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data() ?? {};
    return PortfolioWork(
      id: doc.id,
      title: d['title'] as String? ?? '',
      description: d['description'] as String? ?? '',
      imageUrls: (d['imageUrls'] as List?)?.cast<String>() ?? const [],
      tags: (d['tags'] as List?)?.cast<String>() ?? const [],
      featured: d['featured'] as bool? ?? false,
    );
  }
}

final portfolioProvider = StreamProvider<List<PortfolioWork>>(
  (ref) => ref
      .watch(firestoreProvider)
      .collection('Portfolio')
      .snapshots()
      .map(
        (s) => s.docs.map(PortfolioWork.fromFirestore).toList()
          ..sort((a, b) => (b.featured ? 1 : 0).compareTo(a.featured ? 1 : 0)),
      )
      .transform(logStreamErrors('[portfolio] stream failed')),
);

/// Public gallery of past work (guests included).
class PortfolioScreen extends ConsumerWidget {
  const PortfolioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final works = ref.watch(portfolioProvider).valueOrNull ?? const [];
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          context.l10n.navPortfolio,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          context.l10n.brandingWeveProducedForSchoolsCompanies,
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        if (works.isEmpty)
          EmptyState(
            icon: Icons.photo_library_outlined,
            title: context.l10n.comingSoon,
            message: context.l10n.ourGalleryOfRecentJobsWill,
          ),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final w in works)
              SizedBox(
                width: 300,
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => showDialog<void>(
                      context: context,
                      builder: (_) => Dialog(
                        child: SizedBox(
                          width: 700,
                          child: ListView(
                            shrinkWrap: true,
                            padding: const EdgeInsets.all(16),
                            children: [
                              Text(w.title, style: theme.textTheme.titleLarge),
                              if (w.description.isNotEmpty) Text(w.description),
                              for (final u in w.imageUrls)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Image(
                                    image: CachedNetworkImageProvider(u),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AspectRatio(
                          aspectRatio: 4 / 3,
                          child: CatalogImage(
                            imageUrls: w.imageUrls,
                            placeholderIcon: Icons.image_outlined,
                            borderRadius: BorderRadius.zero,
                          ),
                        ),
                        ListTile(
                          title: Text(w.title),
                          subtitle: w.tags.isEmpty
                              ? null
                              : Text(w.tags.join(' · ')),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Manager: moderate reviews and curate the portfolio.
class ReviewsPortfolioScreen extends StatelessWidget {
  const ReviewsPortfolioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            tabs: [
              Tab(text: context.l10n.reviews),
              Tab(text: context.l10n.portfolio),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [_ModerationTab(), _PortfolioAdminTab()],
            ),
          ),
        ],
      ),
    );
  }
}

final _allReviewsProvider = StreamProvider.autoDispose<List<Review>>(
  (ref) => ref
      .watch(firestoreProvider)
      .collection('Reviews')
      .orderBy('createdAt', descending: true)
      .limit(200)
      .snapshots()
      .map((s) => s.docs.map(Review.fromFirestore).toList())
      .transform(logStreamErrors('[reviews] all failed')),
);

class _ModerationTab extends ConsumerWidget {
  const _ModerationTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviews = ref.watch(_allReviewsProvider).valueOrNull ?? const [];
    final fmt = DateFormat('d MMM y');
    Future<void> setStatus(Review r, String status, [String? reply]) => ref
        .read(firestoreProvider)
        .collection('Reviews')
        .doc(r.orderId)
        .update({
          'status': status,
          'moderatedBy': ref.read(currentUidProvider),
          'reply': ?reply,
        });
    if (reviews.isEmpty) {
      return EmptyState(
        icon: Icons.reviews_outlined,
        title: context.l10n.noReviewsYet,
        message: context.l10n.customersAreAskedToReviewEach,
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final r in reviews)
          Card(
            child: ListTile(
              leading: StarRow(rating: r.rating, size: 14),
              title: Text(
                '${r.customerName} · ${fmt.format(r.createdAt)} · ${r.status}',
              ),
              subtitle: Text(
                [
                  r.comment,
                  if (r.reply != null) context.l10n.reply(r.reply!),
                ].where((s) => s.isNotEmpty).join('\n'),
              ),
              trailing: PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'reply') {
                    final c = TextEditingController(text: r.reply ?? '');
                    final text = await showDialog<String>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text(context.l10n.publicReply),
                        content: TextField(
                          controller: c,
                          maxLines: 3,
                          maxLength: 1000,
                        ),
                        actions: [
                          FilledButton(
                            onPressed: () =>
                                Navigator.pop(context, c.text.trim()),
                            child: Text(context.l10n.save),
                          ),
                        ],
                      ),
                    );
                    if (text != null) await setStatus(r, r.status, text);
                  } else {
                    await setStatus(r, v);
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'approved',
                    child: Text(context.l10n.approvePublish),
                  ),
                  PopupMenuItem(
                    value: 'hidden',
                    child: Text(context.l10n.hide),
                  ),
                  PopupMenuItem(
                    value: 'reply',
                    child: Text(context.l10n.replyPublicly),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _PortfolioAdminTab extends ConsumerWidget {
  const _PortfolioAdminTab();

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final title = TextEditingController();
    final description = TextEditingController();
    final tags = TextEditingController();
    final files = await ImagePicker().pickMultiImage(
      imageQuality: 80,
      maxWidth: 1800,
      limit: 10,
    );
    if (files.isEmpty || !context.mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.newPortfolioEntryPhotoS(files.length)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: title,
              decoration: InputDecoration(labelText: context.l10n.title),
            ),
            TextField(
              controller: description,
              decoration: InputDecoration(labelText: context.l10n.description),
            ),
            TextField(
              controller: tags,
              decoration: InputDecoration(
                labelText: context.l10n.tagsCommaSeparated,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.publish),
          ),
        ],
      ),
    );
    if (ok != true || title.text.trim().length < 2) return;
    try {
      final urls = <String>[];
      for (final f in files) {
        final task = await ref
            .read(firebaseStorageProvider)
            .ref(
              'portfolio/${DateTime.now().millisecondsSinceEpoch}_${urls.length}.jpg',
            )
            .putData(
              await f.readAsBytes(),
              SettableMetadata(contentType: 'image/jpeg'),
            );
        urls.add(await task.ref.getDownloadURL());
      }
      await ref.read(firestoreProvider).collection('Portfolio').add({
        'title': title.text.trim(),
        'description': description.text.trim(),
        'imageUrls': urls,
        'tags': tags.text
            .split(',')
            .map((t) => t.trim())
            .where((t) => t.isNotEmpty)
            .take(10)
            .toList(),
        'category': '',
        'featured': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendlyError(e)),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final works = ref.watch(portfolioProvider).valueOrNull ?? const [];
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context, ref),
        icon: const Icon(Icons.add_photo_alternate_outlined),
        label: Text(context.l10n.addWork),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          for (final w in works)
            Card(
              child: ListTile(
                leading: SizedBox(
                  width: 56,
                  height: 56,
                  child: CatalogImage(
                    imageUrls: w.imageUrls,
                    placeholderIcon: Icons.image_outlined,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                title: Text(w.title),
                subtitle: Text(
                  context.l10n.photosCount(w.imageUrls.length) +
                      (w.featured ? context.l10n.featuredSuffix : ''),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: w.featured
                          ? context.l10n.unfeature
                          : context.l10n.feature,
                      icon: Icon(
                        w.featured
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                      ),
                      onPressed: () => ref
                          .read(firestoreProvider)
                          .collection('Portfolio')
                          .doc(w.id)
                          .update({
                            'featured': !w.featured,
                            'updatedAt': FieldValue.serverTimestamp(),
                          }),
                    ),
                    IconButton(
                      tooltip: context.l10n.delete,
                      icon: const Icon(Icons.delete_outline_rounded),
                      onPressed: () => ref
                          .read(firestoreProvider)
                          .collection('Portfolio')
                          .doc(w.id)
                          .delete(),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
