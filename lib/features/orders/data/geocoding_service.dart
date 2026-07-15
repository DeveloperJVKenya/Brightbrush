import 'dart:convert';

import 'package:http/http.dart' as http;

class GeocodeResult {
  const GeocodeResult({required this.lat, required this.lng});

  final double lat;
  final double lng;
}

/// Turns a free-text delivery address into coordinates via the Google
/// Geocoding API, so the Route Map can drop a real pin for an order that
/// only ever collected a text address at checkout. Results are meant to be
/// cached back onto the order (see `OrdersRepository.setDeliveryCoordinates`)
/// so the same address is never geocoded twice.
class GeocodingService {
  GeocodingService(this._apiKey);

  final String _apiKey;

  Future<GeocodeResult?> geocode(String address) async {
    if (address.trim().isEmpty) return null;
    final uri = Uri.https('maps.googleapis.com', '/maps/api/geocode/json', {
      'address': address,
      'key': _apiKey,
    });
    final response = await http.get(uri);
    if (response.statusCode != 200) return null;

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body['status'] != 'OK') return null;

    final results = body['results'] as List?;
    if (results == null || results.isEmpty) return null;

    final location = results.first['geometry']['location'] as Map<String, dynamic>;
    final lat = (location['lat'] as num).toDouble();
    final lng = (location['lng'] as num).toDouble();
    return GeocodeResult(lat: lat, lng: lng);
  }
}
