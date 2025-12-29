import 'dart:async';
import 'package:bus_tracker_final/services/firestore_service.dart';
import 'package:bus_tracker_final/services/route_calculator_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:logging/logging.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:bus_tracker_final/device_info.dart'; // Import main to get DeviceInfo

class LocationService {
  StreamSubscription<Position>? _positionStream;
  final FirestoreService _firestoreService = FirestoreService();
  final RouteCalculatorService _routeCalculatorService = RouteCalculatorService();
  final _logger = Logger('LocationService');

  Position? _currentPosition;
  double _bearing = 0.0;

  // --- NEW --- This creates a public stream that other parts of the app can listen to.
  // It's like a radio station broadcasting the current position.
  final StreamController<Position> _locationStreamController = StreamController<Position>.broadcast();
  Stream<Position> get onLocationChanged => _locationStreamController.stream;


  String? _busId;
  String? _busNumber;
  String? _driverId;
  String? _routeId;
  String? _currentTripId;
  String? _polylineEncoded;

  static const double _deviationThresholdMeters = 50.0;

  String getDeviceId() => DeviceInfo.userUUID;
  double getCurrentBearing() => _bearing;

  Future<bool> requestPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _logger.warning("Location services are disabled.");
      return false;
    }

    var status = await Permission.location.status;
    if (status.isDenied) {
      if (await Permission.location.request().isGranted) {
        return true;
      }
    }
    return status.isGranted;
  }

  Future<Position?> getCurrentLocation() async {
    if (!await requestPermission()) {
      _logger.warning("Location permission denied. Cannot get current location.");
      return null;
    }
    try {
      return await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high)
      );
    } catch (e) {
      _logger.severe("Error getting current position: $e");
      return null;
    }
  }

  Future<void> startLocationUpdates(String routeId, String busId, String busNumber, String driverId, String tripId) async {
    if (!await requestPermission()) return;

    _busId = busId;
    _busNumber = busNumber;
    _driverId = driverId;
    _routeId = routeId;
    _currentTripId = tripId;

    final routeDoc = await _firestoreService.getRouteDetails(routeId);
    final routeData = routeDoc.data() as Map<String, dynamic>?;
    _polylineEncoded = routeData?['polyline'] as String?;

    if (_polylineEncoded == null) {
      _logger.warning("Polyline not found for deviation check. Tracking without alert.");
    }

    const foregroundNotificationConfig = ForegroundNotificationConfig(
      notificationTitle: "NammaBus Tracker is Active",
      notificationText: "Broadcasting live bus location.",
      enableWakeLock: true,
    );

    final locationSettings = AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
      foregroundNotificationConfig: foregroundNotificationConfig,
    );

    await _positionStream?.cancel();
    _logger.info('Starting location updates for Bus ID: $busId on Route: $routeId');

    _positionStream = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) async {

      if(_currentPosition != null){
        _bearing = Geolocator.bearingBetween(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
            position.latitude,
            position.longitude
        );
      }
      _currentPosition = position;
      final speed = position.speed;
      final busLocation = LatLng(position.latitude, position.longitude);

      // --- NEW --- Add the new position to our public stream.
      _locationStreamController.add(position);

      if (_polylineEncoded != null) {
        _checkRouteDeviation(busLocation);
      }

      if (_busId != null && _busNumber != null && _driverId != null && _routeId != null && _currentTripId != null) {
        await _firestoreService.updateBusLocation(
          busId: _busId!,
          busNumber: _busNumber!,
          driverId: _driverId!,
          routeId: _routeId!,
          tripId: _currentTripId!,
          location: GeoPoint(position.latitude, position.longitude),
          degree: _bearing,
          speed: speed,
        );
      }
    });
  }

  void _checkRouteDeviation(LatLng busLocation) {
    if (_polylineEncoded == null) return;

    final List<LatLng> routePoints = _routeCalculatorService.decodePolyline(_polylineEncoded!);
    final minDistance = _routeCalculatorService.calculateMinDistanceToRoute(
        busLocation,
        routePoints
    );

    if (minDistance > _deviationThresholdMeters) {
      _logger.warning('DEVIATION ALERT: Bus $_busNumber is ${minDistance.toStringAsFixed(1)}m off route!');
    }
  }

  void stopLocationUpdates() {
    _logger.info('Stopping location updates.');
    _positionStream?.cancel();
    _busId = null;
    _busNumber = null;
    _driverId = null;
    _routeId = null;
    _currentTripId = null;
    _polylineEncoded = null;
  }

  // --- NEW --- It's good practice to close the stream controller when it's no longer needed.
  void dispose() {
    _locationStreamController.close();
  }
}
