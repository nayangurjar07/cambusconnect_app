import 'package:cambus_connect_app/features/student/student_providers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─── Tenant Model ────────────────────────────────────────────────────────────

class TenantModel {
  final String id;
  final String name;
  final String domain;
  final String adminEmail;
  final String status;
  final String? firebaseProjectId;
  final DateTime? subscriptionEnd;
  final DateTime? registeredAt;

  TenantModel({
    required this.id,
    required this.name,
    required this.domain,
    required this.adminEmail,
    required this.status,
    this.firebaseProjectId,
    this.subscriptionEnd,
    this.registeredAt,
  });

  factory TenantModel.fromJson(Map<String, dynamic> json, String id) {
    return TenantModel(
      id: id,
      name: json['name'] ?? '',
      domain: json['domain'] ?? '',
      adminEmail: json['adminEmail'] ?? '',
      status: json['status'] ?? 'active',
      firebaseProjectId: json['projectId'] ?? json['firebaseProjectId'],
      subscriptionEnd: _parseDate(json['subscriptionEnd']),
      registeredAt: _parseDate(json['registeredAt'] ?? json['createdAt']),
    );
  }

  static DateTime? _parseDate(dynamic val) {
    if (val == null) return null;
    if (val is Timestamp) return val.toDate();
    if (val is String) return DateTime.tryParse(val);
    return null;
  }
}

// ─── Owner Stats ─────────────────────────────────────────────────────────────

class OwnerStats {
  final int totalTenants;
  final int activeTenants;
  final int suspendedTenants;

  OwnerStats({
    required this.totalTenants,
    required this.activeTenants,
    required this.suspendedTenants,
  });
}

// ─── Tenants Stream Provider ─────────────────────────────────────────────────

final tenantsProvider = StreamProvider<List<TenantModel>>((ref) {
  final firestore = ref.read(firestoreProvider);
  return firestore
      .collection('tenants')
      .orderBy('name')
      .snapshots()
      .map((snap) => snap.docs
          .map((doc) => TenantModel.fromJson(doc.data(), doc.id))
          .toList());
});

// ─── Owner Stats Provider ────────────────────────────────────────────────────

final ownerStatsProvider = FutureProvider<OwnerStats>((ref) async {
  final firestore = ref.read(firestoreProvider);

  final totalSnap = await firestore.collection('tenants').count().get();
  final activeSnap = await firestore
      .collection('tenants')
      .where('status', isEqualTo: 'active')
      .count()
      .get();
  final suspendedSnap = await firestore
      .collection('tenants')
      .where('status', isEqualTo: 'suspended')
      .count()
      .get();

  return OwnerStats(
    totalTenants: totalSnap.count ?? 0,
    activeTenants: activeSnap.count ?? 0,
    suspendedTenants: suspendedSnap.count ?? 0,
  );
});
