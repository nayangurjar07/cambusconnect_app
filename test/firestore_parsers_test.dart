import 'package:cambus_connect_app/core/firestore_parsers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FirestoreParsers - Date Parsing', () {
    test('parses ISO-8601 string correctly', () {
      final date = FirestoreParsers.parseDate('2026-10-31');
      expect(date, isNotNull);
      expect(date!.year, equals(2026));
      expect(date.month, equals(10));
      expect(date.day, equals(31));
    });

    test('parses DD-MM-YYYY string correctly', () {
      final date = FirestoreParsers.parseDate('31-10-2026');
      expect(date, isNotNull);
      expect(date!.year, equals(2026));
      expect(date.month, equals(10));
      expect(date.day, equals(31));
    });

    test('parses Timestamp correctly', () {
      final ts = Timestamp.fromDate(DateTime(2026, 12, 25));
      final date = FirestoreParsers.parseDate(ts);
      expect(date, equals(DateTime(2026, 12, 25)));
    });

    test('parses int epoch millis correctly', () {
      final target = DateTime(2026, 5, 1, 10, 0, 0);
      final millis = target.millisecondsSinceEpoch;
      final date = FirestoreParsers.parseDate(millis);
      expect(date, equals(target));
    });

    test('returns null for empty or null inputs', () {
      expect(FirestoreParsers.parseDate(null), isNull);
      expect(FirestoreParsers.parseDate(''), isNull);
      expect(FirestoreParsers.parseDate('   '), isNull);
      expect(FirestoreParsers.parseDate('invalid-date'), isNull);
    });
  });

  group('FirestoreParsers - Coordinate Parsing', () {
    test('parses num and double accurately', () {
      expect(FirestoreParsers.parseCoord(22.7196), equals(22.7196));
      expect(FirestoreParsers.parseCoord(75), equals(75.0));
    });

    test('extracts coordinates from Web Admin string with degree symbols', () {
      expect(FirestoreParsers.parseCoord('22.7196° N'), closeTo(22.7196, 0.0001));
      expect(FirestoreParsers.parseCoord('75.8577 deg'), closeTo(75.8577, 0.0001));
    });

    test('handles negative coordinates from S or W directions', () {
      expect(FirestoreParsers.parseCoord('33.8688° S'), closeTo(-33.8688, 0.0001));
      expect(FirestoreParsers.parseCoord('151.2093° W'), closeTo(-151.2093, 0.0001));
    });

    test('returns fallback for null or empty strings', () {
      expect(FirestoreParsers.parseCoord(null, 10.0), equals(10.0));
      expect(FirestoreParsers.parseCoord('', 0.0), equals(0.0));
    });
  });

  group('FirestoreParsers - Pass Validity & Formatting', () {
    test('toIsoDateString produces standardized YYYY-MM-DD', () {
      final dt = DateTime(2026, 7, 4);
      expect(FirestoreParsers.toIsoDateString(dt), equals('2026-07-04'));
    });

    test('isPassActive returns true for today through 23:59:59', () {
      final now = DateTime.now();
      expect(FirestoreParsers.isPassActive(now), isTrue);
      final todayIso = FirestoreParsers.toIsoDateString(now);
      expect(FirestoreParsers.isPassActive(todayIso), isTrue);
    });

    test('isPassActive returns false for yesterday', () {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final yesterdayIso = FirestoreParsers.toIsoDateString(yesterday);
      expect(FirestoreParsers.isPassActive(yesterdayIso), isFalse);
    });

    test('isPassActive returns true for future date', () {
      final future = DateTime.now().add(const Duration(days: 30));
      expect(FirestoreParsers.isPassActive(future), isTrue);
    });
  });
}
