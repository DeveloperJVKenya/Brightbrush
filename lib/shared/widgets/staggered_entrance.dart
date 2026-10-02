import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/settings/settings_providers.dart';

/// Wraps a grid/list item so it fades and slides in with a small delay
/// proportional to its index — a cheap entrance instead of just popping
/// into existence.
///
/// Kept cheap for fast scrolling: only the first screenful animates, and an
/// item with an [id] animates once per session — scrolling it out of view
/// and back (lists rebuild off-screen items) shows it straight away instead
/// of replaying the fade, which used to make fast scrolling stutter.
/// Skipped entirely when "Reduce motion" is on in Settings.
class StaggeredEntrance extends ConsumerStatefulWidget {
  const StaggeredEntrance({
    super.key,
    required this.index,
    required this.child,
    this.id,
  });

  final int index;
  final Widget child;

  /// Stable identity (e.g. the item id) so the entrance plays only once.
  final Object? id;

  /// Items beyond this index never animate (they're below the fold).
  static const animatedItems = 12;

  static final Set<Object> _shown = {};

  @override
  ConsumerState<StaggeredEntrance> createState() => _StaggeredEntranceState();
}

class _StaggeredEntranceState extends ConsumerState<StaggeredEntrance>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
    final id = widget.id;
    final skip =
        ref.read(reduceMotionProvider) ||
        widget.index >= StaggeredEntrance.animatedItems ||
        (id != null && StaggeredEntrance._shown.contains(id));
    if (id != null) StaggeredEntrance._shown.add(id);
    if (skip) return;
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _controller = controller;
    Future.delayed(Duration(milliseconds: 30 * widget.index), () {
      if (mounted) controller.forward();
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) return widget.child;
    final curve = CurvedAnimation(parent: controller, curve: Curves.easeOut);
    return AnimatedBuilder(
      animation: controller,
      // Once finished, drop the fade/slide wrappers entirely (no extra
      // compositing layer per item while scrolling).
      builder: (context, child) => controller.isCompleted
          ? child!
          : FadeTransition(
              opacity: curve,
              child: SlideTransition(
                position: Tween(
                  begin: const Offset(0, 0.06),
                  end: Offset.zero,
                ).animate(curve),
                child: child,
              ),
            ),
      child: widget.child,
    );
  }
}
