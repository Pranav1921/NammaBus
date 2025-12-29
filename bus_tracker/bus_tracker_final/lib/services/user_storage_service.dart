import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class UserStorageService {
  static const _nameKey = 'passenger_name';
  static const _emailKey = 'passenger_email';
  static const _uidKey = 'passenger_uid';
  static const _isLoggedInKey = 'is_logged_in';
  static const _deviceUuidKey = 'device_uuid';
  static const _recentRoutesKey = 'recent_routes';

  static SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  Future<void> savePassengerProfile({
    required String name,
    required String email,
    required String uid,
  }) async {
    await _prefs?.setString(_nameKey, name);
    await _prefs?.setString(_emailKey, email);
    await _prefs?.setString(_uidKey, uid);
    await _prefs?.setBool(_isLoggedInKey, true);
  }

  Future<Map<String, String>> getPassengerProfile() async {
    return {
      'name': _prefs?.getString(_nameKey) ?? 'Passenger',
      'email': _prefs?.getString(_emailKey) ?? 'Not signed in',
      'uid': _prefs?.getString(_uidKey) ?? '',
      'isLoggedIn': (_prefs?.getBool(_isLoggedInKey) ?? false).toString(),
    };
  }

  Future<void> clearPassengerProfile() async {
    await _prefs?.remove(_nameKey);
    await _prefs?.remove(_emailKey);
    await _prefs?.remove(_uidKey);
    await _prefs?.remove(_isLoggedInKey);
    await _prefs?.remove(_recentRoutesKey);
  }

  String? getDeviceUUID() {
    return _prefs?.getString(_deviceUuidKey);
  }

  Future<String> setDeviceUUID() async {
    String? uuid = getDeviceUUID();
    if (uuid == null) {
      uuid = const Uuid().v4();
      await _prefs?.setString(_deviceUuidKey, uuid);
    }
    return uuid;
  }

  Future<void> addRecentRoute(String routeId, String routeName) async {
    final routes = await getRecentRoutes();
    // Avoid duplicates
    routes.removeWhere((route) => route['id'] == routeId);
    routes.insert(0, {'id': routeId, 'name': routeName});
    // Keep the list to a reasonable size
    final uniqueRoutes = routes.take(5).toList();
    await _prefs?.setString(_recentRoutesKey, jsonEncode(uniqueRoutes));
  }

  Future<List<Map<String, String>>> getRecentRoutes() async {
    final routesString = _prefs?.getString(_recentRoutesKey);
    if (routesString != null) {
      final List<dynamic> decoded = jsonDecode(routesString);
      return decoded.map((route) => Map<String, String>.from(route)).toList();
    }
    return [];
  }
}
