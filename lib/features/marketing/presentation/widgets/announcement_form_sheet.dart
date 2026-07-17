import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../../../core/errors/user_facing_error.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../catalog/application/catalog_providers.dart';
import '../../application/marketing_providers.dart';
import '../../domain/announcement_model.dart';

/// Create/edit form for a marketing announcement. Image upload degrades
/// gracefully, same as the catalog item form: if it fails, the announcement
/// still saves without a photo.
Future<void> showAnnouncementFormSheet(BuildContext context, WidgetRef ref, {AnnouncementModel? existing}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (context) => _AnnouncementFormSheet(existing: existing),
  );
}

class _AnnouncementFormSheet extends ConsumerStatefulWidget {
  const _AnnouncementFormSheet({this.existing});

  final AnnouncementModel? existing;

  @override
  ConsumerState<_AnnouncementFormSheet> createState() => _AnnouncementFormSheetState();
}

class _AnnouncementFormSheetState extends ConsumerState<_AnnouncementFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.existing?.title ?? '');
  late final _message = TextEditingController(text: widget.existing?.message ?? '');
  late bool _isActive = widget.existing?.isActive ?? true;

  Uint8List? _pickedImageBytes;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() => _pickedImageBytes = bytes);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final repo = ref.read(announcementsRepositoryProvider);
    final uid = ref.read(currentUidProvider);
    if (uid == null) {
      appLogger.w('[marketing] Save attempted with no signed-in uid — this will fail Firestore rules (createdBy required)');
    }

    try {
      final base = AnnouncementModel(
        id: widget.existing?.id ?? '',
        title: _title.text.trim(),
        message: _message.text.trim(),
        imageUrl: widget.existing?.imageUrl,
        isActive: _isActive,
        validFrom: widget.existing?.validFrom,
        validTo: widget.existing?.validTo,
        createdBy: widget.existing?.createdBy ?? uid ?? '',
        createdAt: widget.existing?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      String announcementId;
      if (widget.existing == null) {
        announcementId = await repo.create(base, uid: uid ?? '');
        appLogger.i('[marketing] Created announcement $announcementId (createdBy=$uid)');
      } else {
        announcementId = widget.existing!.id;
        await repo.update(base);
        appLogger.i('[marketing] Updated announcement $announcementId');
      }

      if (_pickedImageBytes != null) {
        try {
          final uploader = ref.read(catalogImageUploaderProvider);
          final url = await uploader.uploadAnnouncementImage(
            announcementId: announcementId,
            bytes: _pickedImageBytes!,
            contentType: 'image/jpeg',
          );
          await repo.update(AnnouncementModel(
            id: announcementId,
            title: base.title,
            message: base.message,
            imageUrl: url,
            isActive: base.isActive,
            validFrom: base.validFrom,
            validTo: base.validTo,
            createdBy: base.createdBy,
            createdAt: base.createdAt,
            updatedAt: DateTime.now(),
          ));
        } catch (error, stack) {
          appLogger.w('[marketing] Image upload failed for announcement $announcementId — saved without a photo',
              error: error, stackTrace: stack);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Saved without a photo — Storage isn\'t activated on this project yet.'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      }

      if (mounted) Navigator.of(context).pop();
    } catch (error, stack) {
      appLogger.e('[marketing] Failed to save announcement', error: error, stackTrace: stack);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Couldn\'t save: ${friendlyError(error)}'), behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 4, bottom: MediaQuery.viewInsetsOf(context).bottom + 24),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.existing == null ? 'New announcement' : 'Edit announcement',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 140,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _pickedImageBytes != null
                      ? Image.memory(_pickedImageBytes!, fit: BoxFit.cover, width: double.infinity)
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate_outlined, color: theme.colorScheme.onSurfaceVariant),
                            const SizedBox(height: 6),
                            Text('Add a banner photo (optional)', style: theme.textTheme.bodySmall),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _title,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (v) => (v == null || v.trim().length < 2) ? 'Enter a title (2+ chars)' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _message,
                decoration: const InputDecoration(labelText: 'Message'),
                maxLines: 3,
                validator: (v) => (v == null || v.trim().length < 2) ? 'Enter a message' : null,
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Active (visible to everyone)'),
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(widget.existing == null ? 'Publish' : 'Save changes'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
