import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import '../firebase/firebase_providers.dart';
import '../logging/app_logger.dart';

/// Crash + error reporting, analytics and user tagging, set up once at
/// start-up. Crashlytics covers Android/iOS; the web (no Crashlytics) sends
/// uncaught errors to the logClientError function instead (throttled).
class Monitoring {
  Monitoring._();

  static int _webReports = 0;

  static Future<void> init() async {
    if (!kIsWeb) {
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
        !kDebugMode,
      );
      FlutterError.onError =
          FirebaseCrashlytics.instance.recordFlutterFatalError;
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
    } else {
      final previous = FlutterError.onError;
      FlutterError.onError = (details) {
        previous?.call(details);
        _reportWeb(details.exceptionAsString(), details.stack);
      };
      PlatformDispatcher.instance.onError = (error, stack) {
        _reportWeb(error.toString(), stack);
        return true;
      };
    }
    FirebaseAuth.instance.authStateChanges().listen((user) {
      final id = user?.uid;
      unawaited(
        FirebaseAnalytics.instance.setUserId(id: id).catchError((_) {}),
      );
      if (!kIsWeb) {
        unawaited(FirebaseCrashlytics.instance.setUserIdentifier(id ?? ''));
      }
    });
  }

  static void _reportWeb(String message, StackTrace? stack) {
    if (kDebugMode || _webReports >= 5) return;
    _webReports++;
    FirebaseFunctions.instanceFor(region: functionsRegion)
        .httpsCallable('logClientError')
        .call({
          'message': message,
          'stack': stack?.toString() ?? '',
          'route': Uri.base.fragment,
          'platform': 'web',
        })
        .catchError((Object e) {
          appLogger.w('[monitoring] error report failed', error: e);
          return null as dynamic;
        });
  }

  static FirebaseAnalytics get _a => FirebaseAnalytics.instance;

  static void _safe(Future<void> Function() f) =>
      unawaited(f().catchError((_) {}));

  // ---- Sales funnel events (GA4 e-commerce names).
  static void viewItem({
    required String id,
    required String name,
    required num price,
  }) => _safe(
    () => _a.logViewItem(
      currency: 'KES',
      value: price.toDouble(),
      items: [
        AnalyticsEventItem(itemId: id, itemName: name, price: price.toDouble()),
      ],
    ),
  );

  static void addToCart({
    required String id,
    required String name,
    required int quantity,
    required num value,
  }) => _safe(
    () => _a.logAddToCart(
      currency: 'KES',
      value: value.toDouble(),
      items: [
        AnalyticsEventItem(itemId: id, itemName: name, quantity: quantity),
      ],
    ),
  );

  static void beginCheckout(num value) => _safe(
    () => _a.logBeginCheckout(currency: 'KES', value: value.toDouble()),
  );

  static void purchase({required String orderId, required num value}) => _safe(
    () => _a.logPurchase(
      currency: 'KES',
      value: value.toDouble(),
      transactionId: orderId,
    ),
  );

  static void paymentStarted(String gateway, num amount) => _safe(
    () => _a.logAddPaymentInfo(
      currency: 'KES',
      value: amount.toDouble(),
      paymentType: gateway,
    ),
  );

  static void signUp() => _safe(() => _a.logSignUp(signUpMethod: 'email'));

  static void login() => _safe(() => _a.logLogin(loginMethod: 'email'));
}
