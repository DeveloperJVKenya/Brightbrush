import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/errors/user_facing_error.dart';
import '../../core/firebase/firebase_providers.dart';
import '../../core/formatting/currency.dart';
import '../payments/application/payments_providers.dart';
import 'growth_providers.dart';

/// Profile card: loyalty points, the customer's referral code to share,
/// and a place to enter a friend's code before the first order.
class RewardsCard extends ConsumerStatefulWidget {
  const RewardsCard({super.key});

  @override
  ConsumerState<RewardsCard> createState() => _RewardsCardState();
}

class _RewardsCardState extends ConsumerState<RewardsCard> {
  String? _code;
  bool _busy = false;

  void _snack(String t) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(t), behavior: SnackBarBehavior.floating),
  );

  Future<void> _getCode() async {
    setState(() => _busy = true);
    try {
      final r = await ref
          .read(firebaseFunctionsProvider)
          .httpsCallable('getMyReferralCode')
          .call();
      setState(() => _code = (r.data as Map)['code'] as String?);
    } catch (e) {
      _snack(friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share(LoyaltySettings s) async {
    final base =
        ref.read(businessSettingsProvider).valueOrNull?.appBaseUrl ??
        'https://bright-brush.web.app';
    final text =
        'Get your custom branding from BrightBrush Creations! Use my code $_code when you sign up '
        'and we both get ${s.referralBonusPoints} points after your first order. $base';
    await SharePlus.instance.share(ShareParams(text: text));
  }

  Future<void> _enterCode() async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter a friend\'s code'),
        content: TextField(
          controller: controller,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            hintText: 'e.g. JANE4821',
            helperText: 'Only before your first order.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    if (code == null || code.isEmpty) return;
    try {
      await ref
          .read(firebaseFunctionsProvider)
          .httpsCallable('claimReferral')
          .call({'code': code});
      _snack(
        'Code applied — you\'ll both get bonus points after your first order.',
      );
    } catch (e) {
      _snack(friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s =
        ref.watch(loyaltySettingsProvider).valueOrNull ??
        const LoyaltySettings();
    if (!s.enabled) return const SizedBox.shrink();
    final points = ref.watch(myPointsProvider).valueOrNull ?? 0;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.card_giftcard_rounded),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Rewards',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    '$points pts',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
              Text(
                'Worth ${currencyFormat.format(points * s.pointValue)} off. You earn ${s.pointsPerHundred} point(s) for every KES 100 you spend.',
                style: theme.textTheme.bodySmall,
              ),
              const Divider(height: 24),
              if (_code == null)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: _busy ? null : _getCode,
                      icon: const Icon(Icons.group_add_outlined),
                      label: Text(
                        'Refer a friend (+${s.referralBonusPoints} pts each)',
                      ),
                    ),
                    TextButton(
                      onPressed: _enterCode,
                      child: const Text('I have a code'),
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: SelectableText(
                        _code!,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          letterSpacing: 3,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Copy',
                      icon: const Icon(Icons.copy_rounded),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _code!));
                        _snack('Copied');
                      },
                    ),
                    FilledButton.icon(
                      onPressed: () => _share(s),
                      icon: const Icon(Icons.share_rounded),
                      label: const Text('Share'),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
