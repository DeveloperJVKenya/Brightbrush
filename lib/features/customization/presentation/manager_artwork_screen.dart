import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/errors/user_facing_error.dart';
import '../../../shared/widgets/empty_state.dart';
import '../application/customization_providers.dart';
import '../domain/artwork.dart';
import 'widgets/artwork_picker.dart';

/// Production's artwork desk: every customer logo, with the digitizing
/// queue first. Staff download originals, attach machine files
/// (DST/EMB/PES...) and record the stitch count — which waives the
/// digitizing fee on repeat orders and prices embroidery by stitches.
class ManagerArtworkScreen extends ConsumerStatefulWidget {
  const ManagerArtworkScreen({super.key});

  @override
  ConsumerState<ManagerArtworkScreen> createState() =>
      _ManagerArtworkScreenState();
}

class _ManagerArtworkScreenState extends ConsumerState<ManagerArtworkScreen> {
  bool _queueOnly = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final async = ref.watch(allArtworksProvider);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      children: [
        Text(
          'Artwork & digitizing',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Customer logos. Attach embroidery files and stitch counts once digitized.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: true, label: Text('Needs digitizing')),
            ButtonSegment(value: false, label: Text('All artwork')),
          ],
          selected: {_queueOnly},
          onSelectionChanged: (v) => setState(() => _queueOnly = v.first),
        ),
        const SizedBox(height: 12),
        ...async.when(
          loading: () => const [Center(child: CircularProgressIndicator())],
          error: (error, stack) => [
            EmptyState(
              icon: Icons.cloud_off_rounded,
              title: 'Couldn\'t load artwork',
              message: friendlyError(error),
            ),
          ],
          data: (all) {
            final shown = _queueOnly
                ? all.where((a) => !a.digitized).toList()
                : all;
            if (shown.isEmpty) {
              return const [
                EmptyState(
                  icon: Icons.task_alt_rounded,
                  title: 'All caught up',
                  message: 'No artwork is waiting to be digitized.',
                ),
              ];
            }
            return [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final a in shown)
                    SizedBox(
                      width: 170,
                      height: 190,
                      child: ArtworkTile(
                        artwork: a,
                        onTap: () => showDialog<void>(
                          context: context,
                          builder: (context) => _DigitizeDialog(artwork: a),
                        ),
                      ),
                    ),
                ],
              ),
            ];
          },
        ),
      ],
    );
  }
}

class _DigitizeDialog extends ConsumerStatefulWidget {
  const _DigitizeDialog({required this.artwork});

  final Artwork artwork;

  @override
  ConsumerState<_DigitizeDialog> createState() => _DigitizeDialogState();
}

class _DigitizeDialogState extends ConsumerState<_DigitizeDialog> {
  late final _stitches = TextEditingController(
    text: widget.artwork.stitchCount?.toString() ?? '',
  );
  late final _threads = TextEditingController(
    text: widget.artwork.threadCount?.toString() ?? '',
  );
  late final _notes = TextEditingController(text: widget.artwork.staffNotes);
  late final List<DigitizedFile> _files = [...widget.artwork.digitizedFiles];
  late bool _digitized = widget.artwork.digitized;
  bool _busy = false;

  @override
  void dispose() {
    _stitches.dispose();
    _threads.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _snack(String text) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
  );

  Future<void> _attach() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const [
        'dst',
        'emb',
        'pes',
        'exp',
        'jef',
        'vp3',
        'xxx',
        'hus',
        'pdf',
      ],
    );
    if (file == null) return;
    setState(() => _busy = true);
    try {
      final uploaded = await ref
          .read(customizationRepositoryProvider)
          .uploadDigitizedFile(
            artwork: widget.artwork,
            fileName: file.name,
            bytes: await file.xFile.readAsBytes(),
          );
      setState(() {
        _files.add(uploaded);
        _digitized = true;
      });
    } catch (error) {
      _snack('Upload failed: ${friendlyError(error)}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(customizationRepositoryProvider)
          .saveDigitizing(
            artworkId: widget.artwork.id,
            digitized: _digitized,
            stitchCount: int.tryParse(_stitches.text.trim()),
            threadCount: int.tryParse(_threads.text.trim()),
            files: _files,
            staffNotes: _notes.text.trim(),
          );
      if (mounted) {
        Navigator.pop(context);
        _snack('Saved');
      }
    } catch (error) {
      _snack(friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.artwork;
    return AlertDialog(
      title: Text(a.name),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 160, child: ArtworkTile(artwork: a)),
              Text(
                '${a.contentType} · ${(a.sizeBytes / 1024).round()} KB · uploaded ${DateFormat('d MMM y').format(a.createdAt)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              TextButton.icon(
                onPressed: () => launchUrl(Uri.parse(a.fileUrl)),
                icon: const Icon(Icons.download_rounded),
                label: const Text('Download original'),
              ),
              const Divider(),
              for (final f in _files)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.insert_drive_file_outlined),
                  title: Text(f.name),
                  subtitle: Text(f.format),
                  trailing: IconButton(
                    tooltip: 'Remove from list',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => setState(() => _files.remove(f)),
                  ),
                  onTap: () => launchUrl(Uri.parse(f.url)),
                ),
              OutlinedButton.icon(
                onPressed: _busy ? null : _attach,
                icon: const Icon(Icons.attach_file_rounded),
                label: const Text('Attach machine file (DST, EMB, PES…)'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _stitches,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Stitch count',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _threads,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Thread colours',
                      ),
                    ),
                  ),
                ],
              ),
              TextField(
                controller: _notes,
                maxLength: 1000,
                decoration: const InputDecoration(
                  labelText: 'Production notes',
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Digitized'),
                subtitle: const Text(
                  'Waives the digitizing fee and prices embroidery by stitch count.',
                ),
                value: _digitized,
                onChanged: (v) => setState(() => _digitized = v),
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
        FilledButton(
          onPressed: _busy ? null : _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
