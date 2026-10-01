import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/user_facing_error.dart';
import '../../../shared/widgets/empty_state.dart';
import '../application/customization_providers.dart';
import '../domain/artwork.dart';
import 'widgets/artwork_picker.dart';
import '../../../core/l10n/l10n_ext.dart';

/// The customer's logo library: upload once, reuse on every order. Logos
/// staff have digitized show a badge — embroidering them again carries no
/// digitizing fee.
class MyArtworkScreen extends ConsumerStatefulWidget {
  const MyArtworkScreen({super.key});

  @override
  ConsumerState<MyArtworkScreen> createState() => _MyArtworkScreenState();
}

class _MyArtworkScreenState extends ConsumerState<MyArtworkScreen> {
  bool _uploading = false;

  void _snack(String text) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
  );

  Future<void> _upload() async {
    setState(() => _uploading = true);
    try {
      final art = await uploadArtworkFromDevice(context, ref);
      if (art != null && mounted) {
        _snack(context.l10n.addedToYourLibrary(art.name));
      }
    } catch (error) {
      if (mounted) _snack(context.l10n.uploadFailed(friendlyError(error)));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _manage(Artwork art) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(art.name),
              subtitle: Text(
                art.digitized
                    ? context.l10n.digitized +
                          (art.stitchCount != null
                              ? context.l10n.stitchesSuffix(art.stitchCount!)
                              : '')
                    : context.l10n.notDigitizedYet,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(context.l10n.rename),
              onTap: () => Navigator.pop(context, 'rename'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded),
              title: Text(context.l10n.deleteFromLibrary),
              subtitle: Text(context.l10n.pastOrdersKeepTheirCopy),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    final repo = ref.read(customizationRepositoryProvider);
    try {
      if (action == 'rename') {
        final controller = TextEditingController(text: art.name);
        final name = await showDialog<String>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(context.l10n.renameArtwork),
            content: TextField(
              controller: controller,
              maxLength: 80,
              autofocus: true,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(context.l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, controller.text.trim()),
                child: Text(context.l10n.save),
              ),
            ],
          ),
        );
        if (name != null && name.isNotEmpty) {
          await repo.renameArtwork(art.id, name);
        }
      } else if (action == 'delete') {
        await repo.deleteArtwork(art);
        if (mounted) _snack(context.l10n.deleted);
      }
    } catch (error) {
      _snack(friendlyError(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(myArtworksProvider);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: context.l10n.back,
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go('/customer/profile'),
        ),
        title: Text(context.l10n.myArtwork),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _uploading ? null : _upload,
        icon: _uploading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.upload_file_rounded),
        label: Text(context.l10n.uploadLogo),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => EmptyState(
          icon: Icons.cloud_off_rounded,
          title: context.l10n.couldntLoadYourArtwork,
          message: friendlyError(error),
        ),
        data: (artworks) => artworks.isEmpty
            ? EmptyState(
                icon: Icons.palette_outlined,
                title: context.l10n.noArtworkYet,
                message: context.l10n.uploadYourLogoOnceAndReuse,
              )
            : GridView.extent(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
                maxCrossAxisExtent: 200,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                children: [
                  for (final a in artworks)
                    ArtworkTile(artwork: a, onTap: () => _manage(a)),
                ],
              ),
      ),
    );
  }
}
