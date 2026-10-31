import 'package:cloud_firestore/cloud_firestore.dart';

/// Matches the exact Firestore schema written by the web app (src/services/students.js).
///
/// Web collection: /students/{email}  (email as document ID)
/// Key web fields: name, email, collegeId, enrollment, phone, parentPhone,
///   busRoute, routeId, assignedBusId, assignedBusNumber, pickupStop,
///   passValidity (ISO date string), qrSecret (32-char hex), status.
class StudentModel {
  final String name;
  final String email;

  /// Web field: 'collegeId' (enrollment/roll number)
  final String collegeId;

  /// Web field: 'enrollment' (alias for collegeId — both may exist)
  final String enrollment;

  final String phone;

  /// Web field: 'parentPhone'
  final String parentPhone;

  /// Web field: 'busRoute' (route name like "Route A")
  final String busRoute;

  /// Web field: 'routeId'
  final String? routeId;

  /// Web field: 'assignedBusId'
  final String? assignedBusId;

  /// Web field: 'assignedBusNumber'
  final String? assignedBusNumber;

  /// Web field: 'pickupStop'
  final String? pickupStop;

  /// Web field: 'passValidity' (ISO date string 'YYYY-MM-DD')
  final DateTime passValidity;

  /// Web field: 'qrSecret' — 32-char hex cryptographic secret for TOTP generation.
  /// The QR token is SHA-256(qrSecret:timeWindowIndex)[0:16], rotating every 15 min.
  final String? qrSecret;

  /// Web field: 'status' ('Active' | 'Inactive' | 'Revoked')
  final String status;

  // Legacy / auxiliary fields
  final String? branch;
  final String? year;

  StudentModel({
    required this.name,
    required this.email,
    required this.collegeId,
    required this.enrollment,
    required this.phone,
    required this.parentPhone,
    required this.busRoute,
    this.routeId,
    this.assignedBusId,
    this.assignedBusNumber,
    this.pickupStop,
    required this.passValidity,
    this.qrSecret,
    required this.status,
    this.branch,
    this.year,
  });

  factory StudentModel.fromJson(Map<String, dynamic> json) {
    // passValidity: web stores as ISO string ('2026-12-31') OR Firestore Timestamp
    DateTime parsedValidity;
    final rawValidity = json['passValidity'];
    if (rawValidity is Timestamp) {
      parsedValidity = rawValidity.toDate();
    } else if (rawValidity is String) {
      parsedValidity = DateTime.tryParse(rawValidity) ?? DateTime.now().add(const Duration(days: 30));
    } else {
      parsedValidity = DateTime.now().add(const Duration(days: 30));
    }

    return StudentModel(
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      // Web uses 'collegeId'
      collegeId: json['collegeId'] ?? json['enrollment'] ?? json['studentId'] ?? '',
      enrollment: json['enrollment'] ?? json['collegeId'] ?? json['studentId'] ?? '',
      phone: json['phone'] ?? '',
      parentPhone: json['parentPhone'] ?? json['emergencyPhone'] ?? '',
      // Web uses 'busRoute' for route name
      busRoute: json['busRoute'] ?? json['assignedRoute'] ?? '',
      routeId: json['routeId'],
      assignedBusId: json['assignedBusId'],
      // Web uses 'assignedBusNumber'
      assignedBusNumber: json['assignedBusNumber'] ?? json['busNumber'],
      // Web uses 'pickupStop'
      pickupStop: json['pickupStop'] ?? json['boardingStop'],
      passValidity: parsedValidity,
      // Web field 'qrSecret' — the TOTP cryptographic secret
      qrSecret: json['qrSecret'],
      // Web uses 'status' (not 'passStatus')
      status: json['status'] ?? json['passStatus'] ?? 'Active',
      branch: json['branch'],
      year: json['year'],
    );
  }

  bool get isActive => status.toLowerCase() == 'active';
  bool get isExpired => passValidity.isBefore(DateTime.now());
  bool get isValid => isActive && !isExpired;
}

/// Derived view-model for the bus pass screen.
class BusPassModel {
  final String studentName;
  final String email;
  /// Display ID: collegeId (enrollment number)
  final String displayId;
  final String? branch;
  final String? assignedRoute;
  final String? boardingStop;
  final String status;
  final DateTime passValidity;
  /// The TOTP cryptographic secret — rotating every 15 min.
  final String? qrSecret;

  BusPassModel({
    required this.studentName,
    required this.email,
    required this.displayId,
    this.branch,
    this.assignedRoute,
    this.boardingStop,
    required this.status,
    required this.passValidity,
    this.qrSecret,
  });

  factory BusPassModel.fromStudent(StudentModel s) {
    return BusPassModel(
      studentName: s.name,
      email: s.email,
      displayId: s.collegeId.isNotEmpty ? s.collegeId : s.email,
      branch: s.branch,
      assignedRoute: s.busRoute.isNotEmpty ? s.busRoute : null,
      boardingStop: s.pickupStop,
      status: s.status,
      passValidity: s.passValidity,
      qrSecret: s.qrSecret,
    );
  }

  bool get isValid =>
      status.toLowerCase() == 'active' && !passValidity.isBefore(DateTime.now());
}
