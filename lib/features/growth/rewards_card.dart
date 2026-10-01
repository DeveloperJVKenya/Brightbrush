import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/errors/user_facing_error.dart';
import '../../core/firebase/firebase_providers.dart';
import '../../core/formatting/currency.dart';
import '../payments/application/payments_providers.dart';
import 'growth_providers.dart';
import '../../shared/whatsapp.dart';
import '../../core/l10n/l10n_ext.dart';

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
    final text = context.l10n.getYourCustomBrandingFromUse(
      businessNameOf(context),
      _code ?? '',
      s.referralBonusPoints,
      base,
    );
    await SharePlus.instance.share(ShareParams(text: text));
  }

  Future<void> _enterCode() async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.enterAFriendsCode),
        content: TextField(
          controller: controller,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(
            hintText: 'e.g. JANE4821',
            helperText: context.l10n.onlyBeforeYourFirstOrder,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(context.l10n.apply),
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
      if (mounted) _snack(context.l10n.codeAppliedYoullBothGetBonus);
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
                      context.l10n.rewards,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    context.l10n.pts(points),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
              Text(
                context.l10n.worthOffYouEarnPointS(
                  currencyFormat.format(points * s.pointValue),
                  s.pointsPerHundred,
                ),
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
                        context.l10n.referAFriendPtsEach(s.referralBonusPoints),
                      ),
                    ),
                    TextButton(
                      onPressed: _enterCode,
                      child: Text(context.l10n.iHaveACode),
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
                      tooltip: context.l10n.copy,
                      icon: const Icon(Icons.copy_rounded),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _code!));
                        _snack(context.l10n.copied);
                      },
                    ),
                    FilledButton.icon(
                      onPressed: () => _share(s),
                      icon: const Icon(Icons.share_rounded),
                      label: Text(context.l10n.share),
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
