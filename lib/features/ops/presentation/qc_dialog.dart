import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/errors/user_facing_error.dart';
import '../application/ops_providers.dart';

/// Must match QC_CHECKLIST in functions/src/ops/ops_callables.ts (the
/// server checks items by index).
const qcChecklist = [
  'Items and quantities match the order',
  'Sizes and colours correct',
  'Placement matches the approved proof',
  'Stitching / print quality (no gaps, bleeding or puckering)',
  'Clean — no loose threads, stains or marks',
  'Folded, packed and labelled',
];

/// Final inspection before handover. Passing moves the order to "ready for
/// delivery"; failing sends it back to production with the reason.
Future<void> showQualityCheckDialog(
  BuildContext context, {
  required String orderId,
  required String orderLabel,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _QcDialog(orderId: orderId, orderLabel: orderLabel),
  );
}

class _QcDialog extends ConsumerStatefulWidget {
  const _QcDialog({required this.orderId, required this.orderLabel});

  final String orderId;
  final String orderLabel;

  @override
  ConsumerState<_QcDialog> createState() => _QcDialogState();
}

class _QcDialogState extends ConsumerState<_QcDialog> {
  final Map<int, bool> _checks = {};
  final _notes = TextEditingController();
  final List<(Uint8List, String)> _photos = [];
  bool _busy = false;

  bool get _allOk => List.generate(
    qcChecklist.length,
    (i) => _checks[i] == true,
  ).every((v) => v);

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _addPhoto() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
      maxWidth: 1600,
    );
    if (file == null) return;
    _photos.add((await file.readAsBytes(), 'image/jpeg'));
    setState(() {});
  }

  Future<void> _submit(bool passed) async {
    setState(() => _busy = true);
    try {
      await ref
          .read(opsRepositoryProvider)
          .recordQualityCheck(
            orderId: widget.orderId,
            passed: passed,
            checks: _checks,
            notes: _notes.text.trim(),
            photos: _photos,
          );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              passed ? 'Passed — ready for delivery' : 'Sent back for rework',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
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
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Quality check · ${widget.orderLabel}'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (i, label) in qcChecklist.indexed)
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(label),
                  value: _checks[i] ?? false,
                  onChanged: (v) => setState(() => _checks[i] = v ?? false),
                ),
              TextField(
                controller: _notes,
                maxLines: 2,
                maxLength: 1000,
                decoration: const InputDecoration(
                  labelText: 'Notes (required if it fails)',
                ),
              ),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: _photos.length < 6 ? _addPhoto : null,
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: Text('Photos (${_photos.length})'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        OutlinedButton(
          onPressed: _busy ? null : () => _submit(false),
          child: const Text('Fail — rework'),
        ),
        FilledButton(
          onPressed: _busy || !_allOk ? null : () => _submit(true),
          child: const Text('Pass'),
        ),
      ],
    );
  }
}
