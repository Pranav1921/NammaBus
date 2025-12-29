import 'dart:async';
import 'dart:math';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:logging/logging.dart';

final _logger = Logger('RouteCalculatorService');

class RouteCalculatorService {
  // No longer need Dio or an API key.

  /// Calculates a "real-time" ETA based on the bus's current speed and straight-line distance.
  /// This method is free and does not use any external APIs.
  /// It requires the bus's current speed to be passed in from the map screen.
  Future<Map<String, dynamic>?> getEtaAndDistance(
      LatLng busLocation, LatLng stopLocation,
      {double? currentBusSpeedMetersPerSecond}) async {
    _logger.info("Calculating ETA based on current speed (no API call).");

    try {
      // 1. Calculate the straight-line distance in meters.
      final double distanceInMeters = _distanceBetween(
        busLocation.latitude,
        busLocation.longitude,
        stopLocation.latitude,
        stopLocation.longitude,
      );

      // 2. Use the bus's current speed. If it's not provided or is near zero (bus is stopped),
      //    fall back to a slow, walking-like speed to avoid infinite ETAs and give a realistic "worst-case" time.
      double speed = currentBusSpeedMetersPerSecond ?? 0.0;
      if (speed < 1.0) {
        speed = 1.5; // Assume a slow speed (e.g., 1.5 m/s or 5.4 km/h) if bus is stopped.
      }

      // 3. Calculate duration in seconds and convert to minutes.
      final double durationInSeconds = distanceInMeters / speed;
      final int durationInMinutes = (durationInSeconds / 60).ceil(); // Round up to the next minute.

      return {
        'duration': durationInMinutes,
        'distance': distanceInMeters.round(),
      };
    } catch (e) {
      _logger.severe('Error calculating current-speed ETA: $e');
      return null;
    }
  }

  /// Decodes a polyline string into a list of LatLng points.
  List<LatLng> decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return points;
  }

  /// Calculates the minimum distance from a user's location to any point on the given route.
  double calculateMinDistanceToRoute(
      LatLng userLocation, List<LatLng> routePoints) {
    if (routePoints.isEmpty) {
      return double.infinity;
    }

    double minDistance = double.infinity;

    for (final point in routePoints) {
      final distance = _distanceBetween(
        userLocation.latitude,
        userLocation.longitude,
        point.latitude,
        point.longitude,
      );
      if (distance < minDistance) {
        minDistance = distance;
      }
    }

    return minDistance;
  }

  /// Calculates the distance between two geographic coordinates using the Haversine formula.
  double _distanceBetween(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371e3; // Earth's radius in meters
    final phi1 = lat1 * pi / 180;
    final phi2 = lat2 * pi / 180;
    final deltaPhi = (lat2 - lat1) * pi / 180;
    final deltaLambda = (lon2 - lon1) * pi / 180;

    final a = sin(deltaPhi / 2) * sin(deltaPhi / 2) +
        cos(phi1) * cos(phi2) * sin(deltaLambda / 2) * sin(deltaLambda / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return r * c;
  }
}
