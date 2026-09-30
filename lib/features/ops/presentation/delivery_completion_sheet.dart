import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/errors/user_facing_error.dart';
import '../../orders/domain/order_model.dart';
import '../application/ops_providers.dart';

/// Hand an order over with proof: the customer's 4-digit code, or a photo
/// of the handover plus the recipient's signature. Used by drivers (route
/// map, My Deliveries) and store staff for pickups.
Future<bool?> showDeliveryCompletionSheet(
  BuildContext context,
  OrderModel order,
) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (context) => _CompletionSheet(order: order),
  );
}

class _CompletionSheet extends ConsumerStatefulWidget {
  const _CompletionSheet({required this.order});

  final OrderModel order;

  @override
  ConsumerState<_CompletionSheet> createState() => _CompletionSheetState();
}

class _CompletionSheetState extends ConsumerState<_CompletionSheet> {
  late final _name = TextEditingController(text: widget.order.contactName);
  final _code = TextEditingController();
  final _signatureKey = GlobalKey<_SignaturePadState>();
  bool _useCode = true;
  Uint8List? _photo;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _takePhoto() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
      maxWidth: 1600,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() => _photo = bytes);
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      Uint8List? signature;
      if (!_useCode) {
        signature = await _signatureKey.currentState?.toPng();
        if (_photo == null || signature == null) {
          setState(
            () =>
                _error = 'Take a handover photo and get the recipient to sign.',
          );
          return;
        }
      }
      await ref
          .read(opsRepositoryProvider)
          .completeDelivery(
            orderId: widget.order.id,
            recipientName: _name.text.trim(),
            code: _useCode ? _code.text.trim() : null,
            photo: _useCode ? null : _photo,
            signaturePng: signature,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
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
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.order.isPickup
                  ? 'Hand over (pickup)'
                  : 'Complete delivery',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              '${widget.order.displayNumber} · ${widget.order.contactName}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Received by'),
            ),
            const SizedBox(height: 12),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: true,
                  label: Text('Customer code'),
                  icon: Icon(Icons.pin_outlined),
                ),
                ButtonSegment(
                  value: false,
                  label: Text('Photo + signature'),
                  icon: Icon(Icons.draw_outlined),
                ),
              ],
              selected: {_useCode},
              onSelectionChanged: (v) => setState(() => _useCode = v.first),
            ),
            const SizedBox(height: 12),
            if (_useCode)
              TextField(
                controller: _code,
                keyboardType: TextInputType.number,
                maxLength: 4,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: theme.textTheme.headlineSmall?.copyWith(
                  letterSpacing: 12,
                ),
                textAlign: TextAlign.center,
                decoration: const InputDecoration(
                  labelText: '4-digit code from the customer',
                  helperText: 'The customer sees it on their order page.',
                ),
              )
            else ...[
              OutlinedButton.icon(
                onPressed: _takePhoto,
                icon: const Icon(Icons.photo_camera_outlined),
                label: Text(
                  _photo == null ? 'Take handover photo' : 'Retake photo',
                ),
              ),
              if (_photo != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      _photo!,
                      height: 140,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              Text('Recipient signature', style: theme.textTheme.labelLarge),
              const SizedBox(height: 6),
              SignaturePad(key: _signatureKey),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _busy ? null : _submit,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_circle_outline_rounded),
              label: const Text('Confirm handover'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Finger/mouse signature capture, exported as a PNG.
class SignaturePad extends StatefulWidget {
  const SignaturePad({super.key, this.height = 160});

  final double height;

  @override
  State<SignaturePad> createState() => _SignaturePadState();
}

class _SignaturePadState extends State<SignaturePad> {
  final List<List<Offset>> _strokes = [];
  Size _size = Size.zero;

  bool get isEmpty => _strokes.every((s) => s.length < 2);

  Future<Uint8List?> toPng() async {
    if (isEmpty || _size == Size.zero) return null;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(Offset.zero & _size, Paint()..color = Colors.white);
    _SignaturePainter(_strokes, Colors.black).paint(canvas, _size);
    final image = await recorder.endRecording().toImage(
      _size.width.ceil(),
      _size.height.ceil(),
    );
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            _size = Size(constraints.maxWidth, widget.height);
            return GestureDetector(
              onPanStart: (d) =>
                  setState(() => _strokes.add([d.localPosition])),
              onPanUpdate: (d) =>
                  setState(() => _strokes.last.add(d.localPosition)),
              child: Container(
                height: widget.height,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: theme.colorScheme.outline),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: CustomPaint(
                  painter: _SignaturePainter(_strokes, Colors.black),
                  size: Size.infinite,
                ),
              ),
            );
          },
        ),
        Positioned(
          right: 4,
          top: 4,
          child: IconButton(
            tooltip: 'Clear',
            icon: const Icon(Icons.refresh_rounded, color: Colors.black54),
            onPressed: () => setState(_strokes.clear),
          ),
        ),
      ],
    );
  }
}

class _SignaturePainter extends CustomPainter {
  _SignaturePainter(this.strokes, this.color);

  final List<List<Offset>> strokes;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final stroke in strokes) {
      if (stroke.length < 2) continue;
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (final p in stroke.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter old) => true;
}
