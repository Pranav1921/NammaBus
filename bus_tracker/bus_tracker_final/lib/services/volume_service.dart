// lib/services/volume_service.dart
import 'dart:async';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:bus_tracker_final/services/vibration_service.dart';

/// A service to manage listening to system volume changes.
class VolumeService {
  StreamSubscription<double>? _subscription;

  /// Starts listening for volume button presses.
  void startListening() {
    if (_subscription != null) return;

    _subscription = FlutterVolumeController.addListener((volume) {
      VibrationService.stopVibration();
    });
  }

  /// Stops listening to volume button presses.
  void stopListening() {
    // The plugin's removeListener handles cancellation.
    FlutterVolumeController.removeListener();
    _subscription = null;
  }
}
