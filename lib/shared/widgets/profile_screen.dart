import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/auth/app_role.dart';
import '../../core/auth/auth_providers.dart';
import '../../core/firebase/firebase_providers.dart';
import '../../core/formatting/currency.dart';
import '../../core/errors/user_facing_error.dart';
import '../../core/logging/app_logger.dart';
import '../../features/catalog/application/catalog_providers.dart';
import 'empty_state.dart';

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
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _pickedPhotoBytes = bytes;
      _uploadingPhoto = true;
    });
    try {
      final url = await ref.read(catalogImageUploaderProvider).uploadProfilePhoto(
            uid: uid,
            bytes: bytes,
            contentType: 'image/jpeg',
          );
      await ref.read(userProfileRepositoryProvider).updateSelfProfile(uid: uid, photoUrl: url);
      appLogger.i('[profile] Photo updated for uid=$uid');
    } catch (error, stack) {
      appLogger.e('[profile] Photo upload failed for uid=$uid', error: error, stackTrace: stack);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Couldn\'t upload photo: ${friendlyError(error)}'), behavior: SnackBarBehavior.floating),
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
      await ref.read(userProfileRepositoryProvider).updateDisplayName(
            uid: uid,
            displayName: _nameController.text.trim(),
          );
      await ref.read(userProfileRepositoryProvider).updateSelfProfile(
            uid: uid,
            phone: _phoneController.text.trim(),
            vehiclePlate: role == AppRole.deliveryStaff ? _vehicleController.text.trim() : null,
            availability: role == AppRole.deliveryStaff ? _available : null,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated'), behavior: SnackBarBehavior.floating),
        );
      }
    } catch (error, stack) {
      appLogger.e('[profile] Save failed', error: error, stackTrace: stack);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Couldn\'t save: ${friendlyError(error)}'), behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _changePassword() async {
    await showDialog<void>(context: context, builder: (context) => const _ChangePasswordDialog());
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
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) {
          appLogger.e('[profile] Failed to load profile', error: error, stackTrace: stack);
          return EmptyState(
              icon: Icons.cloud_off_rounded, title: 'Couldn\'t load your profile', message: friendlyError(error));
        },
        data: (profile) {
          if (profile == null) {
            return const EmptyState(
              icon: Icons.person_off_outlined,
              title: 'No profile found',
              message: 'Sign in again to load your account details.',
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
                  Text('Profile', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    'Your account details.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: theme.colorScheme.outlineVariant),
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              GestureDetector(
                                onTap: _uploadingPhoto ? null : () => _pickPhoto(profile.uid),
                                child: Stack(
                                  children: [
                                    CircleAvatar(
                                      radius: 28,
                                      backgroundColor: theme.colorScheme.primaryContainer,
                                      backgroundImage: _pickedPhotoBytes != null
                                          ? MemoryImage(_pickedPhotoBytes!)
                                          : (profile.photoUrl != null ? NetworkImage(profile.photoUrl!) : null),
                                      child: (_pickedPhotoBytes == null && profile.photoUrl == null)
                                          ? Text(
                                              profile.displayName.isNotEmpty ? profile.displayName[0].toUpperCase() : '?',
                                              style: theme.textTheme.titleLarge?.copyWith(
                                                  color: theme.colorScheme.onPrimaryContainer, fontWeight: FontWeight.w700),
                                            )
                                          : null,
                                    ),
                                    if (_uploadingPhoto)
                                      const Positioned.fill(
                                        child: CircularProgressIndicator(strokeWidth: 2),
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
                                            border: Border.all(color: theme.colorScheme.surfaceContainerLow, width: 2),
                                          ),
                                          child: Icon(Icons.camera_alt_rounded, size: 12, color: theme.colorScheme.onPrimary),
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
                                    Text(profile.email, style: theme.textTheme.bodyMedium),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.secondaryContainer,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        roleLabel,
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(color: theme.colorScheme.onSecondaryContainer, fontWeight: FontWeight.w600),
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
                            decoration: const InputDecoration(labelText: 'Display name'),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _phoneController,
                            decoration: const InputDecoration(labelText: 'Phone (optional)'),
                            keyboardType: TextInputType.phone,
                          ),
                          if (role == AppRole.deliveryStaff) ...[
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _vehicleController,
                              decoration: const InputDecoration(labelText: 'Vehicle plate (optional)'),
                            ),
                            const SizedBox(height: 4),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Available for deliveries'),
                              value: _available,
                              onChanged: (v) => setState(() => _available = v),
                            ),
                          ],
                          if (profile.dailyWage != null && profile.dailyWage! > 0) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.payments_outlined, size: 16, color: theme.colorScheme.onSurfaceVariant),
                                const SizedBox(width: 8),
                                Text(
                                  'Daily wage: ${currencyFormat.format(profile.dailyWage)}/day (set by Admin)',
                                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 8),
                          Text(
                            'Member since ${DateFormat('MMM d, y').format(profile.createdAt)}',
                            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: _saving ? null : () => _save(profile.uid, role),
                              child: _saving
                                  ? const SizedBox(
                                      width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Text('Save changes'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('Security', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  Card(
                    margin: EdgeInsets.zero,
                    child: ListTile(
                      leading: const Icon(Icons.lock_outline_rounded),
                      title: const Text('Change password'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _changePassword,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _signOut,
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('Sign out'),
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
  ConsumerState<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
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
      final credential = EmailAuthProvider.credential(email: user.email!, password: _currentController.text);
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(_newController.text);
      appLogger.i('[auth] Password changed for uid=${user.uid}');
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password changed'), behavior: SnackBarBehavior.floating),
        );
      }
    } on FirebaseAuthException catch (error, stack) {
      appLogger.e('[auth] Password change failed', error: error, stackTrace: stack);
      setState(() => _error = error.message ?? 'Couldn\'t change password');
    } catch (error, stack) {
      appLogger.e('[auth] Password change failed', error: error, stackTrace: stack);
      setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Change password'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _currentController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Current password'),
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _newController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'New password'),
              validator: (v) => (v == null || v.length < 6) ? 'At least 6 characters' : null,
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save'),
        ),
      ],
    );
  }
}
