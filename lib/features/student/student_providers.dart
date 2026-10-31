import 'dart:convert';
import 'package:cambus_connect_app/core/firestore_parsers.dart';
import 'package:cambus_connect_app/data/models/bus_model.dart';
import 'package:cambus_connect_app/data/models/notification_model.dart';
import 'package:cambus_connect_app/data/models/student_model.dart';
import 'package:cambus_connect_app/features/auth/auth_controller.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

// ─────────────────────────────────────────────────────────────────────────────
// 1. Student Profile Provider
// Web portal stores students in /students/{email} (email as document ID).
// ─────────────────────────────────────────────────────────────────────────────
final studentProfileProvider =
    AsyncNotifierProvider<StudentProfileNotifier, StudentModel?>(() {
  return StudentProfileNotifier();
});

class StudentProfileNotifier extends AsyncNotifier<StudentModel?> {
  @override
  Future<StudentModel?> build() async {
    final user = ref.watch(authControllerProvider).value;
    if (user == null) return null;

    final firestore = ref.read(firestoreProvider);
    final cleanEmail = user.email.toLowerCase().trim();

    // 1. Primary: lookup by lowercase email (doc ID) in /students
    final emailDoc =
        await firestore.collection('students').doc(cleanEmail).get();
    if (emailDoc.exists) {
      return StudentModel.fromJson(emailDoc.data()!);
    }

    // 2. Fallback: query by 'email' field
    final emailQuery = await firestore
        .collection('students')
        .where('email', isEqualTo: cleanEmail)
        .limit(1)
        .get();
    if (emailQuery.docs.isNotEmpty) {
      return StudentModel.fromJson(emailQuery.docs.first.data());
    }

    // 3. Fallback: query by 'collegeId' field
    final idQuery = await firestore
        .collection('students')
        .where('collegeId', isEqualTo: cleanEmail)
        .limit(1)
        .get();
    if (idQuery.docs.isNotEmpty) {
      return StudentModel.fromJson(idQuery.docs.first.data());
    }

    return null;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. Bus Pass Provider — Canonical format & TOTP backward compatibility
// ─────────────────────────────────────────────────────────────────────────────

/// Generates the canonical deterministic QR payload:
/// Format: CAMBUS:{collegeId}:{assignedBusId}:{todayIso}
String generateCanonicalQrPayload({
  required String collegeId,
  required String? assignedBusId,
  DateTime? date,
}) {
  final cleanId = collegeId.trim().isNotEmpty ? collegeId.trim() : 'UNKNOWN';
  final bus = (assignedBusId != null &&
          assignedBusId.trim().isNotEmpty &&
          assignedBusId.trim().toLowerCase() != 'not assigned')
      ? assignedBusId.trim()
      : 'NA';
  final todayIso = FirestoreParsers.toIsoDateString(date ?? DateTime.now());
  return 'CAMBUS:$cleanId:$bus:$todayIso';
}

/// Generates the current TOTP token from [qrSecret].
/// Matches web crypto.js generateTotpPayload() exactly.
String _generateTotpToken(String qrSecret, {int windowOffset = 0}) {
  final timeIndex =
      DateTime.now().millisecondsSinceEpoch ~/ (15 * 60 * 1000) + windowOffset;
  final input = utf8.encode('$qrSecret:$timeIndex');
  final digest = sha256.convert(input).toString();
  return digest.substring(0, 16); // First 16 hex chars
}

/// Builds the full QR JSON payload for [email] using [qrSecret].
String generateQrPayload(String email, String qrSecret, {String? studentId}) {
  final timeIndex =
      DateTime.now().millisecondsSinceEpoch ~/ (15 * 60 * 1000);
  final token = _generateTotpToken(qrSecret);
  return jsonEncode({
    'email': email,
    if (studentId != null && studentId.isNotEmpty) 'studentId': studentId,
    'totp': token,
    't': timeIndex,
  });
}

/// Verifies a scanned TOTP token against a student's [qrSecret].
bool verifyTotp(String scannedTotp, String qrSecret) {
  if (scannedTotp.isEmpty || qrSecret.isEmpty) return false;
  final current = _generateTotpToken(qrSecret, windowOffset: 0);
  final previous = _generateTotpToken(qrSecret, windowOffset: -1);
  return scannedTotp == current || scannedTotp == previous;
}

final studentPassProvider = Provider<AsyncValue<BusPassModel?>>((ref) {
  final studentProfile = ref.watch(studentProfileProvider);
  return studentProfile.whenData((student) {
    if (student == null) return null;
    return BusPassModel.fromStudent(student);
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// 3. Live Bus Tracking Provider
// ─────────────────────────────────────────────────────────────────────────────
final studentAssignedBusIdProvider = Provider<String?>((ref) {
  final profile = ref.watch(studentProfileProvider).value;
  return profile?.assignedBusId;
});

final liveBusTrackingProvider =
    StreamProvider.family.autoDispose<BusModel?, String>((ref, busId) {
  final cleanId = busId.trim();
  if (cleanId.isEmpty || cleanId.toLowerCase() == 'not assigned') {
    return Stream.value(null);
  }
  final firestore = ref.read(firestoreProvider);
  return firestore.collection('buses').doc(cleanId).snapshots().map((doc) {
    if (!doc.exists) return null;
    final data = {'id': doc.id, ...doc.data()!};
    return BusModel.fromJson(data);
  });
});

/// Streams ALL buses — used by the fleet tracking map.
final allBusesStreamProvider =
    StreamProvider.autoDispose<List<BusModel>>((ref) {
  final firestore = ref.read(firestoreProvider);
  return firestore.collection('buses').snapshots().map((snap) => snap.docs
      .map((doc) => BusModel.fromJson({'id': doc.id, ...doc.data()}))
      .toList());
});

// ─────────────────────────────────────────────────────────────────────────────
// 4. Student Notifications Provider
// ─────────────────────────────────────────────────────────────────────────────
final studentNotificationsProvider =
    StreamProvider.autoDispose<List<NotificationModel>>((ref) {
  final firestore = ref.read(firestoreProvider);
  return firestore
      .collection('notifications')
      .orderBy('createdAt', descending: true)
      .limit(20)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => NotificationModel.fromJson(doc.data(), doc.id))
          .toList());
});

// ─────────────────────────────────────────────────────────────────────────────
// 5. Lost & Found Items Provider
// ─────────────────────────────────────────────────────────────────────────────
class LostItem {
  final String id;
  final String title;
  final String description;
  final String locationType; // 'BUS' | 'CAMPUS'
  final String location;
  final String status; // 'Lost' | 'Found' | 'Claimed'
  final String contactName;
  final String contactEmail;
  final String contactPhone;
  final DateTime createdAt;

  const LostItem({
    required this.id,
    required this.title,
    required this.description,
    required this.locationType,
    required this.location,
    required this.status,
    required this.contactName,
    required this.contactEmail,
    required this.contactPhone,
    required this.createdAt,
  });

  factory LostItem.fromJson(Map<String, dynamic> json, String id) {
    return LostItem(
      id: id,
      title: json['title'] ?? json['itemName'] ?? json['item'] ?? '',
      description: json['description'] ?? '',
      locationType: json['locationType'] ?? 'BUS',
      location: json['location'] ??
          json['busNumber'] ??
          json['campusLocation'] ??
          '',
      status: json['status'] ?? 'Lost',
      contactName: json['contactName'] ?? json['userName'] ?? json['reportedBy'] ?? '',
      contactEmail: json['contactEmail'] ?? json['userEmail'] ?? '',
      contactPhone: json['contactPhone'] ?? json['userPhone'] ?? '',
      createdAt: FirestoreParsers.parseDate(json['createdAt']) ?? DateTime.now(),
    );
  }
}

final lostItemsProvider = StreamProvider.autoDispose<List<LostItem>>((ref) {
  final firestore = ref.read(firestoreProvider);
  return firestore
      .collection('lost-items')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snap) => snap.docs
          .map((doc) => LostItem.fromJson(doc.data(), doc.id))
          .toList());
});
