import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String notificationId;
  final String title;
  final String message;
  final String type;
  final String targetAudience;
  final String? targetRouteId;
  final String? targetBusId;
  final String senderEmail;
  final DateTime createdAt;

  NotificationModel({
    required this.notificationId,
    required this.title,
    required this.message,
    required this.type,
    required this.targetAudience,
    this.targetRouteId,
    this.targetBusId,
    required this.senderEmail,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json, String id) {
    return NotificationModel(
      notificationId: id,
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      type: json['type'] ?? 'general',
      targetAudience: json['targetAudience'] ?? 'all',
      targetRouteId: json['targetRouteId'],
      targetBusId: json['targetBusId'],
      senderEmail: json['senderEmail'] ?? '',
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
