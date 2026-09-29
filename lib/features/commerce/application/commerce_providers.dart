import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/errors/user_facing_error.dart';
import '../../../core/firebase/firebase_providers.dart';
import '../../../core/logging/app_logger.dart';
import '../data/commerce_repository.dart';

final commerceRepositoryProvider = Provider<CommerceRepository>((ref) {
  return CommerceRepository(
    ref.watch(firestoreProvider),
    ref.watch(firebaseFunctionsProvider),
  );
});

/// The signed-in customer's business terms (discount, credit).
final myAccountProvider = StreamProvider<CustomerAccount?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(null);
  return ref.watch(commerceRepositoryProvider).streamAccount(uid);
});

final allAccountsProvider = StreamProvider<Map<String, CustomerAccount>>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(commerceRepositoryProvider).streamAllAccounts();
});

final couponsProvider = StreamProvider<List<Coupon>>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(commerceRepositoryProvider).streamCoupons();
});

final etimsEnabledProvider = StreamProvider<bool>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(commerceRepositoryProvider).streamEtimsEnabled();
});

final orderRefundsProvider = StreamProvider.autoDispose
    .family<List<RefundRecord>, ({String orderId, bool asStaff})>((ref, args) {
      final uid = ref.watch(currentUidProvider);
      if (uid == null) return Stream.value(const []);
      return ref
          .watch(commerceRepositoryProvider)
          .streamRefunds(args.orderId, customerId: args.asStaff ? null : uid);
    });

/// Saves/shares a file: a download on desktop web, the share sheet on
/// phones (save to Files, WhatsApp, email...).
Future<void> saveOrShareFile(
  BuildContext context, {
  required Uint8List bytes,
  required String fileName,
  required String mimeType,
}) async {
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile.fromData(bytes, mimeType: mimeType, name: fileName)],
      fileNameOverrides: [fileName],
      downloadFallbackEnabled: true,
    ),
  );
}

Future<void> saveCsv(BuildContext context, String fileName, String csv) =>
    saveOrShareFile(
      context,
      bytes: Uint8List.fromList(utf8.encode(csv)),
      fileName: fileName,
      mimeType: 'text/csv',
    );

/// Generates a PDF on the server and hands it to the user.
Future<void> openDocument(
  BuildContext context,
  WidgetRef ref,
  DocumentKind kind,
  String? id,
) async {
  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(
    const SnackBar(
      content: Text('Preparing your document…'),
      behavior: SnackBarBehavior.floating,
      duration: Duration(seconds: 2),
    ),
  );
  try {
    final doc = await ref
        .read(commerceRepositoryProvider)
        .getDocument(kind, id);
    if (!context.mounted) return;
    await saveOrShareFile(
      context,
      bytes: doc.bytes,
      fileName: doc.fileName,
      mimeType: 'application/pdf',
    );
  } catch (error, stack) {
    appLogger.e(
      '[documents] ${kind.name} failed',
      error: error,
      stackTrace: stack,
    );
    messenger.showSnackBar(
      SnackBar(
        content: Text('Couldn\'t create the document: ${friendlyError(error)}'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
