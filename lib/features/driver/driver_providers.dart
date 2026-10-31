import 'package:cambus_connect_app/data/models/bus_model.dart';
import 'package:cambus_connect_app/features/auth/auth_controller.dart';
import 'package:cambus_connect_app/features/student/student_providers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─── Driver Profile Model ────────────────────────────────────────────────────

class DriverProfile {
  final String email;
  final String name;
  final String? assignedBusId;
  final String? assignedBusNumber;
  final String? assignedRoute;
  final String collegeName;

  DriverProfile({
    required this.email,
    required this.name,
    this.assignedBusId,
    this.assignedBusNumber,
    this.assignedRoute,
    this.collegeName = 'Cambus Connect',
  });

  factory DriverProfile.fromJson(Map<String, dynamic> json) {
    return DriverProfile(
      email: json['email'] ?? '',
      name: json['name'] ?? '',
      assignedBusId: json['assignedBusId'],
      assignedBusNumber: json['assignedBusNumber'] ?? json['busNumber'],
      assignedRoute: json['assignedRoute'] ?? json['route'],
      collegeName: json['collegeName'] ?? json['college'] ?? 'Cambus Connect',
    );
  }
}

// ─── Driver Profile Provider ─────────────────────────────────────────────────

final driverProfileProvider = FutureProvider<DriverProfile?>((ref) async {
  final user = ref.watch(authControllerProvider).value;
  if (user == null) return null;

  final firestore = ref.read(firestoreProvider);

  // Try by email document first (matches web portal structure)
  final doc = await firestore.collection('users').doc(user.email).get();
  if (doc.exists) {
    return DriverProfile.fromJson(doc.data()!);
  }

  // Fallback: query by email field
  final query = await firestore
      .collection('users')
      .where('email', isEqualTo: user.email)
      .limit(1)
      .get();

  if (query.docs.isNotEmpty) {
    return DriverProfile.fromJson(query.docs.first.data());
  }

  // Return a basic profile from auth data
  return DriverProfile(email: user.email, name: user.name);
});

// ─── Assigned Bus Provider ───────────────────────────────────────────────────

final driverAssignedBusProvider = StreamProvider.autoDispose<BusModel?>((ref) {
  final driverProfile = ref.watch(driverProfileProvider).value;
  if (driverProfile == null || driverProfile.assignedBusId == null) {
    return Stream.value(null);
  }

  final firestore = ref.read(firestoreProvider);
  return firestore
      .collection('buses')
      .doc(driverProfile.assignedBusId)
      .snapshots()
      .map((doc) => doc.exists ? BusModel.fromJson(doc.data()!) : null);
});

// ─── All Buses List for Driver Selection ─────────────────────────────────────

final allBusesProvider = StreamProvider.autoDispose<List<BusModel>>((ref) {
  final firestore = ref.read(firestoreProvider);
  return firestore.collection('buses').snapshots().map((snapshot) =>
      snapshot.docs.map((doc) => BusModel.fromJson(doc.data())).toList());
});

// ─── Driver Shift History ────────────────────────────────────────────────────

class ShiftRecord {
  final String sessionId;
  final DateTime startTime;
  final DateTime? endTime;
  final String busNumber;
  final String route;

  ShiftRecord({
    required this.sessionId,
    required this.startTime,
    this.endTime,
    required this.busNumber,
    required this.route,
  });

  factory ShiftRecord.fromJson(Map<String, dynamic> json, String id) {
    return ShiftRecord(
      sessionId: id,
      startTime: (json['startTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endTime: (json['endTime'] as Timestamp?)?.toDate(),
      busNumber: json['busNumber'] ?? '',
      route: json['route'] ?? '',
    );
  }
}

final driverShiftHistoryProvider =
    StreamProvider.autoDispose<List<ShiftRecord>>((ref) {
  final user = ref.watch(authControllerProvider).value;
  if (user == null) return Stream.value([]);

  final firestore = ref.read(firestoreProvider);
  // Web app writes sessions to 'driverSessions' (not 'shiftSessions')
  return firestore
      .collection('driverSessions')
      .where('driverEmail', isEqualTo: user.email)
      .orderBy('startTime', descending: true)
      .limit(10)
      .snapshots()
      .map((snap) => snap.docs
          .map((doc) => ShiftRecord.fromJson(doc.data(), doc.id))
          .toList());
});
