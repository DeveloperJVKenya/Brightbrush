import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../connectivity/queued_write.dart';
import '../firebase/firebase_providers.dart';
import '../logging/app_logger.dart';

/// Tells the server which language the signed-in user sees (the one on
/// screen, so "Auto" resolves to the device language), so notifications,
/// emails and WhatsApp messages arrive in that language. Stored in
/// Users/{uid}/Settings/preferences.language; written only when the user or
/// the language changes.
class LanguageSync extends ConsumerStatefulWidget {
  const LanguageSync({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<LanguageSync> createState() => _LanguageSyncState();
}

class _LanguageSyncState extends ConsumerState<LanguageSync> {
  String? _synced;

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(currentUidProvider);
    final lang = Localizations.localeOf(context).languageCode;
    final key = uid == null ? null : '$uid:$lang';
    if (key != null && key != _synced) {
      _synced = key;
      final doc = ref
          .read(firestoreProvider)
          .collection('Users')
          .doc(uid)
          .collection('Settings')
          .doc('preferences');
      unawaited(
        queuedWrite(
          doc.set({
            'language': lang,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true)),
        ).catchError((Object e) {
          appLogger.w('[l10n] could not save language preference', error: e);
          _synced = null;
          return null;
        }),
      );
    }
    return widget.child;
  }
}
