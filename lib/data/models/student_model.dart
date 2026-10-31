import 'package:cambus_connect_app/core/firestore_parsers.dart';

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

  /// Web field: 'passValidity' (ISO date string 'YYYY-MM-DD' or Timestamp)
  final DateTime passValidity;

  /// Web field: 'qrSecret' — 32-char hex cryptographic secret for TOTP generation.
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
    final parsedValidity = FirestoreParsers.parseDate(json['passValidity']) ??
        DateTime.now().add(const Duration(days: 30));

    final parsedCollegeId = json['collegeId']?.toString().trim() ??
        json['enrollment']?.toString().trim() ??
        json['studentId']?.toString().trim() ??
        '';

    final parsedEnrollment = json['enrollment']?.toString().trim() ??
        parsedCollegeId;

    return StudentModel(
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      collegeId: parsedCollegeId,
      enrollment: parsedEnrollment,
      phone: json['phone']?.toString() ?? '',
      parentPhone: json['parentPhone']?.toString() ?? json['emergencyPhone']?.toString() ?? '',
      busRoute: json['busRoute']?.toString() ?? json['assignedRoute']?.toString() ?? 'Not Assigned',
      routeId: json['routeId']?.toString(),
      assignedBusId: json['assignedBusId']?.toString(),
      assignedBusNumber: json['assignedBusNumber']?.toString() ?? json['busNumber']?.toString(),
      pickupStop: json['pickupStop']?.toString() ?? json['boardingStop']?.toString(),
      passValidity: parsedValidity,
      qrSecret: json['qrSecret']?.toString(),
      status: json['status']?.toString() ?? json['passStatus']?.toString() ?? 'Active',
      branch: json['branch']?.toString(),
      year: json['year']?.toString(),
    );
  }

  bool get isActive => status.toLowerCase() == 'active';
  bool get isExpired => !FirestoreParsers.isPassActive(passValidity);
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
      assignedRoute: s.busRoute.isNotEmpty && s.busRoute != 'Not Assigned' ? s.busRoute : null,
      boardingStop: s.pickupStop,
      status: s.status,
      passValidity: s.passValidity,
      qrSecret: s.qrSecret,
    );
  }

  bool get isValid =>
      status.toLowerCase() == 'active' && FirestoreParsers.isPassActive(passValidity);
}
