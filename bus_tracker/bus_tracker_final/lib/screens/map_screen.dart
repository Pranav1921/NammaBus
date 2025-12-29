import 'dart:async';
import 'dart:ui' as ui;
import 'package:bus_tracker_final/screens/conductor_profile_screen.dart';
import 'package:bus_tracker_final/screens/passenger_profile_screen.dart';
import 'package:bus_tracker_final/screens/role_selection.dart';
import 'package:bus_tracker_final/services/auth_service.dart';
import 'package:bus_tracker_final/services/firestore_service.dart';
import 'package:bus_tracker_final/services/location_service.dart';
import 'package:bus_tracker_final/services/notification_service.dart';
import 'package:bus_tracker_final/services/route_calculator_service.dart';
import 'package:bus_tracker_final/services/user_storage_service.dart';
import 'package:bus_tracker_final/services/vibration_service.dart';
import 'package:bus_tracker_final/services/volume_service.dart';
import 'package:bus_tracker_final/util/app_colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:logging/logging.dart';
import 'package:geolocator/geolocator.dart';

final _logger = Logger('MapScreenState');

const double _alertDistanceMeters = 2000;
const double _arrivalDistanceMeters = 200;

class MapScreen extends StatefulWidget {
  final bool isConductor;
  const MapScreen({super.key, required this.isConductor});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // Services and state variables
  final Completer<GoogleMapController> _mapController = Completer();
  final FirestoreService _firestoreService = FirestoreService();
  final LocationService _locationService = LocationService();
  final RouteCalculatorService _routeCalculatorService = RouteCalculatorService();
  final AuthService _authService = AuthService();
  final UserStorageService _storageService = UserStorageService();
  final NotificationService _notificationService = NotificationService();
  final VolumeService _volumeService = VolumeService();
  // final VibrationService _vibrationService = VibrationService(); // REMOVED - Not needed for static calls
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late final String _busId;
  String? _busNumber;
  String? _driverId;
  String? _currentTripId;
  bool _isTracking = false;
  bool _blinkState = true;
  StreamSubscription<Position>? _conductorLocationSubscription;
  bool _areIconsLoaded = false;
  BitmapDescriptor? _busIcon;
  BitmapDescriptor? _busAlertIcon; // New icon for alerts
  BitmapDescriptor? _stopIcon;
  String? _selectedRouteId;
  String? _selectedRouteName;
  //Map<String, dynamic>? _currentRouteDetails;
  final ValueNotifier<Map<String, dynamic>?> _activeAlertNotifier = ValueNotifier<Map<String, dynamic>?>(null);
  Map<String, dynamic>? _currentRouteDetails;
  final Map<String, Marker> _busMarkers = {};
  Map<String, dynamic>? _currentlyDisplayedAlert;
  final Set<Polyline> _polylines = <Polyline>{};
  final Set<Marker> _stopMarkers = <Marker>{};
  StreamSubscription<QuerySnapshot<Object?>>? _busLocationSubscription;
  List<Map<String, dynamic>> _activeBusesWithData = [];
  String? _focusedBusId;
  bool _didAnimateToRoute = false;
  Map<String, dynamic> _profileData = {};
  String? _destinationStopName;
  bool _alertTriggered = false;
  bool _arrivedNotificationSent = false;
  final TextEditingController _stopSearchController = TextEditingController();
  String _stopSearchQuery = '';

  // --- State for Conductor Alert ---
  bool _isAlertActive = false;
  String? _activeAlertMessage;
  Timer? _blinkingTimer;

