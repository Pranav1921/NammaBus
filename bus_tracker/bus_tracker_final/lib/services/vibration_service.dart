import 'package:vibration/vibration.dart';
import 'package:logging/logging.dart';

final _logger = Logger('VibrationService');

/// A service to handle device vibrations, including continuous patterns and cancellation.
/// This uses the 'vibration' package for cross-platform support.
class VibrationService {
  // A static flag to track if a continuous vibration is currently active.
  static bool _isVibrating = false;

  /// Triggers a single, short vibration.
  static Future<void> vibrate() async {
    bool? hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator == true) {
      Vibration.vibrate();
    } else {
      _logger.warning('Device does not have a vibrator.');
    }
  }

  /// Starts a long, repeating vibration pattern to alert the user.
  /// This pattern will continue indefinitely until `stopVibration()` is called.
  /// It does nothing if a vibration is already in progress.
  static Future<void> startContinuousVibration() async {
    // If we are already vibrating, don't do anything to avoid conflicts.
    if (_isVibrating) {
      _logger.info('Vibration already in progress. Ignoring request.');
      return;
    }

    // Check if the device is capable of vibrating.
    bool? hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator == true) {
      _logger.info('Starting continuous vibration.');
      _isVibrating = true;
      // This pattern tells the device to:
      // 1. Wait for 500 milliseconds (0.5s)
      // 2. Vibrate for 1500 milliseconds (1.5s)
      // 3. Repeat this pattern from the beginning (index 0).
      Vibration.vibrate(pattern: [500, 1500, 500, 1500], repeat: 0);
    } else {
      _logger.warning('Device does not have a vibrator.');
    }
  }

  /// Stops any ongoing vibration pattern started by this service.
  /// This is safe to call even if no vibration is active.
  static Future<void> stopVibration() async {
    // If we aren't vibrating, there's nothing to stop.
    if (!_isVibrating) {
      return;
    }

    // Check if the device has a vibrator before trying to cancel.
    bool? hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator == true) {
      _logger.info('Stopping vibration.');
      _isVibrating = false;
      // This is the command that cancels the repeating pattern.
      Vibration.cancel();
    }
  }
}
