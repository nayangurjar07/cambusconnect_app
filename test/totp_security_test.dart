import 'dart:convert';
import 'package:cambus_connect_app/features/student/student_providers.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TOTP & QR Security Protocol', () {
    const testEmail = 'student@campus.edu';
    const testSecret = '0123456789abcdef0123456789abcdef';
    const testStudentId = '0827CS211045';

    test('generateQrPayload emits valid JSON with expected keys', () {
      final payloadStr = generateQrPayload(
        testEmail,
        testSecret,
        studentId: testStudentId,
      );

      final payload = jsonDecode(payloadStr) as Map<String, dynamic>;
      expect(payload['email'], equals(testEmail));
      expect(payload['studentId'], equals(testStudentId));
      expect(payload['totp'], isA<String>());
      expect((payload['totp'] as String).length, equals(16)); // 16 hex chars
      expect(payload['t'], isA<int>());
    });

    test('verifyTotp succeeds for valid current window token', () {
      final payloadStr = generateQrPayload(testEmail, testSecret);
      final payload = jsonDecode(payloadStr) as Map<String, dynamic>;
      final token = payload['totp'] as String;

      final isValid = verifyTotp(token, testSecret);
      expect(isValid, isTrue);
    });

    test('verifyTotp succeeds for previous 15-minute window (clock skew grace period)', () {
      // Calculate token for previous window: (nowMs ~/ (15*60*1000)) - 1
      final prevIndex =
          DateTime.now().millisecondsSinceEpoch ~/ (15 * 60 * 1000) - 1;
      final input = utf8.encode('$testSecret:$prevIndex');
      final prevToken = sha256.convert(input).toString().substring(0, 16);

      final isValid = verifyTotp(prevToken, testSecret);
      expect(isValid, isTrue);
    });

    test('verifyTotp rejects token from 2 windows ago (expired)', () {
      final twoWindowsAgoIndex =
          DateTime.now().millisecondsSinceEpoch ~/ (15 * 60 * 1000) - 2;
      final input = utf8.encode('$testSecret:$twoWindowsAgoIndex');
      final expiredToken = sha256.convert(input).toString().substring(0, 16);

      final isValid = verifyTotp(expiredToken, testSecret);
      expect(isValid, isFalse);
    });

    test('verifyTotp rejects forged token or wrong secret', () {
      final payloadStr = generateQrPayload(testEmail, testSecret);
      final payload = jsonDecode(payloadStr) as Map<String, dynamic>;
      final token = payload['totp'] as String;

      const wrongSecret = 'fedcba9876543210fedcba9876543210';
      expect(verifyTotp(token, wrongSecret), isFalse);
      expect(verifyTotp('forgedtoken12345', testSecret), isFalse);
      expect(verifyTotp('', testSecret), isFalse);
      expect(verifyTotp(token, ''), isFalse);
    });
  });
}