  @override
  void initState() {
    super.initState();
    _busId = _locationService.getDeviceId();
    _locationService.requestPermission();
    _loadMapIcons();
    _loadUserProfile();
    _notificationService.init();
    _volumeService.startListening();

    // --- ADD THIS BLOCK BACK ---
    // This timer is responsible for the blinking effect for passengers.
    if (!widget.isConductor) {
      _blinkingTimer = Timer.periodic(const Duration(milliseconds: 700), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }

        // Only bother updating state if there is an active alert
        final hasAlerts = _activeBusesWithData.any((bus) => bus['isAlertActive'] as bool? ?? false);
        if (!hasAlerts) {
          // If no alerts, ensure the last state was visible
          if (!_blinkState) {
            setState(() => _blinkState = true);
          }
          return;
        }

        // Flip the blink state to create the blinking effect
        setState(() {
          _blinkState = !_blinkState;
        });
      });
    }
  }


  @override
  void dispose() {
    _busLocationSubscription?.cancel();
    _conductorLocationSubscription?.cancel();
    _blinkingTimer?.cancel();
    if (widget.isConductor && _isTracking) {
      _locationService.stopLocationUpdates();
      if (_isAlertActive) { // Ensure alert is cleared if app is closed
        _firestoreService.updateBusAlert(_busId, null);
      }
      _firestoreService.stopTracking(_busId);
    }
    _stopSearchController.dispose();
    _volumeService.stopListening();
    super.dispose();
  }

  // --- LOGIC METHODS ---
  Future<void> _moveCamera(LatLng position, {double? zoom}) async {
    final GoogleMapController controller = await _mapController.future;
    final cameraUpdate = zoom != null
        ? CameraUpdate.newLatLngZoom(position, zoom)
        : CameraUpdate.newLatLng(position);
    controller.animateCamera(cameraUpdate);
  }

  Future<void> _loadUserProfile() async {
    setState(() => _profileData = {});
    final user = _authService.currentUser;
    if (user == null && !widget.isConductor) {
      final profile = await _storageService.getPassengerProfile();
      if (mounted) setState(() => _profileData = profile);
      return;
    }
    if (user == null) return;
    if (widget.isConductor) {
      final doc = await _firestoreService.getConductorProfile(user.uid);
      if (doc.exists && mounted) {
        setState(() {
          _profileData = doc.data() as Map<String, dynamic>;
          _profileData['email'] = user.email;
        });
      } else {
        if (mounted) {
          setState(() {
            _profileData = {'name': 'Conductor', 'email': user.email};
          });
        }
      }
    } else {
      final profile = await _storageService.getPassengerProfile();
      if (mounted) {
        setState(() {
          _profileData = profile;
        });
        if (_profileData['isLoggedIn'] != 'true') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scaffoldKey.currentState?.openDrawer();
          });
        }
      }
    }
  }

  void _loadMapIcons() async {
    try {
      _busIcon = await _getBytesFromAsset('assets/bus_icon.png', 85);
      _busAlertIcon = await _getBytesFromAsset('assets/bus_alert_icon.png', 100);
      _stopIcon = await _getBytesFromAsset('assets/bus_stop.png', 50);
      _logger.info("Custom map icons loaded successfully.");
    } catch (e) {
      _logger.severe('CRITICAL: Error loading map icons: $e. Your `pubspec.yaml` or asset paths are likely incorrect. Falling back to default markers.');
    } finally {
      // This MUST be called to trigger a rebuild, regardless of success or failure.
      if (mounted) {
        setState(() {
          _areIconsLoaded = true;
        });
      }
    }
  }


  Future<BitmapDescriptor> _getBytesFromAsset(String path, int width) async {
    ByteData data = await rootBundle.load(path);
    ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List(), targetWidth: width);
    ui.FrameInfo fi = await codec.getNextFrame();
    final bytes = (await fi.image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
    return BitmapDescriptor.fromBytes(bytes);
  }

  Future<void> _logOut() async {
    await _storageService.clearPassengerProfile();
    if (widget.isConductor) {
      await _authService.signOut();
    }
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const RoleSelectionScreen()),
            (Route<dynamic> route) => false,
      );
    }
  }

  Future<void> _onLoginSuccess() async {
    await _loadUserProfile();
    if (mounted) {
      Navigator.pop(context);
    }
  }

  void _onRouteSelected(String routeId, String routeName) {
    if (mounted) {
      setState(() {
        _selectedRouteId = routeId;
        _selectedRouteName = routeName;
        _busMarkers.clear();
        _stopMarkers.clear();
        _polylines.clear();
        _didAnimateToRoute = false;
        _destinationStopName = null;
        _alertTriggered = false;
        _arrivedNotificationSent = false;
        _activeBusesWithData.clear();
      });
    }
    _firestoreService.getRouteDetails(routeId).then((doc) {
      if (doc.exists) {
        final routeData = doc.data() as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _currentRouteDetails = routeData;
          });
        }
        _drawRoute(routeData);
      }
    });
    if (widget.isConductor && !_isTracking) {
      // Let conductor press the button
    } else if (!widget.isConductor) {
      _subscribeToBusLocations();
    }
  }

  void _drawRoute(Map<String, dynamic> routeData) {
    // This check prevents drawing if icons haven't been loaded yet.
    if (!_areIconsLoaded) return;

    final polylineString = routeData['polyline'] as String?;
    final stops = routeData['stops'] as List<dynamic>?;

    if (polylineString != null) {
      try {
        final points = _routeCalculatorService.decodePolyline(polylineString);
        if (points.isNotEmpty) {
          setState(() {
            _polylines.add(Polyline(
              polylineId: const PolylineId('route_line'),
              points: points,
              color: AppColors.primary.withAlpha(200),
              width: 5,
            ));
          });
        }
      } catch (e, st) {
        _logger.severe('Failed to decode polyline: $e', e, st);
      }
    }

    if (stops != null) {
      final stopMarkers = <Marker>{};
      for (var stopData in stops) {
        final stop = stopData as Map<String, dynamic>;
        final location = stop['location'] as GeoPoint;
        final stopName = stop['stop_name'] as String;
        stopMarkers.add(Marker(
          markerId: MarkerId(stopName),
          position: LatLng(location.latitude, location.longitude),
          icon: _stopIcon ?? BitmapDescriptor.defaultMarker,
          infoWindow: InfoWindow(title: stopName),
          anchor: const Offset(0.5, 0.5), // This centers your custom icon on the coordinate
        ));
      }
      if (mounted) {
        setState(() {
          _stopMarkers.addAll(stopMarkers);
        });
      }
    }
  }


  void _handleConductorAction() {
    if (_isTracking) {
      _stopTracking();
    } else {
      if (_busNumber == null || _driverId == null) {
        _showSnackBar('Please setup Bus and Driver ID first.', AppColors.destructive);
        _showTripSetupModal();
      } else if (_selectedRouteId == null) {
        _showSnackBar('Please select a route first.', AppColors.destructive);
        _showRouteSelectionModal();
      } else {
        _startTracking();
      }
    }
  }

  void _startTracking() async {
    if (_selectedRouteId == null || _busNumber == null || _driverId == null || _selectedRouteName == null) {
      _showSnackBar('Setup incomplete. Cannot start trip.', AppColors.destructive);
      return;
    }
    if (_isTracking) return;
    try {
      final tripId = await _firestoreService.startTrip(_busId, _driverId!, _selectedRouteId!, _busNumber!, _selectedRouteName!);
      _currentTripId = tripId;
      _locationService.startLocationUpdates(_selectedRouteId!, _busId, _busNumber!, _driverId!, _currentTripId!);
      _conductorLocationSubscription = _locationService.onLocationChanged.listen(_updateConductorMarker);
      if (mounted) setState(() => _isTracking = true);
      _showSnackBar('Journey started on $_selectedRouteName.', AppColors.primary);
    } catch (e) {
      _logger.severe('Failed to start trip logging: $e');
      _showSnackBar('Failed to start trip. Check logs.', AppColors.destructive);
    }
  }

  void _stopTracking() async {
    if (!_isTracking || _currentTripId == null) return;

    if (_isAlertActive) {
      await _setConductorAlert(null); // Clear the alert
    }

    _showSnackBar('Ending journey...', AppColors.primary);
    _locationService.stopLocationUpdates();
    await _firestoreService.stopTracking(_busId);
    await _firestoreService.endTrip(_currentTripId!);
    _conductorLocationSubscription?.cancel();
    if (mounted) {
      setState(() {
        _busMarkers.remove(_busId);
        _isTracking = false;
        _currentTripId = null;
        _selectedRouteId = null;
        _selectedRouteName = null;
        _currentRouteDetails = null;
        _polylines.clear();
        _stopMarkers.clear();
      });
    }
    _showSnackBar('Journey completed and logged.', AppColors.success);
  }

  void _updateConductorMarker(Position locationData) {
    if (!mounted || !_areIconsLoaded) return;
    final position = LatLng(locationData.latitude, locationData.longitude);
    final marker = Marker(
      markerId: MarkerId(_busId),
      position: position,
      icon: _isAlertActive
          ? (_busAlertIcon ?? _busIcon ?? BitmapDescriptor.defaultMarker)
          : (_busIcon ?? BitmapDescriptor.defaultMarker),
      infoWindow: InfoWindow(title: 'My Bus: $_busNumber'),
      anchor: const Offset(0.5, 0.5),
      zIndex: 2,
    );
    setState(() {
      _busMarkers[_busId] = marker;
    });
    if (_isTracking) {
      _moveCamera(position, zoom: 15.0);
    }
  }

  Future<void> _setConductorAlert(String? message) async {
    final bool willBeActive = message != null;
    await _firestoreService.updateBusAlert(_busId, message);

    setState(() {
      _isAlertActive = willBeActive;
      _activeAlertMessage = message;
    });

    _blinkingTimer?.cancel();

    if (willBeActive) {
      _showSnackBar("Alert active: $message", AppColors.accent);
      _blinkingTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
        if (!mounted || !_isAlertActive) {
          timer.cancel();
          return;
        }
        final currentMarker = _busMarkers[_busId];
        if (currentMarker != null) {
          setState(() {
            _busMarkers[_busId] = currentMarker.copyWith(visibleParam: !currentMarker.visible);
          });
        }
      });
    } else {
      _showSnackBar("Alert deactivated.", AppColors.success);
      final currentMarker = _busMarkers[_busId];
      if (currentMarker != null && !currentMarker.visible) {
        setState(() {
          _busMarkers[_busId] = currentMarker.copyWith(visibleParam: true);
        });
      }
    }
  }

  void _showConductorAlertDialog() {
    if (!_isTracking) {
      _showSnackBar("Cannot set alert. Journey not started.", AppColors.destructive);
      return;
    }

    final issues = ['Heavy Traffic', 'Bus Breakdown', 'Medical Emergency', 'Delayed Start'];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(_isAlertActive ? 'Update or Clear Alert' : 'Report an Issue'),
          content: SingleChildScrollView(
            child: ListBody(
              children: issues.map((issue) => RadioListTile<String>(
                title: Text(issue),
                value: issue,
                groupValue: _activeAlertMessage,
                onChanged: (String? value) {
                  if (value != null) {
                    _setConductorAlert(value);
                    Navigator.of(context).pop();
                  }
                },
              )).toList(),
            ),
          ),
          actions: <Widget>[
            if (_isAlertActive)
              TextButton(
                child: const Text('Clear Alert', style: TextStyle(color: AppColors.success)),
                onPressed: () {
                  _setConductorAlert(null);
                  Navigator.of(context).pop();
                },
              ),
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _subscribeToBusLocations() {
    if (_selectedRouteId == null) return;
    _busLocationSubscription?.cancel();
    _busLocationSubscription = _firestoreService.getLiveBusLocations(_selectedRouteId!).listen(
          (snapshot) {
        if (mounted) _updateMarkers(snapshot.docs);
      },
      onError: (error) => _logger.severe('Live bus subscription error: $error'),
    );
  }

  // REPLACE your current _updateMarkers method with this one

  // In _updateMarkers method
  // In _updateMarkers method

  // REPLACE your current _updateMarkers method with this one

  // Find this method in your file.
  // Find this method in your file
  Future<void> _updateMarkers(List<DocumentSnapshot> busDocs) async {
    // --- REPLACE THE LOGIC AT THE TOP OF THIS METHOD WITH THIS BLOCK ---

    // 1. Find if any bus in the NEW data has an active alert.
    Map<String, dynamic>? newAlertData;
    try {
      // Find the document of the bus with an active alert.
      final doc = busDocs.firstWhere((d) => (d.data() as Map<String, dynamic>?)?['isAlertActive'] == true);
      newAlertData = doc.data() as Map<String, dynamic>;
      newAlertData['uuid'] = doc.id;
    } catch (e) {
      // No bus in this specific batch of updates has an active alert.
      newAlertData = null;
    }

    // 2. Get the ID of the bus that is currently being displayed as alerting (if any).
    final currentAlertedBusId = _activeAlertNotifier.value?['uuid'];

    // 3. Apply the new, smarter update logic.
    if (newAlertData != null) {
      // An alert was found in the latest data. Show it.
      // This correctly shows a new alert or updates the existing one.
      _activeAlertNotifier.value = newAlertData;
    } else if (currentAlertedBusId != null) {
      // No alert was found in the new data, BUT we are currently showing one.
      // We must check if the bus that was alerting has now cleared its status.
      try {
        final previouslyAlertingBusDoc = busDocs.firstWhere((d) => d.id == currentAlertedBusId);
        // If we found the bus and its alert is now false, we can clear the panel.
        if ((previouslyAlertingBusDoc.data() as Map<String, dynamic>?)?['isAlertActive'] == false) {
          _activeAlertNotifier.value = null;
        }
        // If the previously alerting bus is not in this update batch, we do nothing.
        // We wait for an update from that specific bus before clearing its alert.
      } catch (e) {
        // The previously alerting bus was not in this update batch.
        // DO NOTHING. Keep the current alert visible.
      }
    }
    // --- END OF THE NEW LOGIC ---

    // The rest of your _updateMarkers method continues below, unchanged.
    if (!mounted || !_areIconsLoaded) return;
    // ...

  // ...

  if (busDocs.isEmpty && _selectedRouteId != null && !widget.isConductor) {
      _showSnackBar('No active buses currently on the $_selectedRouteName route.', AppColors.textSecondary);
    }
    if (_currentRouteDetails == null) {
      return;
    }

    LatLng? destinationLatLng;
    if (_destinationStopName != null) {
      final stops = _currentRouteDetails!['stops'] as List<dynamic>? ?? [];
      try {
        final destinationStopData = stops.firstWhere((stop) => stop['stop_name'] == _destinationStopName);
        final location = destinationStopData['location'] as GeoPoint;
        destinationLatLng = LatLng(location.latitude, location.longitude);
      } catch (e) {
        _logger.warning('Could not find coordinates for destination: $_destinationStopName');
        destinationLatLng = null;
      }
    }

    final newMarkers = <String, Marker>{};
    final List<Map<String, dynamic>> updatedBusesWithData = [];
    LatLng? firstBusLocation;

    if (widget.isConductor && _busMarkers.containsKey(_busId)) {
      newMarkers[_busId] = _busMarkers[_busId]!;
    }

    await Future.wait(busDocs.map((doc) async {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) return;
      if (widget.isConductor && doc.id == _busId) return;

      data['uuid'] = doc.id;
      final lat = (data['lat'] as num?)?.toDouble() ?? 0.0;
      final lng = (data['long'] as num?)?.toDouble() ?? 0.0;
      if (lat == 0.0 || lng == 0.0) return;

      final busLocation = LatLng(lat, lng);
      firstBusLocation ??= busLocation;
      final double currentSpeed = (data['speed'] as num?)?.toDouble() ?? 0.0;

      final bool isAlertActive = data['isAlertActive'] ?? false;
      final String? alertMessage = data['alertMessage'];
      final busNumber = data['busNumber'] ?? 'N/A';

      String snippetText;

      if (isAlertActive && alertMessage != null) {
        snippetText = "ALERT: $alertMessage";
      } else if (destinationLatLng != null) {
        final distanceResult = await _routeCalculatorService.getEtaAndDistance(busLocation, destinationLatLng, currentBusSpeedMetersPerSecond: currentSpeed);
        if (distanceResult != null) {
          final distance = distanceResult['distance'];
          final etaMinutes = distanceResult['eta'] as int?;

          if (distance != null) {
            String distanceString;
            if (distance > 1000) {
              final km = (distance / 1000).toStringAsFixed(1);
              distanceString = "~ $km km";
            } else {
              distanceString = "~ $distance m";
            }

            String etaString = (etaMinutes != null && etaMinutes > 0) ? " (≈ $etaMinutes min)" : "";
            snippetText = distanceString + etaString;

            if (distance <= _alertDistanceMeters && !_alertTriggered) {
              VibrationService.startContinuousVibration();
              _showSnackBar('Approaching $_destinationStopName! Press volume button to stop vibration.', AppColors.success);
              if (mounted) setState(() => _alertTriggered = true);
            }
            if (distance <= _arrivalDistanceMeters && !_arrivedNotificationSent) {
              VibrationService.stopVibration();
              _notificationService.showDestinationAlertNotification(_destinationStopName!);
              if (mounted) setState(() => _arrivedNotificationSent = true);
            }
          } else {
            snippetText = "Calculating...";
          }
        } else {
          snippetText = "Calculating...";
        }
      } else {
        snippetText = "Set destination for ETA";
      }

      final busDataWithDistance = {...data, 'distanceText': snippetText, 'isAlertActive': isAlertActive, 'alertMessage': alertMessage};
      updatedBusesWithData.add(busDataWithDistance);

      newMarkers[doc.id] = Marker(
        markerId: MarkerId(doc.id),
        position: busLocation,
        icon: isAlertActive ? (_busAlertIcon ?? _busIcon ?? BitmapDescriptor.defaultMarker) : (_busIcon ?? BitmapDescriptor.defaultMarker),
        infoWindow: InfoWindow(title: 'Bus: $busNumber', snippet: snippetText),
        anchor: const Offset(0.5, 0.5),
        visible: isAlertActive ? _blinkState : true,
        onTap: () {
          if (mounted) {
            setState(() {
              _focusedBusId = doc.id;
            });
            _showSnackBar('Bus $busNumber selected.', AppColors.primary);
          }
        },
        zIndex: isAlertActive ? 3 : (doc.id == _focusedBusId ? 2 : 1),
      );
    }));

    updatedBusesWithData.sort((a, b) {
      final isAlertA = a['isAlertActive'] as bool? ?? false;
      final isAlertB = b['isAlertActive'] as bool? ?? false;
      if (isAlertA && !isAlertB) return -1;
      if (!isAlertA && isAlertB) return 1;
      return 0;
    });

    if (mounted) {
      setState(() {
        if (!widget.isConductor) {
          _busMarkers.clear();
        }
        _busMarkers.addAll(newMarkers);
        _activeBusesWithData = updatedBusesWithData;
      });
    }

    if (!_didAnimateToRoute && firstBusLocation != null) {
      _moveCamera(firstBusLocation!, zoom: 13.5);
      if (mounted) setState(() => _didAnimateToRoute = true);
    }
  }




  void _showTripSetupModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Trip Details', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 20),
                TextField(
                  onChanged: (value) => _busNumber = value,
                  decoration: const InputDecoration(labelText: 'Bus Number (e.g., KA-01-F-1234)'),
                ),
                const SizedBox(height: 10),
                TextField(
                  onChanged: (value) => _driverId = value,
                  decoration: const InputDecoration(labelText: 'Driver ID'),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    if (_busNumber != null && _driverId != null) {
                      Navigator.of(context).pop();
                      _showSnackBar('Details saved. Ready to start.', AppColors.success);
                    } else {
                      _showSnackBar('Please fill both fields.', AppColors.destructive);
                    }
                  },
                  child: const Text('Save Details'),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showRouteSelectionModal() {
    // Reset search query before opening the modal to ensure a fresh start
    setState(() {
      _stopSearchQuery = '';
    });
    _stopSearchController.clear();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        // Use StatefulBuilder to manage the search query state within the modal
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.6,
              minChildSize: 0.3,
              maxChildSize: 0.9,
              builder: (_, controller) {
                return Container(
                  decoration: BoxDecoration(
                    color: AppColors.card.withOpacity(0.95),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Column(
                    children: [
                      // Drag handle
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Container(
                          width: 40,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.grey[400],
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      // Title
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8.0),
                        child: Text(
                          'Select a Route',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                      ),
                      // Search Bar
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        child: TextField(
                          controller: _stopSearchController,
                          onChanged: (value) {
                            setModalState(() {
                              _stopSearchQuery = value;
                            });
                          },
                          decoration: InputDecoration(
                            labelText: 'Search Routes',
                            hintText: 'e.g., Puttur-Madikeri',
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.1),
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      // Filtered List
                      Expanded(
                        child: StreamBuilder<QuerySnapshot>(
                          stream: _firestoreService.getRoutes(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator());
                            }
                            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                              return const Center(child: Text('No routes available.'));
                            }

                            // Filter the routes based on the search query
                            final filteredRoutes = snapshot.data!.docs.where((doc) {
                              final routeName = (doc.data() as Map<String, dynamic>)['name']?.toString().toLowerCase() ?? '';
                              return routeName.contains(_stopSearchQuery.toLowerCase());
                            }).toList();

                            if (filteredRoutes.isEmpty) {
                              return const Center(child: Text('No matching routes found.'));
                            }

                            return ListView.builder(
                              controller: controller,
                              itemCount: filteredRoutes.length,
                              itemBuilder: (context, index) {
                                final routeDoc = filteredRoutes[index];
                                final routeData = routeDoc.data() as Map<String, dynamic>;
                                final String routeName = routeData['name'] ?? 'Unnamed Route';
                                return ListTile(
                                  leading: const Icon(Icons.alt_route_rounded, color: AppColors.primary),
                                  title: Text(routeName, style: const TextStyle(color: AppColors.textPrimary)),
                                  onTap: () {
                                    // Reset search query and close modal
                                    _stopSearchQuery = '';
                                    Navigator.of(context).pop();
                                    _onRouteSelected(routeDoc.id, routeName);
                                  },
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }



  void _showLiveBusesModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          builder: (_, controller) {
            return Container(
              decoration: BoxDecoration(
                color: AppColors.card.withOpacity(0.9),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Text('Live Buses on $_selectedRouteName', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: _activeBusesWithData.isEmpty
                        ? const Center(child: Text('No live buses to display.'))
                        : ListView.builder(
                      controller: controller,
                      itemCount: _activeBusesWithData.length,
                      itemBuilder: (context, index) {
                        final bus = _activeBusesWithData[index];
                        final busNumber = bus['busNumber'] ?? 'Unknown Bus';
                        final statusText = bus['distanceText'] ?? 'Unknown status';
                        final isAlertActive = bus['isAlertActive'] as bool? ?? false;
                        final alertMessage = bus['alertMessage'] as String?;

                        return ListTile(
                          leading: Icon(
                            isAlertActive ? Icons.warning : Icons.directions_bus,
                            color: isAlertActive ? Colors.orangeAccent : AppColors.primary,
                          ),
                          title: Text('Bus: $busNumber', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // This will show the status, including the km value
                              Text(
                                'Distance: $statusText', // <-- CORRECTED LINE
                                style: TextStyle(color: AppColors.textSecondary.withOpacity(0.9)),
                              ),
                              // If there's an alert, show it as a second line
                              if (isAlertActive && alertMessage != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2.0),
                                  child: Text(
                                    "Alert: $alertMessage",
                                    style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                                  ),
                                ),
                            ],
                          ),
                          onTap: () async {
                            final busId = bus['uuid'] as String;
                            final lat = bus['lat'] as double;
                            final lng = bus['long'] as double;
                            final mapController = await _mapController.future;
                            mapController.showMarkerInfoWindow(MarkerId(busId));
                            _moveCamera(LatLng(lat, lng));
                            setState(() {
                              _focusedBusId = busId;
                            });
                            Navigator.of(context).pop();
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }



  void _showSnackBar(String message, Color backgroundColor) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: backgroundColor,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
    ));
  }

  void _onSetDestination() {

    if (_currentRouteDetails == null) {
      _showSnackBar('Route details not loaded yet. Please wait a moment.', AppColors.destructive);      return; // Stop execution if details are not ready.
    }

    final stops = _currentRouteDetails?['stops'] as List<dynamic>? ?? [];
    if (stops.isEmpty) {
      _showSnackBar('Route stops not available.', AppColors.destructive);
      return;
    }
    final stopNames = stops.map((s) => s['stop_name'] as String).toList();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            final filteredStops = stopNames.where((name) => name.toLowerCase().contains(_stopSearchQuery.toLowerCase())).toList();
            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text('Set Destination', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _stopSearchController,
                    onChanged: (value) => setModalState(() => _stopSearchQuery = value),
                    decoration: InputDecoration(
                      labelText: 'Search for a stop',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filteredStops.length,
                      itemBuilder: (context, index) {
                        final stopName = filteredStops[index];
                        return ListTile(
                          title: Text(stopName),
                          onTap: () {
                            // REMOVED VIBRATION
                            if (mounted) {
                              setState(() {
                                _destinationStopName = stopName;
                                _alertTriggered = false;
                                _arrivedNotificationSent = false;
                              });
                            }
                            _stopSearchController.clear();
                            _stopSearchQuery = '';
                            Navigator.pop(context);
                            _showSnackBar('Destination set to $_destinationStopName.', AppColors.success);
                            if (_busLocationSubscription != null) {
                              _firestoreService.getLiveBusLocations(_selectedRouteId!).first.then((snapshot) {
                                if (mounted) _updateMarkers(snapshot.docs);
                              });
                            }
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: PreferredSize(
        preferredSize: Size.zero,
        child: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      ),
      drawer: _buildDrawer(),
      body: Stack(
        children: [
          if (_areIconsLoaded)
            GoogleMap(
              onMapCreated: (GoogleMapController controller) {
                _mapController.complete(controller);
              },
              initialCameraPosition: const CameraPosition(
                target: LatLng(12.9716, 77.5946),
                zoom: 12,
              ),
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              markers: {..._busMarkers.values, ..._stopMarkers},
              polylines: _polylines,
              padding: EdgeInsets.only(
                bottom: widget.isConductor ? 80 : 150,
                top: 70,
              ),
            )
          else
            const Center(child: CircularProgressIndicator()),
          if (widget.isConductor) _buildConductorAppBar(),
          if (!widget.isConductor) _buildGreetingBar(),
          if (!widget.isConductor) _buildAlertNotificationPanel(),
          if (!widget.isConductor) _buildPassengerUI(),
          if (!widget.isConductor) _buildBusInfoPanel(),
        ],
      ),
      floatingActionButton: widget.isConductor ? _buildConductorFAB() : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildGlassEffect({required Widget child, Gradient? gradient, BorderRadius? borderRadius}) {
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          decoration: BoxDecoration(
            gradient: gradient,
            color: gradient == null ? Colors.white.withOpacity(0.2) : null,
            border: Border.all(
              color: Colors.white.withOpacity(0.25),
              width: 1.0,
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  // In lib/screens/map_screen.dart

  Widget _buildConductorAppBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(top: 10, left: 15, right: 15),
        child: _buildGlassEffect(
          borderRadius: BorderRadius.circular(50),
          gradient: LinearGradient(
            colors: [
              AppColors.primary.withOpacity(0.8),
              AppColors.accent.withOpacity(0.7),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // This outer Expanded widget makes the left section containing the text flexible.
                Expanded(
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.menu, color: Colors.white, size: 28),
                        onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                      ),
                      // --- THE FIX IS HERE ---
                      // The Text widget is now wrapped in Expanded.
                      // This allows it to shrink and grow without causing an overflow.
                      Expanded(
                        child: Text(
                          _selectedRouteName ?? 'Conductor',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          // The ellipsis property will now work correctly for long text.
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1, // Ensures text stays on a single line
                        ),
                      ),
                    ],
                  ),
                ),
                // The widgets on the right side remain unchanged.
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        _isAlertActive ? Icons.warning : Icons.warning_amber_outlined,
                        color: _isAlertActive ? Colors.yellowAccent : Colors.white,
                        size: 28,
                      ),
                      onPressed: _showConductorAlertDialog,
                    ),
                    TextButton.icon(
                      onPressed: _showRouteSelectionModal,
                      icon: const Icon(Icons.alt_route, color: Colors.white, size: 20),
                      label: const Text('Route', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildConductorFAB() {
    final fabColor = _isTracking ? AppColors.destructive : AppColors.success;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: _buildGlassEffect(
        borderRadius: BorderRadius.circular(50),
        gradient: LinearGradient(
          colors: [
            fabColor.withOpacity(0.9),
            fabColor.withOpacity(0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        child: FloatingActionButton.extended(
          onPressed: _handleConductorAction,
          label: Text(
            _isTracking ? 'End Journey' : 'Start Journey',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          icon: Icon(_isTracking ? Icons.stop : Icons.play_arrow, color: Colors.white),
          backgroundColor: Colors.transparent,
          elevation: 0,
          highlightElevation: 0,
        ),
      ),
    );
  }

  Widget _buildGreetingBar() {
    final String name = _profileData['name'] ?? 'Guest';
    return Positioned(
      top: 50,
      left: 15,
      right: 15,
      child: GestureDetector(
        onTap: () => _scaffoldKey.currentState?.openDrawer(),
        child: _buildGlassEffect(
          borderRadius: BorderRadius.circular(50),
          gradient: LinearGradient(
            colors: [
              AppColors.primary.withOpacity(0.7),
              AppColors.accent.withOpacity(0.6),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.menu, color: Colors.white, size: 28),
                const SizedBox(width: 16),
                Text(
                  'Hello, $name!',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: [Shadow(blurRadius: 2.0, color: Colors.black26, offset: Offset(1, 1))],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
// Paste this method inside the _MapScreenState class

  // ADD this method to your _MapScreenState class

  // REPLACE your current _buildAlertNotificationPanel method with this one

  Widget _buildAlertNotificationPanel() {
    // This builder listens directly to our notifier.
    return ValueListenableBuilder<Map<String, dynamic>?>(
      valueListenable: _activeAlertNotifier,
      builder: (context, alertData, child) {
        // The 'alertData' here is the current value of the notifier.

        // If the alert data is null, show nothing.
        if (alertData == null) {
          return const SizedBox.shrink();
        }

        // If we have data, build the panel.
        final busNumber = alertData['busNumber'] ?? 'A bus';
        final alertMessage = alertData['alertMessage'] as String?;

        if (alertMessage == null) {
          return const SizedBox.shrink();
        }

        // This is your existing, correct UI code for the panel.
        return Positioned(
          top: 130,
          left: 15,
          right: 15,
          child: _buildGlassEffect(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: [
                Colors.red.withOpacity(0.85),
                Colors.orange.withOpacity(0.8),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.warning, color: Colors.white, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Alert for Bus: $busNumber',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          alertMessage,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }



  Widget _buildActiveRouteControls() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
      child: _buildGlassEffect(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.9),
            AppColors.accent.withOpacity(0.85),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _selectedRouteName ?? 'Selected Route',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _buildLiveBusCountChip(),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildOptionButton(icon: Icons.alt_route, onTap: () => _showRouteSelectionModal()),
                  _buildOptionButton(icon: _destinationStopName == null ? Icons.flag_outlined : Icons.flag, onTap: _onSetDestination),
                  _buildOptionButton(icon: Icons.directions_bus, onTap: () => _showLiveBusesModal()),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBusInfoPanel() {
    if (_activeBusesWithData.isEmpty) {
      return const SizedBox.shrink();
    }
    return Positioned(
      bottom: 180,
      left: 0,
      right: 0,
      child: SizedBox(
        height: 90,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 15),
          itemCount: _activeBusesWithData.length,
          itemBuilder: (context, index) {
            final bus = _activeBusesWithData[index];
            final busNumber = bus['busNumber'] ?? 'Unknown';
            final distanceText = bus['distanceText'] as String? ?? 'N/A';
            final isFocused = bus['uuid'] == _focusedBusId;
            final isAlertActive = bus['isAlertActive'] as bool? ?? false;
            final alertMessage = bus['alertMessage'] as String?;

            return GestureDetector(
              onTap: () async {
                final busId = bus['uuid'] as String;
                final lat = bus['lat'] as double;
                final lng = bus['long'] as double;
                final controller = await _mapController.future;
                controller.showMarkerInfoWindow(MarkerId(busId));
                _moveCamera(LatLng(lat, lng));
                setState(() {
                  _focusedBusId = busId;
                });
              },
              child: Padding(
                padding: const EdgeInsets.only(right: 10),
                child: _buildGlassEffect(
                  gradient: LinearGradient(
                    colors: [
                      isAlertActive ? Colors.red.withOpacity(0.8) : AppColors.primary.withOpacity(0.85),
                      isAlertActive ? Colors.orange.withOpacity(0.7) : AppColors.accent.withOpacity(0.75),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  child: Container(
                    width: 180,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: isFocused ? Border.all(color: AppColors.accent, width: 2.0) : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center, // Center content vertically
                      children: [
                        Row(
                          children: [
                            Icon(isAlertActive ? Icons.warning : Icons.directions_bus, color: Colors.white, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Bus: $busNumber',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4), // Add a little space
                        // Always show the distance
                        Text(
                          "Distance: $distanceText",
                          style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        // Conditionally show the alert on a new line
                        if (isAlertActive && alertMessage != null)
                          Text(
                            alertMessage,
                            style: const TextStyle(fontSize: 13, color: Colors.yellowAccent, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }




  Widget _buildPassengerUI() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        transitionBuilder: (child, animation) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: animation, curve: Curves.easeInOutCubic)),
            child: FadeTransition(opacity: animation, child: child),
          );
        },
        child: _selectedRouteId == null ? _buildInitialSelectRouteCard() : _buildActiveRouteControls(),
      ),
    );
  }

  Widget _buildInitialSelectRouteCard() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: GestureDetector(
        onTap: () {
          // REMOVED VIBRATION
          _showRouteSelectionModal();
        },
        child: _buildGlassEffect(
          borderRadius: BorderRadius.circular(50),
          gradient: LinearGradient(
            colors: [AppColors.primary.withOpacity(0.8), AppColors.accent.withOpacity(0.7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 16, horizontal: 32),
            child: Text(
              'Select a Route',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOptionButton({required IconData icon, required VoidCallback onTap}) {
    return ClipOval(
      child: Material(
        color: Colors.white.withOpacity(0.15),
        child: InkWell(
          splashColor: AppColors.accent.withOpacity(0.3),
          onTap: onTap, // REMOVED VIBRATION WRAPPER
          child: SizedBox(
            width: 56,
            height: 56,
            child: Icon(icon, color: Colors.white, size: 28),
          ),
        ),
      ),
    );
  }

  Widget _buildLiveBusCountChip() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestoreService.getLiveBusLocations(_selectedRouteId!),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Container();
        }
        final liveBusCount = snapshot.data!.docs.length;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.success.withOpacity(0.3),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.success.withOpacity(0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.directions_bus, color: AppColors.success, size: 16),
              const SizedBox(width: 6),
              Text(
                '$liveBusCount Live',
                style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDrawer() {
    // Get the screen width to calculate a responsive drawer size
    final screenWidth = MediaQuery.of(context).size.width;

    return SizedBox(
      // Set the width to 80% of the screen width, or a max of 320 to look good on tablets
      width: screenWidth * 0.8 < 320 ? screenWidth * 0.8 : 320,
      child: Drawer(
        child: widget.isConductor
            ? ConductorProfileScreen(onSignOut: _logOut, profileData: _profileData)
            : PassengerProfileScreen(
          onLoginSuccess: _onLoginSuccess,
          onLogOut: _logOut,
          profile: _profileData.map((key, value) => MapEntry(key, value.toString())),
        ),
      ),
    );
  }
}
