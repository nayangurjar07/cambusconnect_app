import 'package:cambus_connect_app/core/firestore_parsers.dart';
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
  /// Web field: 'lastGpsUpdate' (Firestore Timestamp or ISO Date string)
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
    double lat = 0.0;
    double lng = 0.0;

    // Check nested location map or currentLocation GeoPoint/Map
    if (json['location'] is Map) {
      final loc = json['location'] as Map;
      lat = FirestoreParsers.parseCoord(loc['lat'] ?? loc['latitude']);
      lng = FirestoreParsers.parseCoord(loc['lng'] ?? loc['longitude']);
    } else if (json['currentLocation'] is GeoPoint) {
      final gp = json['currentLocation'] as GeoPoint;
      lat = gp.latitude;
      lng = gp.longitude;
    } else if (json['currentLocation'] is Map) {
      final loc = json['currentLocation'] as Map;
      lat = FirestoreParsers.parseCoord(loc['latitude'] ?? loc['lat']);
      lng = FirestoreParsers.parseCoord(loc['longitude'] ?? loc['lng']);
    } else {
      lat = FirestoreParsers.parseCoord(json['latitude'] ?? json['lat']);
      lng = FirestoreParsers.parseCoord(json['longitude'] ?? json['lng']);
    }

    final parsedSpeed = (json['speed'] as num?)?.toDouble() ??
        FirestoreParsers.parseCoord(json['speed'], 0.0);

    return BusModel(
      busId: json['id']?.toString() ?? json['busId']?.toString() ?? '',
      // Web field is 'number', not 'busNumber'
      busNumber: json['number']?.toString() ?? json['busNumber']?.toString() ?? '',
      // Web field is 'registrationNumber', not 'plateNumber'
      registrationNumber:
          json['registrationNumber']?.toString() ?? json['plateNumber']?.toString() ?? '',
      capacity: (json['capacity'] as num?)?.toInt() ?? 45,
      headcount: (json['headcount'] as num?)?.toInt() ?? 0,
      routeId: json['routeId']?.toString() ?? '',
      // Web field is 'route', not 'routeName'
      routeName: json['route']?.toString() ?? json['routeName']?.toString() ?? 'Unassigned Route',
      status: json['status']?.toString() ?? 'On Time',
      driverName: json['driver']?.toString() ?? json['driverName']?.toString(),
      driverPhone: json['phone']?.toString() ?? json['driverPhone']?.toString(),
      latitude: lat,
      longitude: lng,
      speed: parsedSpeed,
      lastGpsUpdate: FirestoreParsers.parseDate(json['lastGpsUpdate'] ?? json['updatedAt']),
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
