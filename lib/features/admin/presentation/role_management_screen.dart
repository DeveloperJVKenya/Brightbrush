import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/auth/app_role.dart';
import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/founding_developer.dart';
import '../../../core/errors/user_facing_error.dart';
import '../../../core/firebase/firebase_providers.dart';
import '../../../core/formatting/currency.dart';
import '../../../core/logging/app_logger.dart';
import '../../../shared/search/search_utils.dart';
import '../../../shared/whatsapp.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/live_search_field.dart';
import '../../auth/domain/user_profile.dart';

enum _AccountAction {
  details,
  changeRole,
  revoke,
  setWage,
  whatsapp,
  call,
  email,
  copyEmail,
  copyUid,
  suspend,
  reactivate,
}

/// Role filter chips: "All", one per [AppRole], plus "Suspended".
enum _RoleFilter {
  all,
  user,
  deliveryStaff,
  systemManager,
  admin,
  developer,
  suspended;

  String get label => switch (this) {
    _RoleFilter.all => 'All',
    _RoleFilter.suspended => 'Suspended',
    _ => AppRole.fromRoleName(name).label,
  };

  bool matches(UserProfile p) => switch (this) {
    _RoleFilter.all => true,
    _RoleFilter.suspended => p.disabled,
    _ => p.role.name == name,
  };
}

final _roleManagementSearchProvider = StateProvider<String>((ref) => '');

const _twoColumnBreakpoint = 700.0;

/// Roles paid a daily wage (see Employees) — the only ones "Set daily wage"
/// is offered for.
const _wageRoles = {AppRole.deliveryStaff, AppRole.systemManager};

/// Admin/CEO- and Developer-only account directory: view every account and
/// change anyone else's role. firestore.rules is the real gate (see
/// `isAdminOrDeveloper()`) — this screen assumes it's only ever reached by
/// someone that already passes, since the Admin/Developer shells are the
/// only places it's linked from.
///
/// Real sign-ups and the seeded demonstration accounts
/// ([UserProfile.isDemo]) are split into separate tabs, each filterable by
/// role.
class RoleManagementScreen extends ConsumerWidget {
  const RoleManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profilesAsync = ref.watch(allUserProfilesProvider);
    final query = ref.watch(_roleManagementSearchProvider);
    final profiles = profilesAsync.valueOrNull ?? const <UserProfile>[];
    final realCount = profiles.where((p) => !p.isDemo).length;
    final demoCount = profiles.length - realCount;

