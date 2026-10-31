import 'package:cambus_connect_app/data/models/user_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return FirebaseAuthRepository(
    FirebaseAuth.instance,
    FirebaseFirestore.instance,
  );
});

abstract class AuthRepository {
  Future<UserModel> login(String email, String password);
  Future<void> logout();
  Stream<UserModel?> get authStateChanges;
  UserModel? get currentUser;
}

class FirebaseAuthRepository implements AuthRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  FirebaseAuthRepository(this._auth, this._firestore);

  UserModel? _currentUser;

  @override
  Future<UserModel> login(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Web portal stores users by email as document ID
      final user = await _fetchUserByEmail(email, credential.user!.uid);
      _currentUser = user;
      return user;
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseAuthException(e);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> logout() async {
    await _auth.signOut();
    _currentUser = null;
  }

  @override
  Stream<UserModel?> get authStateChanges {
    return _auth.authStateChanges().asyncMap((firebaseUser) async {
      if (firebaseUser == null || firebaseUser.email == null) {
        if (firebaseUser != null && firebaseUser.email == null) {
          await _auth.signOut();
        }
        _currentUser = null;
        return null;
      }
      try {
        final user = await _fetchUserByEmail(firebaseUser.email!, firebaseUser.uid);
        _currentUser = user;
        return user;
      } catch (e) {
        // If we fail to fetch the user document, sign them out for safety.
        await _auth.signOut();
        _currentUser = null;
        return null;
      }
    });
  }

  @override
  UserModel? get currentUser => _currentUser;

  /// Dual-collection lookup:
  /// 1. /users/{email} (Staff: admin, driver, owner, conductor, superadmin)
  /// 2. /students/{email} (Student bus pass holders)
  Future<UserModel> _fetchUserByEmail(String email, String uid) async {
    final cleanEmail = email.toLowerCase().trim();

    // 1. Check users collection (Admins, Drivers, Owners, Staff)
    final userDoc = await _firestore.collection('users').doc(cleanEmail).get();
    if (userDoc.exists) {
      final data = userDoc.data()!;
      return UserModel(
        uid: uid,
        email: cleanEmail,
        name: data['name'] ?? 'Staff',
        role: UserModel.parseRole(data['role']),
        branch: data['branch'] ?? '',
        year: data['year'] ?? '',
        passStatus: data['status'] ?? '',
      );
    }

    // Fallback: check users collection by email field
    final userQuery = await _firestore
        .collection('users')
        .where('email', isEqualTo: cleanEmail)
        .limit(1)
        .get();
    if (userQuery.docs.isNotEmpty) {
      final data = userQuery.docs.first.data();
      return UserModel(
        uid: uid,
        email: cleanEmail,
        name: data['name'] ?? 'Staff',
        role: UserModel.parseRole(data['role']),
        branch: data['branch'] ?? '',
        year: data['year'] ?? '',
        passStatus: data['status'] ?? '',
      );
    }

    // 2. Check students collection (Bus pass holders)
    final studentDoc =
        await _firestore.collection('students').doc(cleanEmail).get();
    if (studentDoc.exists) {
      final data = studentDoc.data()!;
      return UserModel(
        uid: uid,
        email: cleanEmail,
        name: data['name'] ?? 'Student',
        role: UserRole.student,
        branch: data['branch'] ?? '',
        year: data['year'] ?? '',
        passStatus: data['status'] ?? data['passStatus'] ?? 'Active',
      );
    }

    // Fallback: check students collection by email field
    final studentQuery = await _firestore
        .collection('students')
        .where('email', isEqualTo: cleanEmail)
        .limit(1)
        .get();
    if (studentQuery.docs.isNotEmpty) {
      final data = studentQuery.docs.first.data();
      return UserModel(
        uid: uid,
        email: cleanEmail,
        name: data['name'] ?? 'Student',
        role: UserRole.student,
        branch: data['branch'] ?? '',
        year: data['year'] ?? '',
        passStatus: data['status'] ?? data['passStatus'] ?? 'Active',
      );
    }

    throw Exception('Account record not found in campus database for $cleanEmail.');
  }

  Exception _mapFirebaseAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return Exception('No account found for that email.');
      case 'wrong-password':
        return Exception('Incorrect password provided.');
      case 'invalid-email':
        return Exception('The email address is badly formatted.');
      case 'invalid-credential':
        return Exception('Invalid login credentials. Please check your email and password.');
      case 'too-many-requests':
        return Exception('Too many login attempts. Please try again later.');
      case 'network-request-failed':
        return Exception('Network error. Please check your connection.');
      default:
        return Exception(e.message ?? 'Authentication failed.');
    }
  }
}
