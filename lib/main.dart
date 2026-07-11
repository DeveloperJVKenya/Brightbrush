import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

void main() {
  // ToDO(firebase): Firebase.initializeApp() goes here once
  // `flutterfire configure` has generated firebase_options.dart.
  runApp(const ProviderScope(child: BrightBrushApp()));
}
