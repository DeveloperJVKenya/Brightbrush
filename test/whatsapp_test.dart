import 'package:brightbrush/shared/whatsapp.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalises numbers for click-to-chat', () {
    expect(whatsappNumber('0712 345 678'), '254712345678');
    expect(whatsappNumber('+254 110 345678'), '254110345678');
    expect(whatsappNumber('712345678'), '254712345678');
    expect(whatsappNumber('+44 7700 900123'), '447700900123');
    expect(whatsappNumber('123'), isNull);
  });
}
