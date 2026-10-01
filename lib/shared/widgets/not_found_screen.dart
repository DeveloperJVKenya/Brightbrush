import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'empty_state.dart';

/// Shown for an address that matches no page (a typo, or a link to a page
/// that has since moved). Sends the visitor home rather than leaving them
/// on an error.
class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: EmptyState(
            icon: Icons.travel_explore_rounded,
            title: 'Page not found',
            message: 'That link doesn\'t lead anywhere in BrightBrush.',
            action: FilledButton.icon(
              onPressed: () => context.go('/splash'),
              icon: const Icon(Icons.home_rounded),
              label: const Text('Go home'),
            ),
          ),
        ),
      ),
    );
  }
}
