import 'package:cambus_connect_app/data/models/student_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StudentModel & BusPassModel Schema Parity', () {
    test('StudentModel.fromJson handles ISO string passValidity and status', () {
      final json = {
        'name': 'Aarav Sharma',
        'email': 'aarav@college.edu',
        'collegeId': '0827CS211001',
        'enrollment': '0827CS211001',
        'phone': '9876543210',
        'parentPhone': '9876543211',
        'busRoute': 'Route 5 - South Campus',
        'assignedBusNumber': 'BUS-42',
        'pickupStop': 'Main Gate Stop',
        'passValidity': '2028-12-31',
        'qrSecret': 'abcdef0123456789abcdef0123456789',
        'status': 'Active',
      };

      final student = StudentModel.fromJson(json);
      expect(student.name, equals('Aarav Sharma'));
      expect(student.email, equals('aarav@college.edu'));
      expect(student.collegeId, equals('0827CS211001'));
      expect(student.busRoute, equals('Route 5 - South Campus'));
      expect(student.assignedBusNumber, equals('BUS-42'));
      expect(student.passValidity.year, equals(2028));
      expect(student.isActive, isTrue);
      expect(student.isExpired, isFalse);
      expect(student.isValid, isTrue);
    });

    test('StudentModel.fromJson handles Firestore Timestamp and passStatus fallback', () {
      final futureDate = DateTime.now().add(const Duration(days: 90));
      final json = {
        'name': 'Priya Patel',
        'email': 'priya@college.edu',
        'studentId': '0827EC211045',
        'passValidity': Timestamp.fromDate(futureDate),
        'passStatus': 'active',
      };

      final student = StudentModel.fromJson(json);
      expect(student.name, equals('Priya Patel'));
      expect(student.collegeId, equals('0827EC211045'));
      expect(student.isActive, isTrue);
      expect(student.isValid, isTrue);
    });

    test('BusPassModel preserves email, displayId, and qrSecret', () {
      final student = StudentModel(
        name: 'Rohan Gupta',
        email: 'rohan@college.edu',
        collegeId: '0827ME211088',
        enrollment: '0827ME211088',
        phone: '9812345678',
        parentPhone: '9812345679',
        busRoute: 'Route 2',
        pickupStop: 'Metro Station',
        passValidity: DateTime.now().add(const Duration(days: 30)),
        qrSecret: '11223344556677889900aabbccddeeff',
        status: 'Active',
      );

      final pass = BusPassModel.fromStudent(student);
      expect(pass.studentName, equals('Rohan Gupta'));
      expect(pass.email, equals('rohan@college.edu'));
      expect(pass.displayId, equals('0827ME211088'));
      expect(pass.assignedRoute, equals('Route 2'));
      expect(pass.qrSecret, equals('11223344556677889900aabbccddeeff'));
      expect(pass.isValid, isTrue);
    });

    test('Expired pass correctly flags isValid as false', () {
      final student = StudentModel(
        name: 'Expired User',
        email: 'expired@college.edu',
        collegeId: '0827EX000001',
        enrollment: '0827EX000001',
        phone: '',
        parentPhone: '',
        busRoute: 'Route 1',
        passValidity: DateTime.now().subtract(const Duration(days: 1)),
        qrSecret: 'secret',
        status: 'Active',
      );

      expect(student.isExpired, isTrue);
      expect(student.isValid, isFalse);

      final pass = BusPassModel.fromStudent(student);
      expect(pass.isValid, isFalse);
    });
  });
}

