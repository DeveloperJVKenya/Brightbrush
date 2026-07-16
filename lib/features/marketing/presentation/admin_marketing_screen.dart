import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/empty_state.dart';
import '../application/marketing_providers.dart';
import '../domain/announcement_model.dart';
import 'widgets/announcement_form_sheet.dart';

class AdminMarketingScreen extends ConsumerWidget {
  const AdminMarketingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final announcementsAsync = ref.watch(allAnnouncementsProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showAnnouncementFormSheet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New announcement'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Marketing', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                'Announcements shown on every signed-in user\'s Home and Notifications feed.',
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: announcementsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, stack) =>
                      EmptyState(icon: Icons.cloud_off_rounded, title: 'Couldn\'t load announcements', message: '$error'),
                  data: (announcements) {
                    if (announcements.isEmpty) {
                      return const EmptyState(
                        icon: Icons.campaign_outlined,
                        title: 'Nothing published yet',
                        message: 'Announce seasonal offers or brand news — they\'ll show on every customer\'s Home.',
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.only(bottom: 100),
                      itemCount: announcements.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 10),
                      itemBuilder: (context, index) => _AnnouncementRow(announcement: announcements[index]),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnnouncementRow extends ConsumerWidget {
  const _AnnouncementRow({required this.announcement});

  final AnnouncementModel announcement;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: announcement.imageUrl != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(announcement.imageUrl!, width: 48, height: 48, fit: BoxFit.cover),
              )
            : CircleAvatar(child: Icon(Icons.campaign_outlined, color: theme.colorScheme.primary)),
        title: Text(announcement.title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(announcement.message, maxLines: 2, overflow: TextOverflow.ellipsis),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: announcement.isActive,
              onChanged: (v) => ref.read(announcementsRepositoryProvider).update(AnnouncementModel(
                    id: announcement.id,
                    title: announcement.title,
                    message: announcement.message,
                    imageUrl: announcement.imageUrl,
                    isActive: v,
                    validFrom: announcement.validFrom,
                    validTo: announcement.validTo,
                    createdBy: announcement.createdBy,
                    createdAt: announcement.createdAt,
                    updatedAt: DateTime.now(),
                  )),
            ),
            IconButton(
              tooltip: 'Edit',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => showAnnouncementFormSheet(context, ref, existing: announcement),
            ),
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => ref.read(announcementsRepositoryProvider).delete(announcement.id),
            ),
          ],
        ),
      ),
    );
  }
}
