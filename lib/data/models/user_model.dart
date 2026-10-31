import 'package:cambus_connect_app/core/firestore_parsers.dart';

enum UserRole { student, admin, driver, owner, unknown }

class UserModel {
  final String uid;
  final String email;
  final String name;
  final UserRole role;
  // Denormalized student fields
  final String branch;
  final String year;
  final String passStatus;
  final DateTime? validityDate;
  final String assignedBusId;
  final String busRoute;
  final String? collegeId;

  UserModel({
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
    this.branch = '',
    this.year = '',
    this.passStatus = '',
    this.validityDate,
    this.assignedBusId = '',
    this.busRoute = 'Not Assigned',
    this.collegeId,
  });

  factory UserModel.fromJson(Map<String, dynamic> json, String uid) {
    return UserModel(
      uid: uid,
      email: json['email'] ?? '',
      name: json['name'] ?? '',
      role: parseRole(json['role']),
      branch: json['branch'] ?? '',
      year: json['year'] ?? '',
      passStatus: json['status'] ?? json['passStatus'] ?? 'pending',
      validityDate: FirestoreParsers.parseDate(json['validityDate'] ?? json['passValidity']),
      assignedBusId: json['assignedBusId'] ?? '',
      busRoute: json['busRoute'] ?? json['assignedRoute'] ?? 'Not Assigned',
      collegeId: json['collegeId'] ?? json['enrollment'] ?? json['studentId'],
    );
  }

  bool get isPassActive => FirestoreParsers.isPassActive(validityDate);

  static UserRole parseRole(String? roleStr) {
    switch (roleStr?.toLowerCase()) {
      case 'student':
        return UserRole.student;
      case 'admin':
        return UserRole.admin;
      case 'driver':
        return UserRole.driver;
      case 'owner':
        return UserRole.owner;
      default:
        return UserRole.unknown;
    }
  }
}
