import 'package:cambus_connect_app/core/firestore_parsers.dart';
import 'package:cambus_connect_app/data/models/user_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return FirebaseAuthRepository(
    FirebaseAuth.instance,
    FirebaseFirestore.instance,
  );
});

abstract class AuthRepository {
  Future<UserModel> login(String identifier, String password);
  Future<UserModel> signInWithGoogle();
  Future<void> logout();
  Stream<UserModel?> get authStateChanges;
  UserModel? get currentUser;
  Future<void> createStudentAccountIsolated({
    required String email,
    required String password,
  });
}

class FirebaseAuthRepository implements AuthRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  FirebaseAuthRepository(this._auth, this._firestore);

  UserModel? _currentUser;

  /// Smart Enrollment ID expansion:
  /// Converts enrollment numbers (e.g. "0818CS221001" or "admin") to institutional email
  static String normalizeIdentifier(String input) {
    final clean = input.trim().toLowerCase();
    if (clean.isEmpty) return '';
    if (!clean.contains('@')) {
      if (clean == 'admin') {
        return 'admin@indoreinstitute.com';
      }
      return '$clean@indoreinstitute.com';
    }
    return clean;
  }

  @override
  Future<UserModel> login(String identifier, String password) async {
    final email = normalizeIdentifier(identifier);
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Web portal stores users by lowercase email as document ID
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
  Future<UserModel> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw Exception('Google sign-in was cancelled by user.');
      }

      final email = googleUser.email.toLowerCase().trim();
      // Verify institutional domain
      if (!email.endsWith('@indoreinstitute.com')) {
        await _googleSignIn.signOut();
        throw Exception(
          'Access restricted. Please sign in with your official @indoreinstitute.com account.',
        );
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final user = await _fetchUserByEmail(email, userCredential.user!.uid);
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
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
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

  /// Secondary FirebaseApp registration for Admin:
  /// Creates a student account without evicting or signing out the logged-in admin!
  @override
  Future<void> createStudentAccountIsolated({
    required String email,
    required String password,
  }) async {
    final cleanEmail = normalizeIdentifier(email);
    final secondaryAppName = 'SecondaryAdminApp_${DateTime.now().millisecondsSinceEpoch}';
    FirebaseApp? secondaryApp;

    try {
      secondaryApp = await Firebase.initializeApp(
        name: secondaryAppName,
        options: Firebase.app().options,
      );

      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
      await secondaryAuth.createUserWithEmailAndPassword(
        email: cleanEmail,
        password: password,
      );
    } finally {
      if (secondaryApp != null) {
        await secondaryApp.delete();
      }
    }
  }

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
        validityDate: FirestoreParsers.parseDate(data['validityDate']),
        assignedBusId: data['assignedBusId'] ?? '',
        busRoute: data['busRoute'] ?? 'Not Assigned',
        collegeId: data['collegeId'],
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
        validityDate: FirestoreParsers.parseDate(data['validityDate']),
        assignedBusId: data['assignedBusId'] ?? '',
        busRoute: data['busRoute'] ?? 'Not Assigned',
        collegeId: data['collegeId'],
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
        validityDate: FirestoreParsers.parseDate(data['passValidity']),
        assignedBusId: data['assignedBusId'] ?? '',
        busRoute: data['busRoute'] ?? data['assignedRoute'] ?? 'Not Assigned',
        collegeId: data['collegeId'] ?? data['enrollment'] ?? data['studentId'],
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
        validityDate: FirestoreParsers.parseDate(data['passValidity']),
        assignedBusId: data['assignedBusId'] ?? '',
        busRoute: data['busRoute'] ?? data['assignedRoute'] ?? 'Not Assigned',
        collegeId: data['collegeId'] ?? data['enrollment'] ?? data['studentId'],
      );
    }

    throw Exception('Account record not found in campus database for $cleanEmail.');
  }

  Exception _mapFirebaseAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return Exception('No account found for that email or enrollment number.');
      case 'wrong-password':
        return Exception('Incorrect password provided.');
      case 'invalid-email':
        return Exception('The email or enrollment number is badly formatted.');
      case 'invalid-credential':
        return Exception('Invalid login credentials. Please check your enrollment ID and password.');
      case 'too-many-requests':
        return Exception('Too many login attempts. Please try again later.');
      case 'network-request-failed':
        return Exception('Network error. Please check your connection.');
      default:
        return Exception(e.message ?? 'Authentication failed.');
    }
  }
}
