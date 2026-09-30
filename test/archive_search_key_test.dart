import 'package:brightbrush/features/orders/data/orders_repository.dart';
import 'package:flutter_test/flutter_test.dart';

// The key must be one the server indexes (searchKeywords() in
// functions/src/platform/platform.ts) or the archive search finds nothing.
void main() {
  test('order numbers: the most selective word', () {
    expect(archiveSearchKey('BB-000123'), '000123');
  });

  test('names: lowercase, longest word, capped at 15', () {
    expect(archiveSearchKey('Jane Wanjiru'), 'wanjiru');
    expect(archiveSearchKey('Supercalifragilistic'), 'supercalifragil');
  });

  test('phones in any format use the last 9 digits', () {
    expect(archiveSearchKey('0712 345 678'), '712345678');
    expect(archiveSearchKey('+254712345678'), '712345678');
  });

  test('too short to search', () {
    expect(archiveSearchKey(' a '), '');
    expect(archiveSearchKey(''), '');
  });
}
