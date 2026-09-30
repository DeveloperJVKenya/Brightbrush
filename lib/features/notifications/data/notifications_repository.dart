import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/logging/stream_error_logger.dart';

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.link,
    required this.read,
    required this.createdAt,
  });

  final String id;
  final String type;
  final String title;
  final String body;
  final String? link;
  final bool read;
  final DateTime createdAt;

  factory AppNotification.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data() ?? {};
    return AppNotification(
      id: doc.id,
      type: d['type'] as String? ?? '',
      title: d['title'] as String? ?? '',
      body: d['body'] as String? ?? '',
      link: d['link'] as String?,
      read: d['read'] as bool? ?? false,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class NotificationPrefs {
  const NotificationPrefs({
    this.push = true,
    this.email = true,
    this.whatsapp = true,
    this.marketing = true,
  });

  final bool push;
  final bool email;
  final bool whatsapp;

  /// Cart reminders and promotions.
  final bool marketing;

  factory NotificationPrefs.fromMap(Map<String, dynamic>? d) =>
      NotificationPrefs(
        push: d?['push'] as bool? ?? true,
        email: d?['email'] as bool? ?? true,
        whatsapp: d?['whatsapp'] as bool? ?? true,
        marketing: d?['marketing'] as bool? ?? true,
      );

  Map<String, dynamic> toMap() => {
    'push': push,
    'email': email,
    'whatsapp': whatsapp,
    'marketing': marketing,
  };
}

class NotificationsRepository {
  NotificationsRepository(this._db, this._functions);

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  Stream<List<AppNotification>> streamInbox(String uid) => _db
      .collection('Notifications')
      .where('uid', isEqualTo: uid)
      .orderBy('createdAt', descending: true)
      .limit(100)
      .snapshots()
      .map((s) => s.docs.map(AppNotification.fromFirestore).toList())
      .transform(logStreamErrors('[notifications] inbox failed'));

  Future<void> markRead(String id) =>
      _db.collection('Notifications').doc(id).update({'read': true});

  Future<void> markAllRead(List<AppNotification> items) async {
    final batch = _db.batch();
    for (final n in items.where((n) => !n.read)) {
      batch.update(_db.collection('Notifications').doc(n.id), {'read': true});
    }
    await batch.commit();
  }

  Future<void> delete(String id) =>
      _db.collection('Notifications').doc(id).delete();

  DocumentReference<Map<String, dynamic>> _prefs(String uid) => _db
      .collection('Users')
      .doc(uid)
      .collection('Settings')
      .doc('notifications');

  Stream<NotificationPrefs> streamPrefs(String uid) => _prefs(uid)
      .snapshots()
      .map((s) => NotificationPrefs.fromMap(s.data()))
      .handleError((Object _) => const NotificationPrefs());

  Future<void> savePrefs(String uid, NotificationPrefs prefs) =>
      _prefs(uid).set(prefs.toMap());

  /// Asks for permission and registers this device for push. One VAPID key
  /// serves every browser and account of the project: the admin's optional
  /// key from Business settings if set, otherwise Firebase's built-in default
  /// key. Each device still gets its own token. Safe to call repeatedly;
  /// failures are logged, never thrown.
  Future<bool> registerDevice(String uid, {String? vapidKey}) async {
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        return false;
      }
      final token = await messaging.getToken(
        vapidKey: kIsWeb && (vapidKey ?? '').isNotEmpty ? vapidKey : null,
      );
      if (token == null) return false;
      await _db
          .collection('Users')
          .doc(uid)
          .collection('Devices')
          .doc(token)
          .set({
            'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
            'updatedAt': FieldValue.serverTimestamp(),
          });
      appLogger.i('[push] device registered for $uid');
      return true;
    } catch (error, stack) {
      appLogger.w(
        '[push] registration failed',
        error: error,
        stackTrace: stack,
      );
      return false;
    }
  }

  Future<Map<String, dynamic>> adminGetChannels() async =>
      Map<String, dynamic>.from(
        (await _functions.httpsCallable('adminGetNotificationChannels').call())
                .data
            as Map,
      );

  Future<void> adminSaveChannels(Map<String, dynamic> data) =>
      _functions.httpsCallable('adminSaveNotificationChannels').call(data);

  Future<void> adminTest() =>
      _functions.httpsCallable('adminTestNotification').call();
}
