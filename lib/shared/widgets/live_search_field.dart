import 'package:flutter/material.dart';

/// A reusable live-search field used across the system (catalog, packages,
/// order lists, etc). Updates on every keystroke — no submit button, no
/// debounce dance — with an animated clear button and a focus-aware border,
/// so search feels immediate everywhere it appears.
class LiveSearchField extends StatefulWidget {
  const LiveSearchField({
    super.key,
    required this.hintText,
    required this.onChanged,
    this.controller,
  });

  final String hintText;
  final ValueChanged<String> onChanged;
  final TextEditingController? controller;

  @override
  State<LiveSearchField> createState() => _LiveSearchFieldState();
}

class _LiveSearchFieldState extends State<LiveSearchField> {
  late final TextEditingController _controller = widget.controller ?? TextEditingController();
  late final FocusNode _focusNode = FocusNode();
  bool _hasText = false;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _hasText = _controller.text.isNotEmpty;
    _controller.addListener(_handleTextChange);
    _focusNode.addListener(() => setState(() => _focused = _focusNode.hasFocus));
  }

  void _handleTextChange() {
    final hasText = _controller.text.isNotEmpty;
    if (hasText != _hasText) setState(() => _hasText = hasText);
    widget.onChanged(_controller.text);
  }

  @override
  void dispose() {
    _controller.removeListener(_handleTextChange);
    if (widget.controller == null) _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _focused ? scheme.primary : scheme.outlineVariant,
          width: _focused ? 1.5 : 1,
        ),
      ),
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: widget.hintText,
          prefixIcon: Icon(Icons.search_rounded, color: scheme.onSurfaceVariant),
          suffixIcon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            child: _hasText
                ? IconButton(
                    key: const ValueKey('clear'),
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => _controller.clear(),
                  )
                : const SizedBox(key: ValueKey('empty'), width: 0),
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}
