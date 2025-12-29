import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Updates the alert status and message for a specific bus.
  Future<void> updateBusAlert(String busId, String? alertMessage) {
    // A null message indicates the alert is being cleared.
    return _db.collection('buses').doc(busId).update({
      'alertMessage': alertMessage,
    });
  }

  Future<void> logPassengerTrip({
    required String passengerId,
    required String routeId,
    required String routeName,
    required String destinationStop,
  }) {
    return _db.collection('passenger_trips').add({
      'passengerId': passengerId,
      'routeId': routeId,
      'routeName': routeName,
      'destination': destinationStop,
      'completedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot> getActiveBusesStream() {
    return _db
        .collection('buses')
        .where('isTracking', isEqualTo: true)
        .snapshots();
  }

  Future<DocumentSnapshot> getConductorProfile(String uid) {
    return _db.collection('conductors').doc(uid).get();
  }

  Future<String> startTrip(
    String busId,
    String driverId,
    String routeId,
    String busNumber,
    String routeName,
  ) async {
    final tripRef = _db.collection('historical_trips').doc();
    await tripRef.set({
      'busId': busId,
      'driverId': driverId,
      'routeId': routeId,
      'busNumber': busNumber,
      'routeName': routeName,
      'startTime': FieldValue.serverTimestamp(),
      'endTime': null,
      'isActive': true,
    });
    return tripRef.id;
  }

  Future<void> endTrip(String tripId) {
    return _db.collection('historical_trips').doc(tripId).update({
      'endTime': FieldValue.serverTimestamp(),
      'isActive': false,
    });
  }

  Future<void> updateBusLocation({
    required String busId,
    required String busNumber,
    required String driverId,
    required String routeId,
    required String tripId,
    required GeoPoint location,
    required double degree,
    required double speed,
  }) {
    // When a bus updates its location, it is not in an alert state by default.
    return _db.collection('buses').doc(busId).set({
      'lat': location.latitude,
      'long': location.longitude,
      'timestamp': FieldValue.serverTimestamp(),
      'isTracking': true,
      'degree': degree,
      'busNumber': busNumber,
      'driverId': driverId,
      'routeId': routeId,
      'tripId': tripId,
      'speed': speed,
    }, SetOptions(merge: true)); // Use merge to not overwrite the alertMessage
  }

  Future<void> stopTracking(String busId) async {
    final docRef = _db.collection('buses').doc(busId);
    final doc = await docRef.get();
    if (doc.exists) {
      // When tracking stops, clear any active alert.
      await docRef.update({'isTracking': false, 'alertMessage': null});
    }
  }

  Stream<QuerySnapshot> getLiveBusLocations(String routeId) {
    return _db
        .collection('buses')
        .where('isTracking', isEqualTo: true)
        .where('routeId', isEqualTo: routeId)
        .snapshots();
  }

  Stream<QuerySnapshot> getRoutes() {
    return _db.collection('routes_data').snapshots();
  }

  Future<DocumentSnapshot> getRouteDetails(String routeId) {
    return _db.collection('routes_data').doc(routeId).get();
  }

  Stream<QuerySnapshot> getCompletedTripsForPassenger(String passengerId) {
    return _db
        .collection('passenger_trips')
        .where('passengerId', isEqualTo: passengerId)
        .orderBy('completedAt', descending: true)
        .limit(20)
        .snapshots();
  }

  Stream<QuerySnapshot> getCompletedTripHistory() {
    return _db
        .collection('historical_trips')
        .where('isActive', isEqualTo: false)
        .orderBy('endTime', descending: true)
        .limit(20)
        .snapshots();
  }
}
