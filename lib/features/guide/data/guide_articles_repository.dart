import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/logging/stream_error_logger.dart';
import '../domain/guide_article.dart';

class GuideArticlesRepository {
  GuideArticlesRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _articles => _db.collection('GuideArticles');

  /// Every article, newest first — the Guide Editor authoring view.
  Stream<List<GuideArticle>> streamAll() {
    appLogger.d('[guide] streamAll()');
    return _articles
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(GuideArticle.fromFirestore).toList())
        .transform(logStreamErrors('[guide] streamAll() failed — likely signed in as a role without isAdminOrDeveloper()'));
  }

  /// Articles targeting a given role — the Guide screen everyone reads.
  Stream<List<GuideArticle>> streamForRole(String roleName) {
    appLogger.d('[guide] streamForRole($roleName)');
    return _articles
        .where('roles', arrayContains: roleName)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(GuideArticle.fromFirestore).toList())
        .transform(logStreamErrors('[guide] streamForRole($roleName) failed'));
  }

  Future<String> create(GuideArticle article, {required String uid}) async {
    appLogger.i('[guide] create() question="${article.question}" createdBy=$uid');
    try {
      final doc = await _articles.add(article.toFirestoreCreate(uid: uid));
      appLogger.i('[guide] created ${doc.id}');
      return doc.id;
    } catch (error, stack) {
      appLogger.e('[guide] create() failed for question="${article.question}"', error: error, stackTrace: stack);
      rethrow;
    }
  }

  Future<void> update(GuideArticle article) async {
    appLogger.i('[guide] update(${article.id})');
    try {
      await _articles.doc(article.id).update(article.toFirestoreUpdate());
    } catch (error, stack) {
      appLogger.e('[guide] update(${article.id}) failed', error: error, stackTrace: stack);
      rethrow;
    }
  }

  Future<void> delete(String id) async {
    appLogger.i('[guide] delete($id)');
    try {
      await _articles.doc(id).delete();
    } catch (error, stack) {
      appLogger.e('[guide] delete($id) failed', error: error, stackTrace: stack);
      rethrow;
    }
  }
}
