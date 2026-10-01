import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/user_facing_error.dart';
import '../../../core/firebase/firebase_providers.dart';
import '../../../shared/widgets/announcement_banner.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../payments/application/payments_providers.dart';
import '../application/notifications_providers.dart';
import '../../../l10n/app_localizations.dart';
import '../data/notifications_repository.dart';
import '../../../core/l10n/l10n_ext.dart';

/// Every notice for the signed-in user (order moves, proofs, payments,
/// messages, reminders), plus which channels they want them on.
class InboxScreen extends ConsumerWidget {
  const InboxScreen({super.key, this.standalone = false});

  /// True when opened from the bell (own Scaffold/back button).
  final bool standalone;

  static IconData _icon(String type) => switch (type.split('.').first) {
    'order' => Icons.local_shipping_outlined,
    'payment' => Icons.payments_outlined,
    'quote' => Icons.request_quote_outlined,
    'chat' => Icons.chat_bubble_outline_rounded,
    'loyalty' => Icons.card_giftcard_rounded,
    'marketing' => Icons.shopping_cart_outlined,
    'staff' => Icons.notifications_active_outlined,
    _ => Icons.notifications_none_rounded,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(inboxProvider);
    final fmt = DateFormat('d MMM, HH:mm');
    final body = async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(
        icon: Icons.cloud_off_rounded,
        title: context.l10n.couldntLoadNotifications,
        message: friendlyError(e),
      ),
      data: (items) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!standalone) const AnnouncementBanner(),
          const _PushPrompt(),
          Row(
            children: [
              Expanded(
                child: Text(
                  context.l10n.unread(items.where((n) => !n.read).length),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              TextButton(
                onPressed: items.any((n) => !n.read)
                    ? () => ref
                          .read(notificationsRepositoryProvider)
                          .markAllRead(items)
                    : null,
                child: Text(AppLocalizations.of(context).markAllRead),
              ),
              IconButton(
                tooltip: context.l10n.notificationSettings,
                icon: const Icon(Icons.tune_rounded),
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  showDragHandle: true,
                  builder: (_) => const _PrefsSheet(),
                ),
              ),
            ],
          ),
          if (items.isEmpty)
            EmptyState(
              icon: Icons.notifications_none_rounded,
              title: AppLocalizations.of(context).noNotifications,
              message: context.l10n.orderUpdatesProofsPaymentsAndMessages,
            ),
          for (final n in items)
            Dismissible(
              key: ValueKey(n.id),
              direction: DismissDirection.endToStart,
              onDismissed: (_) =>
                  ref.read(notificationsRepositoryProvider).delete(n.id),
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                child: const Icon(Icons.delete_outline_rounded),
              ),
              child: Card(
                child: ListTile(
                  leading: Badge(
                    isLabelVisible: !n.read,
                    child: Icon(_icon(n.type)),
                  ),
                  title: Text(
                    n.title,
                    style: TextStyle(
                      fontWeight: n.read ? FontWeight.w400 : FontWeight.w700,
                    ),
                  ),
                  subtitle: Text('${n.body}\n${fmt.format(n.createdAt)}'),
                  isThreeLine: true,
                  onTap: () {
                    if (!n.read) {
                      ref.read(notificationsRepositoryProvider).markRead(n.id);
                    }
                    if (n.link != null && n.link!.isNotEmpty) {
                      context.push(n.link!);
                    }
                  },
                ),
              ),
            ),
        ],
      ),
    );
    if (!standalone) return body;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
        title: Text(AppLocalizations.of(context).notificationsTitle),
      ),
      body: body,
    );
  }
}

/// Offers to switch on push for this device (only shown until it works).
class _PushPrompt extends ConsumerStatefulWidget {
  const _PushPrompt();

  @override
  ConsumerState<_PushPrompt> createState() => _PushPromptState();
}

class _PushPromptState extends ConsumerState<_PushPrompt> {
  bool _done = false;

  @override
  Widget build(BuildContext context) {
    if (_done) return const SizedBox.shrink();
    return Card(
      child: ListTile(
        leading: const Icon(Icons.notifications_active_outlined),
        title: Text(context.l10n.getAlertsOnThisDevice),
        subtitle: Text(context.l10n.orderUpdatesAndMessagesEvenWhen),
        trailing: FilledButton(
          onPressed: () async {
            final uid = ref.read(currentUidProvider);
            if (uid == null) return;
            final vapid = ref
                .read(businessSettingsProvider)
                .valueOrNull
                ?.webPushVapidKey;
            final ok = await ref
                .read(notificationsRepositoryProvider)
                .registerDevice(uid, vapidKey: vapid);
            if (!context.mounted) return;
            setState(() => _done = ok);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  ok
                      ? context.l10n.alertsSwitchedOnForThisDevice
                      : context.l10n.couldntSwitchOnAlertsCheckYour,
                ),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
          child: Text(context.l10n.turnOn),
        ),
      ),
    );
  }
}

class _PrefsSheet extends ConsumerWidget {
  const _PrefsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs =
        ref.watch(notificationPrefsProvider).valueOrNull ??
        const NotificationPrefs();
    void save(NotificationPrefs p) {
      final uid = ref.read(currentUidProvider);
      if (uid != null) {
        ref.read(notificationsRepositoryProvider).savePrefs(uid, p);
      }
    }

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text(context.l10n.howShouldWeReachYou),
            subtitle: Text(context.l10n.theInAppInboxAlwaysGets),
          ),
          SwitchListTile(
            title: Text(context.l10n.pushNotifications),
            value: prefs.push,
            onChanged: (v) => save(
              NotificationPrefs(
                push: v,
                email: prefs.email,
                whatsapp: prefs.whatsapp,
                marketing: prefs.marketing,
              ),
            ),
          ),
          SwitchListTile(
            title: Text(context.l10n.email),
            value: prefs.email,
            onChanged: (v) => save(
              NotificationPrefs(
                push: prefs.push,
                email: v,
                whatsapp: prefs.whatsapp,
                marketing: prefs.marketing,
              ),
            ),
          ),
          SwitchListTile(
            title: const Text('WhatsApp'),
            subtitle: Text(context.l10n.usesThePhoneNumberOnYour),
            value: prefs.whatsapp,
            onChanged: (v) => save(
              NotificationPrefs(
                push: prefs.push,
                email: prefs.email,
                whatsapp: v,
                marketing: prefs.marketing,
              ),
            ),
          ),
          SwitchListTile(
            title: Text(context.l10n.remindersOffers),
            subtitle: Text(context.l10n.cartRemindersAndPromotions),
            value: prefs.marketing,
            onChanged: (v) => save(
              NotificationPrefs(
                push: prefs.push,
                email: prefs.email,
                whatsapp: prefs.whatsapp,
                marketing: v,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// App-bar bell with the unread count; opens the inbox.
class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(currentUidProvider) == null) return const SizedBox.shrink();
    final unread = ref.watch(unreadCountProvider);
    return IconButton(
      tooltip: context.l10n.notificationsTitle,
      onPressed: () => context.push('/notifications'),
      icon: Badge(
        isLabelVisible: unread > 0,
        label: Text(unread > 99 ? '99+' : '$unread'),
        child: const Icon(Icons.notifications_none_rounded),
      ),
    );
  }
}
