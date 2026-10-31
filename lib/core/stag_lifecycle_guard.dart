import 'dart:async';
import 'package:cambus_connect_app/core/firestore_parsers.dart';
import 'package:cambus_connect_app/data/models/user_model.dart';
import 'package:cambus_connect_app/data/repositories/auth_repository.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final stagGuardProvider = Provider<StagLifecycleGuard>((ref) {
  final authRepo = ref.read(authRepositoryProvider);
  final guard = StagLifecycleGuard(authRepo);
  guard.initialize();
  ref.onDispose(() {
    guard.dispose();
  });
  return guard;
});

/// Self-Terminating Authentication Guard (STAG):
/// Continuously enforces pass validity in real-time and on lifecycle transitions.
/// If a student's pass expires (end of day T23:59:59), logs out immediately.
class StagLifecycleGuard with WidgetsBindingObserver {
  final AuthRepository _authRepository;
  Timer? _periodicCheckTimer;
  StreamSubscription<UserModel?>? _userSubscription;

  StagLifecycleGuard(this._authRepository);

  void initialize() {
    WidgetsBinding.instance.addObserver(this);

    // 1. Listen to user changes
    _userSubscription = _authRepository.authStateChanges.listen((user) {
      if (user != null && user.role == UserRole.student) {
        _evaluatePassValidity(user);
      }
    });

    // 2. Periodic check every 60 seconds
    _periodicCheckTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      final user = _authRepository.currentUser;
      if (user != null && user.role == UserRole.student) {
        _evaluatePassValidity(user);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final user = _authRepository.currentUser;
      if (user != null && user.role == UserRole.student) {
        _evaluatePassValidity(user);
      }
    }
  }

  void _evaluatePassValidity(UserModel user) {
    if (user.validityDate == null) return;

    final isActive = FirestoreParsers.isPassActive(user.validityDate);
    if (!isActive) {
      // Pass is expired - trigger immediate secure eviction
      _authRepository.logout();
    }
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _periodicCheckTimer?.cancel();
    _userSubscription?.cancel();
  }
}
