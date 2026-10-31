import 'dart:convert';
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

    // 1. Primary: lookup by email (doc ID) in /students — matches web structure
    final emailDoc =
        await firestore.collection('students').doc(user.email).get();
    if (emailDoc.exists) {
      return StudentModel.fromJson(emailDoc.data()!);
    }

    // 2. Fallback: query by 'email' field (for docs not keyed by email)
    final emailQuery = await firestore
        .collection('students')
        .where('email', isEqualTo: user.email)
        .limit(1)
        .get();
    if (emailQuery.docs.isNotEmpty) {
      return StudentModel.fromJson(emailQuery.docs.first.data());
    }

    // 3. Fallback: query by 'collegeId' field
    final idQuery = await firestore
        .collection('students')
        .where('collegeId', isEqualTo: user.email)
        .limit(1)
        .get();
    if (idQuery.docs.isNotEmpty) {
      return StudentModel.fromJson(idQuery.docs.first.data());
    }

    return null;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. Bus Pass Provider — TOTP-based, matching web crypto.js exactly
//
// Web TOTP algorithm (src/utils/crypto.js):
//   timeIndex = floor(Date.now() / 900_000)    [15-min window]
//   token = SHA-256("${qrSecret}:${timeIndex}")[0:16]  [first 16 hex chars]
//   QR payload = JSON: { email, totp: token, t: timeIndex }
//
// This Dart implementation mirrors that exactly so the admin scan pass
// on the web can verify tokens generated here.
// ─────────────────────────────────────────────────────────────────────────────

/// Generates the current TOTP token from [qrSecret].
/// Matches web crypto.js generateTotpPayload() exactly.
String _generateTotpToken(String qrSecret, {int windowOffset = 0}) {
  final timeIndex =
      DateTime.now().millisecondsSinceEpoch ~/ (15 * 60 * 1000) + windowOffset;
  final input = utf8.encode('$qrSecret:$timeIndex');
  final digest = sha256.convert(input).toString();
  return digest.substring(0, 16); // First 16 hex chars = 64 bits
}

/// Builds the full QR JSON payload for [email] using [qrSecret].
/// Matches web crypto.js generateTotpPayload() with optional studentId for legacy scanners.
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
/// Allows current + previous window (grace period for clock skew).
bool verifyTotp(String scannedTotp, String qrSecret) {
  if (scannedTotp.isEmpty || qrSecret.isEmpty) return false;
  final current = _generateTotpToken(qrSecret, windowOffset: 0);
  final previous = _generateTotpToken(qrSecret, windowOffset: -1);
  return scannedTotp == current || scannedTotp == previous;
}

/// Provides a [BusPassModel] derived from the student's Firestore profile.
/// The QR payload is TOTP-generated on-device — no Cloud Function required.
final studentPassProvider = Provider<AsyncValue<BusPassModel?>>((ref) {
  final studentProfile = ref.watch(studentProfileProvider);
  return studentProfile.whenData((student) {
    if (student == null) return null;
    return BusPassModel.fromStudent(student);
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// 3. Live Bus Tracking Provider
// Streams a single bus by Firestore document ID from /buses/{busId}.
// The student's assignedBusId comes from their /students profile.
// ─────────────────────────────────────────────────────────────────────────────
final studentAssignedBusIdProvider = Provider<String?>((ref) {
  final profile = ref.watch(studentProfileProvider).value;
  return profile?.assignedBusId;
});

final liveBusTrackingProvider =
    StreamProvider.family.autoDispose<BusModel?, String>((ref, busId) {
  if (busId.isEmpty) return Stream.value(null);
  final firestore = ref.read(firestoreProvider);
  return firestore.collection('buses').doc(busId).snapshots().map((doc) {
    if (!doc.exists) return null;
    // Pass doc.id as 'id' so BusModel.fromJson can use it
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
// Matches web communications.js subscribeToNotifications() exactly:
//   collection: 'notifications', ordered by createdAt desc, limit 20.
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
// Collection: 'lost-items' (exact web name from communications.js)
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
      createdAt:
          (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

final lostItemsProvider = StreamProvider.autoDispose<List<LostItem>>((ref) {
  final firestore = ref.read(firestoreProvider);
  return firestore
      .collection('lost-items') // exact web collection name
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snap) => snap.docs
          .map((doc) => LostItem.fromJson(doc.data(), doc.id))
          .toList());
});
