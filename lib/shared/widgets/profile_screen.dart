import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/auth/app_role.dart';
import '../../core/auth/auth_providers.dart';
import '../../core/firebase/firebase_providers.dart';
import '../../core/formatting/currency.dart';
import '../../core/errors/user_facing_error.dart';
import '../../core/logging/app_logger.dart';
import '../../features/auth/presentation/widgets/account_safety_section.dart';
import '../../features/commerce/presentation/customer_account_tile.dart';
import '../../features/growth/rewards_card.dart';
import '../../features/catalog/application/catalog_providers.dart';
import 'empty_state.dart';
import '../../core/l10n/l10n_ext.dart';

/// Account screen shared by every role that has a `/profile` route (Manager,
/// Delivery Staff, Customer). Admin/CEO and Developer don't get one — they
/// use Role Management / the "view as" picker instead.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _vehicleController = TextEditingController();
  bool _saving = false;
  bool _seeded = false;
  bool _available = true;

  Uint8List? _pickedPhotoBytes;
  bool _uploadingPhoto = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _vehicleController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(String uid) async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _pickedPhotoBytes = bytes;
      _uploadingPhoto = true;
    });
    try {
      final url = await ref
          .read(catalogImageUploaderProvider)
          .uploadProfilePhoto(
            uid: uid,
            bytes: bytes,
            contentType: 'image/jpeg',
          );
      await ref
          .read(userProfileRepositoryProvider)
          .updateSelfProfile(uid: uid, photoUrl: url);
      appLogger.i('[profile] Photo updated for uid=$uid');
    } catch (error, stack) {
      appLogger.e(
        '[profile] Photo upload failed for uid=$uid',
        error: error,
        stackTrace: stack,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.couldntUploadPhoto(friendlyError(error)),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _save(String uid, AppRole role) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(userProfileRepositoryProvider)
          .updateDisplayName(
            uid: uid,
            displayName: _nameController.text.trim(),
          );
      await ref
          .read(userProfileRepositoryProvider)
          .updateSelfProfile(
            uid: uid,
            phone: _phoneController.text.trim(),
            vehiclePlate: role == AppRole.deliveryStaff
                ? _vehicleController.text.trim()
                : null,
            availability: role == AppRole.deliveryStaff ? _available : null,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.profileUpdated),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (error, stack) {
      appLogger.e('[profile] Save failed', error: error, stackTrace: stack);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.couldntSave(friendlyError(error))),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _changePassword() async {
    await showDialog<void>(
      context: context,
      builder: (context) => const _ChangePasswordDialog(),
    );
  }

  Future<void> _signOut() async {
    appLogger.i('[auth] Signing out from Profile screen');
    await ref.read(firebaseAuthProvider).signOut();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profileAsync = ref.watch(myProfileProvider);
    final roleAsync = ref.watch(resolvedRoleProvider);

    return SafeArea(
      child: profileAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(
            semanticsLabel: context.l10n.loading,
          ),
        ),
        error: (error, stack) {
          appLogger.e(
            '[profile] Failed to load profile',
            error: error,
            stackTrace: stack,
          );
          return EmptyState(
            icon: Icons.cloud_off_rounded,
            title: context.l10n.couldntLoadYourProfile,
            message: friendlyError(error),
            action: TextButton.icon(
              onPressed: () => ref.invalidate(myProfileProvider),
              icon: const Icon(Icons.refresh_rounded),
              label: Text(context.l10n.retry),
            ),
          );
        },
        data: (profile) {
          if (profile == null) {
            return EmptyState(
              icon: Icons.person_off_outlined,
              title: context.l10n.noProfileFound,
              message: context.l10n.signInAgainToLoadYour,
            );
          }
          if (!_seeded) {
            _nameController.text = profile.displayName;
            _phoneController.text = profile.phone;
            _vehicleController.text = profile.vehiclePlate;
            _available = profile.availability;
            _seeded = true;
          }
          final role = roleAsync.valueOrNull ?? profile.role;
          final roleLabel = role.label;

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.navProfile,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.l10n.yourAccountDetails,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant,
                      ),
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              GestureDetector(
                                onTap: _uploadingPhoto
                                    ? null
                                    : () => _pickPhoto(profile.uid),
                                child: Stack(
                                  children: [
                                    CircleAvatar(
                                      radius: 28,
                                      backgroundColor:
                                          theme.colorScheme.primaryContainer,
                                      backgroundImage: _pickedPhotoBytes != null
                                          ? MemoryImage(_pickedPhotoBytes!)
                                          : (profile.photoUrl != null
                                                ? CachedNetworkImageProvider(
                                                    profile.photoUrl!,
                                                  )
                                                : null),
                                      child:
                                          (_pickedPhotoBytes == null &&
                                              profile.photoUrl == null)
                                          ? Text(
                                              profile.displayName.isNotEmpty
                                                  ? profile.displayName[0]
                                                        .toUpperCase()
                                                  : '?',
                                              style: theme.textTheme.titleLarge
                                                  ?.copyWith(
                                                    color: theme
                                                        .colorScheme
                                                        .onPrimaryContainer,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                            )
                                          : null,
                                    ),
                                    if (_uploadingPhoto)
                                      const Positioned.fill(
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    else
                                      Positioned(
                                        bottom: -2,
                                        right: -2,
                                        child: Container(
                                          padding: const EdgeInsets.all(3),
                                          decoration: BoxDecoration(
                                            color: theme.colorScheme.primary,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: theme
                                                  .colorScheme
                                                  .surfaceContainerLow,
                                              width: 2,
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.camera_alt_rounded,
                                            size: 12,
                                            color: theme.colorScheme.onPrimary,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      profile.email,
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: theme
                                            .colorScheme
                                            .secondaryContainer,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        roleLabel,
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                              color: theme
                                                  .colorScheme
                                                  .onSecondaryContainer,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _nameController,
                            decoration: InputDecoration(
                              labelText: context.l10n.displayName,
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? context.l10n.required
                                : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _phoneController,
                            decoration: InputDecoration(
                              labelText: context.l10n.phoneOptional,
                            ),
                            keyboardType: TextInputType.phone,
                          ),
                          if (role == AppRole.deliveryStaff) ...[
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _vehicleController,
                              decoration: InputDecoration(
                                labelText: context.l10n.vehiclePlateOptional,
                              ),
                            ),
                            const SizedBox(height: 4),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(context.l10n.availableForDeliveries),
                              value: _available,
                              onChanged: (v) => setState(() => _available = v),
                            ),
                          ],
                          if (profile.dailyWage != null &&
                              profile.dailyWage! > 0) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  Icons.payments_outlined,
                                  size: 16,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  context.l10n.dailyWageDaySetByAdmin(
                                    currencyFormat.format(profile.dailyWage),
                                  ),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 8),
                          Text(
                            context.l10n.memberSince(
                              DateFormat('MMM d, y').format(profile.createdAt),
                            ),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: _saving
                                  ? null
                                  : () => _save(profile.uid, role),
                              child: _saving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(context.l10n.saveChanges),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    context.l10n.security,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Card(
                    margin: EdgeInsets.zero,
                    child: ListTile(
                      leading: const Icon(Icons.lock_outline_rounded),
                      title: Text(context.l10n.changePassword),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _changePassword,
                    ),
                  ),
                  if (role == AppRole.user) ...[
                    const SizedBox(height: 10),
                    Card(
                      margin: EdgeInsets.zero,
                      child: ListTile(
                        leading: const Icon(Icons.palette_outlined),
                        title: Text(context.l10n.myArtwork),
                        subtitle: Text(
                          context.l10n.yourSavedLogosForBrandingOrders,
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push('/customer/artwork'),
                      ),
                    ),
                  ],
                  if (role == AppRole.user) const CustomerAccountTile(),
                  if (role == AppRole.user) const RewardsCard(),
                  if (role == AppRole.user)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Card(
                        margin: EdgeInsets.zero,
                        child: ListTile(
                          leading: const Icon(Icons.favorite_border_rounded),
                          title: Text(context.l10n.wishlist),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context.push('/customer/wishlist'),
                        ),
                      ),
                    ),
                  AccountSafetySection(role: role),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _signOut,
                      icon: const Icon(Icons.logout_rounded),
                      label: Text(context.l10n.signOut),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ChangePasswordDialog extends ConsumerStatefulWidget {
  const _ChangePasswordDialog();

  @override
  ConsumerState<_ChangePasswordDialog> createState() =>
      _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends ConsumerState<_ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final user = ref.read(firebaseAuthProvider).currentUser;
      if (user == null || user.email == null) throw StateError('Not signed in');
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: _currentController.text,
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(_newController.text);
      appLogger.i('[auth] Password changed for uid=${user.uid}');
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.passwordChanged),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on FirebaseAuthException catch (error, stack) {
      appLogger.e(
        '[auth] Password change failed',
        error: error,
        stackTrace: stack,
      );
      setState(
        () => _error = error.message ?? context.l10n.couldntChangePassword,
      );
    } catch (error, stack) {
      appLogger.e(
        '[auth] Password change failed',
        error: error,
        stackTrace: stack,
      );
      setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.l10n.changePassword),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _currentController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: context.l10n.currentPassword,
              ),
              validator: (v) =>
                  (v == null || v.isEmpty) ? context.l10n.required : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _newController,
              obscureText: true,
              decoration: InputDecoration(labelText: context.l10n.newPassword),
              validator: (v) => (v == null || v.length < 6)
                  ? context.l10n.atLeast6Characters
                  : null,
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(context.l10n.save),
        ),
      ],
    );
  }
}
