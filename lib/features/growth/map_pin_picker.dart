import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/l10n/l10n_ext.dart';

/// Tap the map to drop the delivery pin (drivers get exact coordinates
/// instead of a geocoded guess). Returns the chosen point, or null.
Future<LatLng?> pickLocationOnMap(BuildContext context, {LatLng? initial}) {
  return showDialog<LatLng>(
    context: context,
    builder: (context) => _PinDialog(initial: initial),
  );
}

class _PinDialog extends StatefulWidget {
  const _PinDialog({this.initial});

  final LatLng? initial;

  @override
  State<_PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<_PinDialog> {
  // Nairobi CBD.
  static const _nairobi = LatLng(-1.2864, 36.8172);
  late LatLng? _pin = widget.initial;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.l10n.dropAPinOnYourDelivery),
      contentPadding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      content: SizedBox(
        width: 560,
        height: 420,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: GoogleMap(
            initialCameraPosition: CameraPosition(
              target: widget.initial ?? _nairobi,
              zoom: widget.initial == null ? 11 : 16,
            ),
            onTap: (p) => setState(() => _pin = p),
            myLocationButtonEnabled: false,
            markers: {
              if (_pin != null)
                Marker(markerId: const MarkerId('pin'), position: _pin!),
            },
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          onPressed: _pin == null ? null : () => Navigator.pop(context, _pin),
          child: Text(context.l10n.useThisSpot),
        ),
      ],
    );
  }
}
