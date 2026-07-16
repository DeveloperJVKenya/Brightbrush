import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/logging/stream_error_logger.dart';
import '../domain/announcement_model.dart';

class AnnouncementsRepository {
  AnnouncementsRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _announcements => _db.collection('Announcements');

  /// All announcements, newest first — Admin/CEO authoring view.
  Stream<List<AnnouncementModel>> streamAll() {
    appLogger.d('[marketing] streamAll()');
    return _announcements
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(AnnouncementModel.fromFirestore).toList())
        .transform(logStreamErrors('[marketing] streamAll() failed — likely signed in as a role without isAdminOrDeveloper()'));
  }

  /// Active-only announcements, newest first — surfaced on every signed-in
  /// user's Home/Notifications feed.
  Stream<List<AnnouncementModel>> streamActive() {
    appLogger.d('[marketing] streamActive()');
    return _announcements
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(AnnouncementModel.fromFirestore).toList())
        .transform(logStreamErrors('[marketing] streamActive() failed'));
  }

  Future<String> create(AnnouncementModel announcement, {required String uid}) async {
    appLogger.i('[marketing] create() title="${announcement.title}" createdBy=$uid');
    try {
      final doc = await _announcements.add(announcement.toFirestoreCreate(uid: uid));
      appLogger.i('[marketing] created ${doc.id}');
      return doc.id;
    } catch (error, stack) {
      appLogger.e('[marketing] create() failed for title="${announcement.title}"', error: error, stackTrace: stack);
      rethrow;
    }
  }

  Future<void> update(AnnouncementModel announcement) async {
    appLogger.i('[marketing] update(${announcement.id})');
    try {
      await _announcements.doc(announcement.id).update(announcement.toFirestoreUpdate());
    } catch (error, stack) {
      appLogger.e('[marketing] update(${announcement.id}) failed', error: error, stackTrace: stack);
      rethrow;
    }
  }

  Future<void> delete(String id) async {
    appLogger.i('[marketing] delete($id)');
    try {
      await _announcements.doc(id).delete();
    } catch (error, stack) {
      appLogger.e('[marketing] delete($id) failed', error: error, stackTrace: stack);
      rethrow;
    }
  }
}
