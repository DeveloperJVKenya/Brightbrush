import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/settings/settings_providers.dart';

/// Wraps a grid/list item so it fades and slides in with a small delay
/// proportional to its index — a cheap, implicit-animation way to give a
/// data-driven grid an entrance instead of just popping into existence.
/// Skipped entirely when the user has turned on "Reduce motion" in Settings.
class StaggeredEntrance extends ConsumerStatefulWidget {
  const StaggeredEntrance({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  ConsumerState<StaggeredEntrance> createState() => _StaggeredEntranceState();
}

class _StaggeredEntranceState extends ConsumerState<StaggeredEntrance> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    if (ref.read(reduceMotionProvider)) {
      _visible = true;
      return;
    }
    final delay = Duration(milliseconds: 30 * (widget.index % 12));
    Future.delayed(delay, () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
      child: AnimatedSlide(
        offset: _visible ? Offset.zero : const Offset(0, 0.06),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
