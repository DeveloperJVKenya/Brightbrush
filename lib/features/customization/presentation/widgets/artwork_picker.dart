import 'package:file_picker/file_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/user_facing_error.dart';
import '../../../../core/firebase/firebase_providers.dart';
import '../../application/customization_providers.dart';
import '../../domain/artwork.dart';
import '../../../../core/l10n/l10n_ext.dart';

const _maxBytes = 25 * 1024 * 1024;
const allowedArtworkExtensions = [
  'png',
  'jpg',
  'jpeg',
  'webp',
  'svg',
  'pdf',
  'ai',
  'eps',
];

/// Picks a file from the device and saves it to the customer's artwork
/// library. Returns null if cancelled.
Future<Artwork?> uploadArtworkFromDevice(
  BuildContext context,
  WidgetRef ref,
) async {
  final uid = ref.read(currentUidProvider);
  if (uid == null) return null;
  final file = await FilePicker.pickFile(
    type: FileType.custom,
    allowedExtensions: allowedArtworkExtensions,
  );
  if (file == null) return null;
  if ((await file.length() ?? 0) > _maxBytes) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.thatFileIsOver25Mb),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    return null;
  }
  final baseName = file.name.contains('.')
      ? file.name.substring(0, file.name.lastIndexOf('.'))
      : file.name;
  return ref
      .read(customizationRepositoryProvider)
      .uploadArtwork(
        uid: uid,
        name: baseName.isEmpty
            ? 'Logo'
            : baseName.substring(0, baseName.length.clamp(0, 80)),
        fileName: file.name,
        bytes: await file.xFile.readAsBytes(),
      );
}

/// Bottom sheet: choose a logo from the library or upload a new one.
Future<Artwork?> showArtworkPicker(BuildContext context) {
  return showModalBottomSheet<Artwork>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (context) => const _ArtworkPickerSheet(),
  );
}

class _ArtworkPickerSheet extends ConsumerStatefulWidget {
  const _ArtworkPickerSheet();

  @override
  ConsumerState<_ArtworkPickerSheet> createState() =>
      _ArtworkPickerSheetState();
}

class _ArtworkPickerSheetState extends ConsumerState<_ArtworkPickerSheet> {
  bool _uploading = false;

  Future<void> _upload() async {
    setState(() => _uploading = true);
    try {
      final art = await uploadArtworkFromDevice(context, ref);
      if (art != null && mounted) Navigator.of(context).pop(art);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.uploadFailed(friendlyError(error))),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final artworks = ref.watch(myArtworksProvider).valueOrNull ?? const [];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.l10n.chooseYourArtwork,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            context.l10n.pngWithATransparentBackgroundGives,
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _uploading ? null : _upload,
            icon: _uploading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.upload_file_rounded),
            label: Text(context.l10n.uploadNewArtwork),
          ),
          if (artworks.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(context.l10n.yourLibrary, style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: GridView.count(
                shrinkWrap: true,
                crossAxisCount: 3,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                children: [
                  for (final a in artworks)
                    ArtworkTile(
                      artwork: a,
                      onTap: () => Navigator.of(context).pop(a),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class ArtworkTile extends StatelessWidget {
  const ArtworkTile({super.key, required this.artwork, this.onTap});

  final Artwork artwork;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: artwork.isPreviewable
                    ? Image(
                        image: CachedNetworkImageProvider(artwork.fileUrl),
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stack) =>
                            const Icon(Icons.image_not_supported_outlined),
                      )
                    : Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.insert_drive_file_outlined,
                              size: 32,
                            ),
                            Text(
                              artwork.contentType.split('/').last.toUpperCase(),
                              style: theme.textTheme.labelSmall,
                            ),
                          ],
                        ),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
              child: Row(
                children: [
                  if (artwork.digitized)
                    Padding(
                      padding: EdgeInsets.only(right: 4),
                      child: Tooltip(
                        message: context.l10n.digitizedNoSetupFeeForEmbroidery,
                        child: Icon(
                          Icons.verified_rounded,
                          size: 14,
                          color: Colors.green,
                        ),
                      ),
                    ),
                  Expanded(
                    child: Text(
                      artwork.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
