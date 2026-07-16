import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/settings/settings_providers.dart';

/// Reveals [text] a few characters at a time, like it's being typed live —
/// used for Guide answers (predefined or AI). Renders the full text
/// instantly when the user has "Reduce motion" on in Settings.
class TypewriterText extends ConsumerStatefulWidget {
  const TypewriterText({super.key, required this.text, this.style});

  final String text;
  final TextStyle? style;

  @override
  ConsumerState<TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends ConsumerState<TypewriterText> {
  Timer? _timer;
  int _charsShown = 0;
  static const _charsPerTick = 1;
  static const _tickInterval = Duration(milliseconds: 32);

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(covariant TypewriterText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _timer?.cancel();
      _charsShown = 0;
      _start();
    }
  }

  void _start() {
    if (ref.read(reduceMotionProvider)) {
      _charsShown = widget.text.length;
      return;
    }
    _timer = Timer.periodic(_tickInterval, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _charsShown = (_charsShown + _charsPerTick).clamp(0, widget.text.length));
      if (_charsShown >= widget.text.length) timer.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(widget.text.substring(0, _charsShown), style: widget.style);
  }
}
