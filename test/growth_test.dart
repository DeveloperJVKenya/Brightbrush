import 'package:brightbrush/features/growth/growth_providers.dart';
import 'package:flutter_test/flutter_test.dart';

/// Same cases as functions/src/loyalty/loyalty.test.ts (redeemable).
void main() {
  const on = LoyaltySettings(
    enabled: true,
    pointValue: 1,
    maxRedeemPercent: 20,
  );

  test('points redemption is capped by balance and % of the order', () {
    expect(on.redeemable(300, 10000), (points: 300, value: 300));
    expect(on.redeemable(9999, 10000), (points: 2000, value: 2000));
    expect(const LoyaltySettings().redeemable(100, 10000), (
      points: 0,
      value: 0,
    ));
  });

  test('point value scales the discount', () {
    const s = LoyaltySettings(
      enabled: true,
      pointValue: 2,
      maxRedeemPercent: 50,
    );
    expect(s.redeemable(1000, 1000), (points: 250, value: 500));
  });
}
