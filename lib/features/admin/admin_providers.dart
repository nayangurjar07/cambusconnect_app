import 'package:cambus_connect_app/data/models/student_model.dart';
import 'package:cambus_connect_app/features/student/student_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─── Admin Stats ─────────────────────────────────────────────────────────────

class AdminStats {
  final int totalStudents;
  final int activePasses;
  final int totalBuses;
  final int totalNotifications;

  const AdminStats({
    required this.totalStudents,
    required this.activePasses,
    required this.totalBuses,
    required this.totalNotifications,
  });
}

/// All stats read from the correct collections that the web app uses.
final adminStatsProvider = FutureProvider<AdminStats>((ref) async {
  final firestore = ref.read(firestoreProvider);

  // Students are in /students — NOT /users (which holds staff/admins/drivers)
  final studentCountSnap = await firestore
      .collection('students')
      .count()
      .get();

  // Active passes: students with status='Active' (web field is 'status', not 'passStatus')
  final activePassSnap = await firestore
      .collection('students')
      .where('status', isEqualTo: 'Active')
      .count()
      .get();

  final busCountSnap = await firestore.collection('buses').count().get();

  final notifCountSnap =
      await firestore.collection('notifications').count().get();

  return AdminStats(
    totalStudents: studentCountSnap.count ?? 0,
    activePasses: activePassSnap.count ?? 0,
    totalBuses: busCountSnap.count ?? 0,
    totalNotifications: notifCountSnap.count ?? 0,
  );
});

// ─── All Students Stream ─────────────────────────────────────────────────────

/// Streams the /students collection (web app's canonical student store).
/// Web uses email as document ID and stores: name, email, collegeId, busRoute,
/// status, passValidity, qrSecret, assignedBusId, etc.
final allStudentsProvider =
    StreamProvider.autoDispose<List<StudentModel>>((ref) {
  final firestore = ref.read(firestoreProvider);
  return firestore
      .collection('students') // ← correct collection (NOT /users)
      .orderBy('name')
      .limit(100)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => StudentModel.fromJson(doc.data()))
          .toList());
});

// ─── Notifications Stream ────────────────────────────────────────────────────

class NotifModel {
  final String id;
  final String title;
  final String message;
  final String type;
  final String targetRouteId;
  final DateTime createdAt;

  const NotifModel({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.targetRouteId,
    required this.createdAt,
  });

  factory NotifModel.fromJson(Map<String, dynamic> json, String id) {
    return NotifModel(
      id: id,
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      type: json['type'] ?? 'info',
      targetRouteId: json['targetRouteId'] ?? 'all',
      createdAt: (json['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
    );
  }
}

final adminNotificationsProvider =
    StreamProvider.autoDispose<List<NotifModel>>((ref) {
  final firestore = ref.read(firestoreProvider);
  return firestore
      .collection('notifications')
      .orderBy('createdAt', descending: true)
      .limit(20)
      .snapshots()
      .map((snap) => snap.docs
          .map((doc) => NotifModel.fromJson(doc.data(), doc.id))
          .toList());
});

// ─── Support Queries Stream ──────────────────────────────────────────────────

class SupportQuery {
  final String id;
  final String studentName;
  final String studentEmail;
  final String subject;
  final String message;
  final String status;
  final String category;
  final DateTime createdAt;

  const SupportQuery({
    required this.id,
    required this.studentName,
    required this.studentEmail,
    required this.subject,
    required this.message,
    required this.status,
    required this.category,
    required this.createdAt,
  });

  factory SupportQuery.fromJson(Map<String, dynamic> json, String id) {
    return SupportQuery(
      id: id,
      studentName: json['studentName'] ?? '',
      studentEmail: json['studentEmail'] ?? '',
      subject: json['subject'] ?? '',
      message: json['message'] ?? '',
      status: json['status'] ?? 'Pending',
      category: json['category'] ?? 'General Inquiry',
      createdAt: (json['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
    );
  }
}

final adminSupportQueriesProvider =
    StreamProvider.autoDispose<List<SupportQuery>>((ref) {
  final firestore = ref.read(firestoreProvider);
  return firestore
      .collection('support-queries') // exact web collection name
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots()
      .map((snap) => snap.docs
          .map((doc) => SupportQuery.fromJson(doc.data(), doc.id))
          .toList());
});
