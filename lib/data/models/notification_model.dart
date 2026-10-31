import 'package:cambus_connect_app/core/firestore_parsers.dart';

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
      title: json['title']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      type: json['type']?.toString() ?? 'general',
      targetAudience: json['targetAudience']?.toString() ?? 'all',
      targetRouteId: json['targetRouteId']?.toString(),
      targetBusId: json['targetBusId']?.toString(),
      senderEmail: json['senderEmail']?.toString() ?? '',
      createdAt: FirestoreParsers.parseDate(json['createdAt']) ?? DateTime.now(),
    );
  }
}
