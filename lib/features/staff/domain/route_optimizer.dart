import 'dart:math';

/// A stop to visit (latitude/longitude in degrees).
class RouteStop<T> {
  const RouteStop(this.value, this.lat, this.lng);

  final T value;
  final double lat;
  final double lng;
}

/// Great-circle distance in km.
double haversineKm(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371.0;
  double rad(double d) => d * pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLng = rad(lng2 - lng1);
  final a =
      sin(dLat / 2) * sin(dLat / 2) +
      cos(rad(lat1)) * cos(rad(lat2)) * sin(dLng / 2) * sin(dLng / 2);
  return 2 * r * asin(min(1, sqrt(a)));
}

/// Orders delivery stops to shorten the drive: nearest-neighbour from the
/// start point, then 2-opt improvement. Good results for a day's drops
/// (tens of stops) with no paid routing API. Straight-line distances — the
/// driver's navigation app handles the actual roads.
List<RouteStop<T>> optimizeRoute<T>(
  List<RouteStop<T>> stops, {
  double? startLat,
  double? startLng,
}) {
  if (stops.length < 2) return List.of(stops);
  final remaining = List.of(stops);
  final route = <RouteStop<T>>[];
  var curLat = startLat ?? remaining.first.lat;
  var curLng = startLng ?? remaining.first.lng;
  while (remaining.isNotEmpty) {
    var best = 0;
    var bestD = double.infinity;
    for (var i = 0; i < remaining.length; i++) {
      final d = haversineKm(curLat, curLng, remaining[i].lat, remaining[i].lng);
      if (d < bestD) {
        bestD = d;
        best = i;
      }
    }
    final next = remaining.removeAt(best);
    route.add(next);
    curLat = next.lat;
    curLng = next.lng;
  }

  double dist(int i, int j) =>
      haversineKm(route[i].lat, route[i].lng, route[j].lat, route[j].lng);
  double fromStart(int i) => startLat == null
      ? 0
      : haversineKm(startLat, startLng!, route[i].lat, route[i].lng);

  // 2-opt: reverse any segment that shortens the path.
  var improved = true;
  var guard = 0;
  while (improved && guard++ < 200) {
    improved = false;
    for (var i = 0; i < route.length - 1; i++) {
      for (var k = i + 1; k < route.length; k++) {
        final before =
            (i == 0 ? fromStart(i) : dist(i - 1, i)) +
            (k + 1 < route.length ? dist(k, k + 1) : 0);
        final after =
            (i == 0 ? fromStart(k) : dist(i - 1, k)) +
            (k + 1 < route.length ? dist(i, k + 1) : 0);
        if (after + 1e-9 < before) {
          final segment = route.sublist(i, k + 1).reversed.toList();
          route.replaceRange(i, k + 1, segment);
          improved = true;
        }
      }
    }
  }
  return route;
}

double routeLengthKm<T>(
  List<RouteStop<T>> route, {
  double? startLat,
  double? startLng,
}) {
  var total = 0.0;
  for (var i = 0; i < route.length; i++) {
    if (i == 0) {
      if (startLat != null) {
        total += haversineKm(startLat, startLng!, route[0].lat, route[0].lng);
      }
    } else {
      total += haversineKm(
        route[i - 1].lat,
        route[i - 1].lng,
        route[i].lat,
        route[i].lng,
      );
    }
  }
  return total;
}

/// Google Maps multi-stop directions link (opens in the Maps app on
/// phones). Up to 9 waypoints between origin and destination.
Uri googleMapsRouteUrl<T>(
  List<RouteStop<T>> route, {
  double? startLat,
  double? startLng,
}) {
  String p(RouteStop<T> s) => '${s.lat},${s.lng}';
  final dest = route.last;
  final waypoints = route.sublist(0, route.length - 1).take(9).map(p).join('|');
  return Uri.https('www.google.com', '/maps/dir/', {
    'api': '1',
    if (startLat != null) 'origin': '$startLat,$startLng',
    'destination': p(dest),
    if (waypoints.isNotEmpty) 'waypoints': waypoints,
    'travelmode': 'driving',
  });
}
