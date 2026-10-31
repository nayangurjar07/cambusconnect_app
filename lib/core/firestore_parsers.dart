import 'package:cloud_firestore/cloud_firestore.dart';

/// Defensive utility to safely parse heterogeneous data formats coming
/// from Firestore (Web SaaS strings, Firebase Timestamps, unix millis, etc.)
class FirestoreParsers {
  FirestoreParsers._();

  /// Parse dates from String (ISO-8601 YYYY-MM-DD or full), Timestamp, int, or DateTime.
  static DateTime? parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is int) {
      // Could be milliseconds or seconds
      if (value < 10000000000) {
        return DateTime.fromMillisecondsSinceEpoch(value * 1000);
      }
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    if (value is String) {
      final clean = value.trim();
      if (clean.isEmpty) return null;

      final parsed = DateTime.tryParse(clean);
      if (parsed != null) return parsed;

      // Handle standard "YYYY-MM-DD" or "DD-MM-YYYY" fallback formats
      final dashParts = clean.split('-');
      if (dashParts.length == 3) {
        if (dashParts[0].length == 4) {
          // YYYY-MM-DD
          final y = int.tryParse(dashParts[0]);
          final m = int.tryParse(dashParts[1]);
          final d = int.tryParse(dashParts[2]);
          if (y != null && m != null && d != null) {
            return DateTime(y, m, d);
          }
        } else if (dashParts[2].length == 4) {
          // DD-MM-YYYY
          final d = int.tryParse(dashParts[0]);
          final m = int.tryParse(dashParts[1]);
          final y = int.tryParse(dashParts[2]);
          if (y != null && m != null && d != null) {
            return DateTime(y, m, d);
          }
        }
      }
    }
    return null;
  }

  /// Parses geographic coordinates from double, int, or dirty strings
  /// (e.g. "22.7196° N", "75.8577 deg", "22.7196").
  static double parseCoord(dynamic value, [double fallback = 0.0]) {
    if (value == null) return fallback;
    if (value is num) return value.toDouble();
    if (value is String) {
      final clean = value.trim();
      if (clean.isEmpty) return fallback;

      final match = RegExp(r'[-+]?[0-9]*\.?[0-9]+').firstMatch(clean);
      if (match != null) {
        final parsed = double.tryParse(match.group(0)!);
        if (parsed != null) {
          final isNegative = clean.toUpperCase().contains('S') || clean.toUpperCase().contains('W');
          return isNegative ? -parsed.abs() : parsed;
        }
      }
    }
    return fallback;
  }

  /// Returns canonical ISO "YYYY-MM-DD" string.
  static String toIsoDateString(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  /// Evaluates pass validity against end of day (23:59:59.999).
  /// Prevents premature morning lockouts when validity is "YYYY-MM-DD".
  static bool isPassActive(dynamic validityDate) {
    final date = parseDate(validityDate);
    if (date == null) return false;

    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
    final now = DateTime.now();
    return now.isBefore(endOfDay) || now.isAtSameMomentAs(endOfDay);
  }
}
