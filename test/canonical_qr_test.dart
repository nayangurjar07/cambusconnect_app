import 'package:cambus_connect_app/data/repositories/auth_repository.dart';
import 'package:cambus_connect_app/features/student/student_providers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Smart Enrollment Normalization', () {
    test('expands enrollment number to institutional email', () {
      expect(
        FirebaseAuthRepository.normalizeIdentifier('0818CS221001'),
        equals('0818cs221001@indoreinstitute.com'),
      );
    });

    test('expands admin keyword to institutional admin email', () {
      expect(
        FirebaseAuthRepository.normalizeIdentifier('admin'),
        equals('admin@indoreinstitute.com'),
      );
      expect(
        FirebaseAuthRepository.normalizeIdentifier('ADMIN'),
        equals('admin@indoreinstitute.com'),
      );
    });

    test('leaves existing email untouched except lowercasing and trimming', () {
      expect(
        FirebaseAuthRepository.normalizeIdentifier('  Student@IndoreInstitute.com  '),
        equals('student@indoreinstitute.com'),
      );
    });
  });

  group('Canonical Deterministic QR Payload', () {
    test('formats canonical QR string with assigned bus', () {
      final payload = generateCanonicalQrPayload(
        collegeId: '0818CS221001',
        assignedBusId: 'bus_14',
        date: DateTime(2026, 10, 31),
      );
      expect(payload, equals('CAMBUS:0818CS221001:bus_14:2026-10-31'));
    });

    test('formats canonical QR string with unassigned bus', () {
      final payload = generateCanonicalQrPayload(
        collegeId: '0818CS221001',
        assignedBusId: null,
        date: DateTime(2026, 10, 31),
      );
      expect(payload, equals('CAMBUS:0818CS221001:NA:2026-10-31'));

      final payload2 = generateCanonicalQrPayload(
        collegeId: '0818CS221001',
        assignedBusId: 'Not Assigned',
        date: DateTime(2026, 10, 31),
      );
      expect(payload2, equals('CAMBUS:0818CS221001:NA:2026-10-31'));
    });
  });
}
