import 'package:intl/intl.dart';

/// BrightBrush Creations prices everything in Kenyan Shillings — a single
/// shared formatter so the symbol only ever needs to change in one place.
final NumberFormat currencyFormat = NumberFormat.currency(symbol: 'KES ', decimalDigits: 0);
