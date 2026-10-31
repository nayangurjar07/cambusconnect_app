import 'package:cloud_firestore/cloud_firestore.dart';

/// Matches the exact Firestore schema written by the web app (src/services/transit.js).
/// Web writes: number, registrationNumber, location.lat, location.lng, headcount,
/// driver, phone, route, routeId, status, speed, capacity, lastUpdate, lastGpsUpdate.
class BusModel {
  final String busId;
  /// Web field: 'number' (e.g. "Bus 14")
  final String busNumber;
  /// Web field: 'registrationNumber'
  final String registrationNumber;
  final int capacity;
  /// Live passenger count — web field: 'headcount'
  final int headcount;
  final String routeId;
  /// Web field: 'route' (route name string)
  final String routeName;
  /// Values: 'On Time' | 'Delayed' | 'Breakdown'
  final String status;
  /// Web field: 'driver'
  final String? driverName;
  /// Web field: 'phone'
  final String? driverPhone;
  /// Web field: 'location.lat'
  final double latitude;
  /// Web field: 'location.lng'
  final double longitude;
  final double speed;
  /// Web field: 'lastGpsUpdate' (Firestore Timestamp)
  final DateTime? lastGpsUpdate;
  /// Web field: 'lastUpdate' (HH:MM string)
  final String lastUpdate;

  BusModel({
    required this.busId,
    required this.busNumber,
    required this.registrationNumber,
    required this.capacity,
    required this.headcount,
    required this.routeId,
    required this.routeName,
    required this.status,
    this.driverName,
    this.driverPhone,
    required this.latitude,
    required this.longitude,
    required this.speed,
    this.lastGpsUpdate,
    required this.lastUpdate,
  });

  factory BusModel.fromJson(Map<String, dynamic> json) {
    // Web stores location as nested map: { lat: ..., lng: ... }
    final locationMap = json['location'] as Map<String, dynamic>?;
    final lat = (locationMap?['lat'] as num?)?.toDouble() ?? 0.0;
    final lng = (locationMap?['lng'] as num?)?.toDouble() ?? 0.0;

    return BusModel(
      busId: json['id'] ?? json['busId'] ?? '',
      // Web field is 'number', not 'busNumber'
      busNumber: json['number'] ?? json['busNumber'] ?? '',
      // Web field is 'registrationNumber', not 'plateNumber'
      registrationNumber:
          json['registrationNumber'] ?? json['plateNumber'] ?? '',
      capacity: (json['capacity'] as num?)?.toInt() ?? 45,
      headcount: (json['headcount'] as num?)?.toInt() ?? 0,
      routeId: json['routeId'] ?? '',
      // Web field is 'route', not 'routeName'
      routeName: json['route'] ?? json['routeName'] ?? '',
      status: json['status'] ?? 'On Time',
      driverName: json['driver'] ?? json['driverName'],
      driverPhone: json['phone'] ?? json['driverPhone'],
      latitude: lat,
      longitude: lng,
      speed: (json['speed'] as num?)?.toDouble() ?? 0.0,
      lastGpsUpdate: (json['lastGpsUpdate'] as Timestamp?)?.toDate()
          ?? (json['updatedAt'] as Timestamp?)?.toDate(),
      lastUpdate: json['lastUpdate']?.toString() ?? '',
    );
  }

  /// GPS freshness check — mirrors web FleetMap.jsx getGpsStatus()
  String get gpsStatusLabel {
    if (latitude == 0.0 && longitude == 0.0) return 'NO_LOCATION';
    if (lastGpsUpdate == null) return 'LIVE';
    final diffMinutes =
        DateTime.now().difference(lastGpsUpdate!).inMinutes;
    if (diffMinutes < 3) return 'LIVE';
    if (diffMinutes <= 15) return 'STALE';
    return 'OFFLINE';
  }
}
