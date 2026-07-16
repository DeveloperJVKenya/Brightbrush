import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/settings/settings_providers.dart';
import '../../features/marketing/application/marketing_providers.dart';
import '../../features/marketing/domain/announcement_model.dart';

/// Compact strip of active Marketing announcements, shown above the
/// catalog on the customer Home. Renders nothing while loading, on error,
/// when there's simply nothing active, or when the user has turned off
/// in-app notifications in Settings — this is a bonus, not a blocking
/// element.
class AnnouncementBanner extends ConsumerWidget {
  const AnnouncementBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(inAppNotificationsEnabledProvider)) return const SizedBox.shrink();
    final announcementsAsync = ref.watch(activeAnnouncementsProvider);
    final announcements = announcementsAsync.valueOrNull ?? const <AnnouncementModel>[];
    if (announcements.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 78,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: announcements.length,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (context, index) => _BannerCard(announcement: announcements[index]),
      ),
    );
  }
}

class _BannerCard extends StatelessWidget {
  const _BannerCard({required this.announcement});

  final AnnouncementModel announcement;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 280,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.campaign_outlined, color: theme.colorScheme.onPrimaryContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  announcement.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onPrimaryContainer, fontWeight: FontWeight.w700),
                ),
                Text(
                  announcement.message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onPrimaryContainer),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