    return DefaultTabController(
      length: 2,
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Role management',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Every registered account. Assign or change anyone else\'s role — you can\'t change your own here.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TabBar(
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    tabs: [
                      Tab(
                        icon: const Icon(Icons.verified_user_outlined),
                        text: profilesAsync.hasValue
                            ? 'Real users ($realCount)'
                            : 'Real users',
                      ),
                      Tab(
                        icon: const Icon(Icons.science_outlined),
                        text: profilesAsync.hasValue
                            ? 'Demo accounts ($demoCount)'
                            : 'Demo accounts',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  LiveSearchField(
                    hintText: 'Search by name, email, phone or uid',
                    onChanged: (v) =>
                        ref.read(_roleManagementSearchProvider.notifier).state =
                            v,
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: profilesAsync.when(
                      loading: () => const Center(
                        child: CircularProgressIndicator(
                          semanticsLabel: 'Loading',
                        ),
                      ),
                      error: (error, stack) {
                        appLogger.e(
                          '[role-mgmt] Failed to load accounts',
                          error: error,
                          stackTrace: stack,
                        );
                        return EmptyState(
                          icon: Icons.lock_outline_rounded,
                          title: 'Couldn\'t load accounts',
                          message: friendlyError(error),
                          action: TextButton.icon(
                            onPressed: () =>
                                ref.invalidate(allUserProfilesProvider),
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Retry'),
                          ),
                        );
                      },
                      data: (profiles) {
                        final searched = filterBySearch(
                          profiles,
                          query,
                          (p) => [
                            p.displayName,
                            p.email,
                            p.phone,
                            p.uid,
                            p.role.label,
                          ],
                        );
                        return TabBarView(
                          children: [
                            _AccountDirectory(
                              key: const PageStorageKey('real'),
                              profiles: [
                                for (final p in searched)
                                  if (!p.isDemo) p,
                              ],
                              hasQuery: query.trim().isNotEmpty,
                              demo: false,
                            ),
                            _AccountDirectory(
                              key: const PageStorageKey('demo'),
                              profiles: [
                                for (final p in searched)
                                  if (p.isDemo) p,
                              ],
                              hasQuery: query.trim().isNotEmpty,
                              demo: true,
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One tab's worth of accounts, with the role filter chips on top.
class _AccountDirectory extends ConsumerStatefulWidget {
  const _AccountDirectory({
    super.key,
    required this.profiles,
    required this.hasQuery,
    required this.demo,
  });

  final List<UserProfile> profiles;
  final bool hasQuery;
  final bool demo;

  @override
  ConsumerState<_AccountDirectory> createState() => _AccountDirectoryState();
}

class _AccountDirectoryState extends ConsumerState<_AccountDirectory>
    with AutomaticKeepAliveClientMixin {
  _RoleFilter _filter = _RoleFilter.all;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final myUid = ref.watch(currentUidProvider);
    final filtered = widget.profiles.where(_filter.matches).toList();

    Widget body;
    if (filtered.isEmpty) {
      body = EmptyState(
        icon: widget.demo
            ? Icons.science_outlined
            : Icons.people_outline_rounded,
        title: widget.profiles.isEmpty && !widget.hasQuery
            ? (widget.demo ? 'No demo accounts' : 'No registered users yet')
            : 'No matches',
        message: widget.profiles.isEmpty && !widget.hasQuery
            ? (widget.demo
                  ? 'Seeded accounts (${UserProfile.demoEmailDomain}) appear here.'
                  : 'Accounts show up here as soon as someone signs up.')
            : 'Try a different search term or role filter.',
      );
    } else {
      body = LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < _twoColumnBreakpoint) {
            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: filtered.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final profile = filtered[index];
                return _AccountRow(
                  profile: profile,
                  isSelf: profile.uid == myUid,
                );
              },
            );
          }
          final columnWidth = (constraints.maxWidth - 12) / 2;
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Wrap(
              spacing: 12,
              runSpacing: 10,
              children: [
                for (final profile in filtered)
                  SizedBox(
                    width: columnWidth,
                    child: _AccountRow(
                      profile: profile,
                      isSelf: profile.uid == myUid,
                    ),
                  ),
              ],
            ),
          );
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.demo)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.tertiaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: theme.colorScheme.onTertiaryContainer,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Seeded accounts kept to demonstrate each role. '
                    'They never mix with real users.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onTertiaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final f in _RoleFilter.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(
                      '${f.label} (${widget.profiles.where(f.matches).length})',
                    ),
                    selected: _filter == f,
                    onSelected: (_) => setState(() => _filter = f),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(child: body),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _AccountRow extends ConsumerWidget {
  const _AccountRow({required this.profile, required this.isSelf});

  final UserProfile profile;
  final bool isSelf;

  bool get _isFounder => profile.uid == foundingDeveloperUid;

  /// Role/wage/suspension changes are off for your own account and the
  /// founding developer — firestore.rules rejects both anyway.
  bool get _canManage => !isSelf && !_isFounder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showDetails(context, ref),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                backgroundImage:
                    profile.photoUrl == null || profile.photoUrl!.isEmpty
                    ? null
                    : NetworkImage(profile.photoUrl!),
                child: profile.photoUrl == null || profile.photoUrl!.isEmpty
                    ? Icon(_iconFor(profile.role))
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            profile.nameOrEmail,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isSelf) ...[
                          const SizedBox(width: 8),
                          _Pill(
                            text: 'You',
                            color: theme.colorScheme.secondaryContainer,
                            onColor: theme.colorScheme.onSecondaryContainer,
                          ),
                        ],
                      ],
                    ),
                    Text(
                      profile.email,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      [
                        if (profile.phone.isNotEmpty) profile.phone,
                        if (profile.createdAt.millisecondsSinceEpoch > 0)
                          'Joined ${DateFormat.yMMMd().format(profile.createdAt)}',
                      ].join(' · '),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _Pill(
                    text: profile.role.label,
                    color: theme.colorScheme.primaryContainer,
                    onColor: theme.colorScheme.onPrimaryContainer,
                  ),
                  if (profile.disabled) ...[
                    const SizedBox(height: 4),
                    _Pill(
                      text: 'Suspended',
                      color: theme.colorScheme.errorContainer,
                      onColor: theme.colorScheme.onErrorContainer,
                    ),
                  ],
                ],
              ),
              const SizedBox(width: 4),
              if (_isFounder)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Tooltip(
                    message: 'Founding developer — role locked',
                    child: Icon(
                      Icons.lock_outline_rounded,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              PopupMenuButton<_AccountAction>(
                tooltip: 'Account actions',
                icon: const Icon(Icons.more_vert_rounded),
                onSelected: (action) => _onAction(context, ref, action),
                itemBuilder: (context) => _menuItems(theme),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<PopupMenuEntry<_AccountAction>> _menuItems(ThemeData theme) {
    PopupMenuItem<_AccountAction> item(
      _AccountAction value,
      IconData icon,
      String text, {
      Color? color,
    }) => PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              text,
              style: color == null ? null : TextStyle(color: color),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );

    final hasPhone = profile.phone.isNotEmpty;
    return [
      item(_AccountAction.details, Icons.badge_outlined, 'View details'),
      if (_canManage) ...[
        const PopupMenuDivider(),
        item(
          _AccountAction.changeRole,
          Icons.manage_accounts_outlined,
          'Change role...',
        ),
        if (profile.role != AppRole.user)
          item(
            _AccountAction.revoke,
            Icons.person_remove_outlined,
            'Revoke to User',
          ),
        if (_wageRoles.contains(profile.role))
          item(
            _AccountAction.setWage,
            Icons.payments_outlined,
            'Set daily wage...',
          ),
      ],
      const PopupMenuDivider(),
      if (hasPhone) ...[
        item(_AccountAction.whatsapp, Icons.chat_rounded, 'WhatsApp'),
        item(_AccountAction.call, Icons.call_outlined, 'Call'),
      ],
      if (profile.email.isNotEmpty) ...[
        item(_AccountAction.email, Icons.email_outlined, 'Send email'),
        item(_AccountAction.copyEmail, Icons.copy_rounded, 'Copy email'),
      ],
      item(_AccountAction.copyUid, Icons.fingerprint_rounded, 'Copy uid'),
      if (_canManage) ...[
        const PopupMenuDivider(),
        if (profile.disabled)
          item(
            _AccountAction.reactivate,
            Icons.lock_open_rounded,
            'Reactivate account',
          )
        else
          item(
            _AccountAction.suspend,
            Icons.block_rounded,
            'Suspend account',
            color: theme.colorScheme.error,
          ),
      ],
    ];
  }

  Future<void> _onAction(
    BuildContext context,
    WidgetRef ref,
    _AccountAction action,
  ) async {
    switch (action) {
      case _AccountAction.details:
        _showDetails(context, ref);
      case _AccountAction.changeRole:
        _showRolePicker(context, profile);
      case _AccountAction.revoke:
        await _confirmRevoke(context, ref, profile);
      case _AccountAction.setWage:
        await _editWage(context, ref);
      case _AccountAction.whatsapp:
        await openWhatsApp(
          context,
          phone: profile.phone,
          message:
              'Hello ${profile.nameOrEmail}, this is ${businessNameOf(context)}. ',
        );
      case _AccountAction.call:
        await _launch(context, Uri(scheme: 'tel', path: profile.phone));
      case _AccountAction.email:
        await _launch(context, Uri(scheme: 'mailto', path: profile.email));
      case _AccountAction.copyEmail:
        await _copy(context, profile.email, 'Email copied');
      case _AccountAction.copyUid:
        await _copy(context, profile.uid, 'uid copied');
      case _AccountAction.suspend:
        await _confirmSetDisabled(context, ref, profile, true);
      case _AccountAction.reactivate:
        await _confirmSetDisabled(context, ref, profile, false);
    }
  }

  IconData _iconFor(AppRole role) => switch (role) {
    AppRole.user => Icons.person_outline,
    AppRole.deliveryStaff => Icons.local_shipping_outlined,
    AppRole.systemManager => Icons.dashboard_outlined,
    AppRole.admin => Icons.insights_outlined,
    AppRole.developer => Icons.code_rounded,
  };

  static void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _launch(BuildContext context, Uri uri) async {
    final ok = await launchUrl(uri);
    if (!ok && context.mounted) {
      _snack(context, 'Couldn\'t open that on this device.');
    }
  }

  Future<void> _copy(BuildContext context, String text, String done) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) _snack(context, done);
  }

  void _showDetails(BuildContext context, WidgetRef ref) {
    final date = DateFormat.yMMMd().add_jm();
    String when(DateTime d) =>
        d.millisecondsSinceEpoch == 0 ? '—' : date.format(d);
    final wage = profile.dailyWage;
    final rows = <(String, String)>[
      ('Email', profile.email),
      ('Phone', profile.phone.isEmpty ? '—' : profile.phone),
      ('Role', profile.role.label),
      ('Status', profile.disabled ? 'Suspended' : 'Active'),
      ('Account type', profile.isDemo ? 'Demo (seeded)' : 'Real sign-up'),
      if (_wageRoles.contains(profile.role))
        (
          'Daily wage',
          wage == null || wage <= 0
              ? 'Not set'
              : '${currencyFormat.format(wage)}/day',
        ),
      if (profile.role == AppRole.deliveryStaff) ...[
        ('Vehicle', profile.vehiclePlate.isEmpty ? '—' : profile.vehiclePlate),
        ('Available', profile.availability ? 'Yes' : 'No'),
      ],
      ('Joined', when(profile.createdAt)),
      ('Last updated', when(profile.updatedAt)),
      ('uid', profile.uid),
    ];

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        child: Icon(_iconFor(profile.role)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          profile.nameOrEmail,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  for (final (label, value) in rows)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 120,
                            child: Text(
                              label,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          Expanded(
                            child: SelectableText(
                              value,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (_canManage)
                        FilledButton.tonalIcon(
                          onPressed: () {
                            Navigator.of(sheetContext).pop();
                            _showRolePicker(context, profile);
                          },
                          icon: const Icon(Icons.manage_accounts_outlined),
                          label: const Text('Change role'),
                        ),
                      if (_canManage && _wageRoles.contains(profile.role))
                        OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(sheetContext).pop();
                            _editWage(context, ref);
                          },
                          icon: const Icon(Icons.payments_outlined),
                          label: const Text('Daily wage'),
                        ),
                      if (profile.phone.isNotEmpty)
                        OutlinedButton.icon(
                          onPressed: () =>
                              _onAction(context, ref, _AccountAction.whatsapp),
                          icon: const Icon(Icons.chat_rounded),
                          label: const Text('WhatsApp'),
                        ),
                      if (profile.phone.isNotEmpty)
                        OutlinedButton.icon(
                          onPressed: () =>
                              _onAction(context, ref, _AccountAction.call),
                          icon: const Icon(Icons.call_outlined),
                          label: const Text('Call'),
                        ),
                      if (profile.email.isNotEmpty)
                        OutlinedButton.icon(
                          onPressed: () =>
                              _onAction(context, ref, _AccountAction.email),
                          icon: const Icon(Icons.email_outlined),
                          label: const Text('Email'),
                        ),
                      if (_canManage)
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: profile.disabled
                                ? null
                                : theme.colorScheme.error,
                          ),
                          onPressed: () {
                            Navigator.of(sheetContext).pop();
                            _confirmSetDisabled(
                              context,
                              ref,
                              profile,
                              !profile.disabled,
                            );
                          },
                          icon: Icon(
                            profile.disabled
                                ? Icons.lock_open_rounded
                                : Icons.block_rounded,
                          ),
                          label: Text(
                            profile.disabled ? 'Reactivate' : 'Suspend',
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _editWage(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(
      text: profile.dailyWage?.toString() ?? '',
    );
    final formKey = GlobalKey<FormState>();
    String? validate(String? v) {
      final n = num.tryParse((v ?? '').trim());
      if (n == null) return 'Enter a number';
      if (n < 0) return 'Can\'t be negative';
      return null;
    }

    void submit(BuildContext dialogContext) {
      if (formKey.currentState?.validate() ?? false) {
        Navigator.of(dialogContext).pop(num.tryParse(controller.text.trim()));
      }
    }

    final result = await showDialog<num>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Daily wage — ${profile.nameOrEmail}'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Amount (KES per day)',
            ),
            autofocus: true,
            validator: validate,
            onFieldSubmitted: (_) => submit(dialogContext),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => submit(dialogContext),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null) return;
    try {
      appLogger.i('[role-mgmt] Setting ${profile.uid} dailyWage=$result');
      await ref
          .read(userProfileRepositoryProvider)
          .updateDailyWage(uid: profile.uid, dailyWage: result);
    } catch (error, stack) {
      appLogger.e(
        '[role-mgmt] Failed to set dailyWage for ${profile.uid}',
        error: error,
        stackTrace: stack,
      );
      if (context.mounted) {
        _snack(context, 'Couldn\'t save wage: ${friendlyError(error)}');
      }
    }
  }

  Future<void> _confirmRevoke(
    BuildContext context,
    WidgetRef ref,
    UserProfile profile,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revoke role?'),
        content: Text(
          '${profile.nameOrEmail} will be demoted from ${profile.role.label} back to a plain User, '
          'losing all staff/manager/admin access immediately.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final myUid = ref.read(currentUidProvider);
    try {
      appLogger.i('[role-mgmt] Revoking ${profile.uid} -> user');
      await ref
          .read(userProfileRepositoryProvider)
          .updateRole(
            uid: profile.uid,
            role: AppRole.user,
            changedByUid: myUid ?? 'unknown',
          );
    } catch (error, stack) {
      appLogger.e(
        '[role-mgmt] Failed to revoke role for ${profile.uid}',
        error: error,
        stackTrace: stack,
      );
      if (context.mounted) {
        _snack(context, 'Couldn\'t revoke role: ${friendlyError(error)}');
      }
    }
  }

  Future<void> _confirmSetDisabled(
    BuildContext context,
    WidgetRef ref,
    UserProfile profile,
    bool disable,
  ) async {
    final name = profile.nameOrEmail;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(disable ? 'Suspend account?' : 'Reactivate account?'),
        content: Text(
          disable
              ? '$name will be signed out immediately and blocked from signing back in '
                    'or using any staff/manager/admin permission, until reactivated.'
              : '$name will be able to sign in and use their ${profile.role.label} '
                    'permissions again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(disable ? 'Suspend' : 'Reactivate'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      appLogger.i('[role-mgmt] Setting ${profile.uid} disabled=$disable');
      await ref
          .read(userProfileRepositoryProvider)
          .setDisabled(uid: profile.uid, disabled: disable);
    } catch (error, stack) {
      appLogger.e(
        '[role-mgmt] Failed to set disabled=$disable for ${profile.uid}',
        error: error,
        stackTrace: stack,
      );
      if (context.mounted) {
        _snack(
          context,
          'Couldn\'t ${disable ? "suspend" : "reactivate"} account: ${friendlyError(error)}',
        );
      }
    }
  }

  void _showRolePicker(BuildContext context, UserProfile profile) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (context) {
        return Consumer(
          builder: (context, ref, _) {
            // The Developer role is never offered here, even to the founding
            // developer — it's the widest-access role in the system, so
            // granting it is deliberately kept out of this general-purpose
            // picker and only ever done directly against Firestore.
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Set role for ${profile.nameOrEmail}',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      for (final role in AppRole.values)
                        if (role != AppRole.developer)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              role == profile.role
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_unchecked,
                              color: role == profile.role
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                            ),
                            title: Text(role.label),
                            onTap: () async {
                              // Grab the messenger before the sheet closes —
                              // its context is gone by the time an error lands.
                              final messenger = ScaffoldMessenger.of(context);
                              Navigator.of(context).pop();
                              if (role == profile.role) return;
                              final myUid = ref.read(currentUidProvider);
                              try {
                                appLogger.i(
                                  '[role-mgmt] Setting ${profile.uid} -> ${role.name}',
                                );
                                await ref
                                    .read(userProfileRepositoryProvider)
                                    .updateRole(
                                      uid: profile.uid,
                                      role: role,
                                      changedByUid: myUid ?? 'unknown',
                                    );
                              } catch (error, stack) {
                                appLogger.e(
                                  '[role-mgmt] Failed to set role for ${profile.uid}',
                                  error: error,
                                  stackTrace: stack,
                                );
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Couldn\'t change role: ${friendlyError(error)}',
                                    ),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            },
                          ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.color, required this.onColor});

  final String text;
  final Color color;
  final Color onColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: onColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
