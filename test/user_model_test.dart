import 'package:cambus_connect_app/data/models/user_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UserModel Role & Schema Parsing', () {
    test('Correctly parses all role variants', () {
      expect(UserModel.parseRole('student'), equals(UserRole.student));
      expect(UserModel.parseRole('STUDENT'), equals(UserRole.student));
      expect(UserModel.parseRole('admin'), equals(UserRole.admin));
      expect(UserModel.parseRole('driver'), equals(UserRole.driver));
      expect(UserModel.parseRole('owner'), equals(UserRole.owner));
      expect(UserModel.parseRole('unknown_role'), equals(UserRole.unknown));
      expect(UserModel.parseRole(null), equals(UserRole.unknown));
    });

    test('UserModel.fromJson parses staff and student records', () {
      final staffUser = UserModel.fromJson({
        'email': 'driver@campus.edu',
        'name': 'Rajesh Driver',
        'role': 'driver',
      }, 'uid_123');

      expect(staffUser.uid, equals('uid_123'));
      expect(staffUser.email, equals('driver@campus.edu'));
      expect(staffUser.role, equals(UserRole.driver));

      final studentUser = UserModel.fromJson({
        'email': 'student@campus.edu',
        'name': 'Ananya Roy',
        'role': 'student',
        'branch': 'Computer Science',
        'year': '3rd Year',
        'status': 'Active',
      }, 'uid_456');

      expect(studentUser.role, equals(UserRole.student));
      expect(studentUser.branch, equals('Computer Science'));
      expect(studentUser.year, equals('3rd Year'));
      expect(studentUser.passStatus, equals('Active'));
    });
  });
}

