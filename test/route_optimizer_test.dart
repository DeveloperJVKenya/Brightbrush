import 'dart:math';

import 'package:brightbrush/features/staff/domain/route_optimizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('visits points along a line in order from the start', () {
    final stops = [
      const RouteStop('c', -1.30, 36.90),
      const RouteStop('a', -1.30, 36.70),
      const RouteStop('d', -1.30, 37.00),
      const RouteStop('b', -1.30, 36.80),
    ];
    final route = optimizeRoute(stops, startLat: -1.30, startLng: 36.60);
    expect(route.map((s) => s.value), ['a', 'b', 'c', 'd']);
  });

  test('is never longer than the input order on random Nairobi stops', () {
    final rnd = Random(42);
    for (var trial = 0; trial < 20; trial++) {
      final stops = [
        for (var i = 0; i < 12; i++)
          RouteStop(
            i,
            -1.2 - rnd.nextDouble() * 0.2,
            36.7 + rnd.nextDouble() * 0.3,
          ),
      ];
      final optimized = optimizeRoute(stops, startLat: -1.28, startLng: 36.82);
      expect(optimized.length, stops.length);
      expect(
        optimized.map((s) => s.value).toSet(),
        stops.map((s) => s.value).toSet(),
      );
      expect(
        routeLengthKm(optimized, startLat: -1.28, startLng: 36.82),
        lessThanOrEqualTo(
          routeLengthKm(stops, startLat: -1.28, startLng: 36.82) + 1e-9,
        ),
      );
    }
  });

  test('builds a Google Maps directions link with waypoints', () {
    final url = googleMapsRouteUrl(
      [const RouteStop(1, -1.3, 36.8), const RouteStop(2, -1.2, 36.9)],
      startLat: -1.28,
      startLng: 36.82,
    );
    expect(url.queryParameters['destination'], '-1.2,36.9');
    expect(url.queryParameters['waypoints'], '-1.3,36.8');
    expect(url.queryParameters['origin'], '-1.28,36.82');
  });

  test('haversine is about 111 km per degree of latitude', () {
    expect(haversineKm(0, 0, 1, 0), closeTo(111.2, 0.5));
  });
}
