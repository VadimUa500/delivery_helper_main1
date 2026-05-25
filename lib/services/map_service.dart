import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'maps_config.dart';

class MapService {
  static Future<List<Map<String, dynamic>>> autocompleteAddress(
      String input,
      ) async {
    final query = input.trim();

    if (query.length < 3) return [];

    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/autocomplete/json'
          '?input=${Uri.encodeComponent(query)}'
          '&language=uk'
          '&components=country:ua'
          '&key=${MapsConfig.googleApiKey}',
    );

    final response = await http.get(url);
    final data = jsonDecode(response.body);

    if (data['status'] != 'OK' && data['status'] != 'ZERO_RESULTS') {
      throw Exception(
        'Places error: ${data['status']} | ${data['error_message'] ?? "No details"}',
      );
    }

    final predictions = data['predictions'] as List<dynamic>? ?? [];

    return predictions.map((p) {
      return {
        'description': p['description']?.toString() ?? '',
        'place_id': p['place_id']?.toString() ?? '',
      };
    }).toList();
  }

  static Future<Map<String, dynamic>> getPlaceDetails(String placeId) async {
    if (placeId.trim().isEmpty) {
      throw Exception('Place ID is empty');
    }

    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/details/json'
          '?place_id=${Uri.encodeComponent(placeId)}'
          '&fields=formatted_address,geometry'
          '&language=uk'
          '&key=${MapsConfig.googleApiKey}',
    );

    final response = await http.get(url);
    final data = jsonDecode(response.body);

    if (data['status'] != 'OK') {
      throw Exception(
        'Place details error: ${data['status']} | ${data['error_message'] ?? "No details"}',
      );
    }

    final result = data['result'];
    final location = result['geometry']['location'];

    return {
      'address': result['formatted_address']?.toString() ?? '',
      'lat': (location['lat'] as num).toDouble(),
      'lng': (location['lng'] as num).toDouble(),
    };
  }

  static Future<LatLng> geocodeAddress(String address) async {
    final query = address.trim();

    if (query.isEmpty) {
      throw Exception('Address is empty');
    }

    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/geocode/json'
          '?address=${Uri.encodeComponent(query)}'
          '&language=uk'
          '&region=ua'
          '&key=${MapsConfig.googleApiKey}',
    );

    final response = await http.get(url);
    final data = jsonDecode(response.body);

    if (data['status'] != 'OK') {
      throw Exception(
        'Google Geocoding error: ${data['status']} | ${data['error_message'] ?? "No details"}',
      );
    }

    final results = data['results'] as List<dynamic>? ?? [];

    if (results.isEmpty) {
      throw Exception('Address not found: $address');
    }

    final location = results[0]['geometry']['location'];

    return LatLng(
      (location['lat'] as num).toDouble(),
      (location['lng'] as num).toDouble(),
    );
  }

  static Future<List<LatLng>> getRoutePolyline({
    required double originLat,
    required double originLng,
    required double destinationLat,
    required double destinationLng,
  }) async {
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/directions/json'
          '?origin=$originLat,$originLng'
          '&destination=$destinationLat,$destinationLng'
          '&mode=driving'
          '&language=uk'
          '&region=ua'
          '&key=${MapsConfig.googleApiKey}',
    );
    final response = await http.get(url);
    final data = jsonDecode(response.body);
    if (data['status'] != 'OK') {
      throw Exception(
        'Google Directions error: ${data['status']} | ${data['error_message'] ?? "No details"}',
      );
    }
    final routes = data['routes'] as List<dynamic>? ?? [];
    if (routes.isEmpty) {
      throw Exception('Route not found');
    }
    final encodedPolyline = routes[0]['overview_polyline']['points'];
    return _decodePolyline(encodedPolyline);
  }

  static Future<Map<String, dynamic>> getRouteInfo({
    required double originLat,
    required double originLng,
    required double destinationLat,
    required double destinationLng,
  }) async {
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/directions/json'
          '?origin=$originLat,$originLng'
          '&destination=$destinationLat,$destinationLng'
          '&mode=driving'
          '&language=uk'
          '&region=ua'
          '&key=${MapsConfig.googleApiKey}',
    );
    final response = await http.get(url);
    final data = jsonDecode(response.body);
    if (data['status'] != 'OK') {
      throw Exception(
        'Google Directions info error: ${data['status']} | ${data['error_message'] ?? "No details"}',
      );
    }
    final routes = data['routes'] as List<dynamic>? ?? [];
    if (routes.isEmpty) {
      throw Exception('Route info not found');
    }
    final legs = routes[0]['legs'] as List<dynamic>? ?? [];
    if (legs.isEmpty) {
      throw Exception('Route legs not found');
    }
    final leg = legs[0];
    return {
      'distance_text': leg['distance']['text'],
      'duration_text': leg['duration']['text'],
      'distance_meters': leg['distance']['value'],
      'duration_seconds': leg['duration']['value'],
    };
  }

  static List<LatLng> _decodePolyline(String encoded) {
    final List<LatLng> polyline = [];

    int index = 0;
    int lat = 0;
    int lng = 0;

    while (index < encoded.length) {
      int shift = 0;
      int result = 0;
      int b;

      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);

      lat += ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);

      shift = 0;
      result = 0;

      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);

      lng += ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);

      polyline.add(
        LatLng(lat / 100000.0, lng / 100000.0),
      );
    }

    return polyline;
  }
}