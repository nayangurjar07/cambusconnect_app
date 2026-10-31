import 'dart:async';
import 'package:cambus_connect_app/data/models/user_model.dart';
import 'package:cambus_connect_app/data/repositories/auth_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final authControllerProvider = AsyncNotifierProvider<AuthController, UserModel?>(() {
  return AuthController();
});

class AuthController extends AsyncNotifier<UserModel?> {
  @override
  FutureOr<UserModel?> build() {
    // Listen to the auth state changes from the repository
    final authStream = ref.watch(authRepositoryProvider).authStateChanges;
    
    // Subscribe to the stream to update our state whenever Firebase auth state changes
    final subscription = authStream.listen((user) {
      state = AsyncData(user);
    }, onError: (Object err, StackTrace st) {
      state = AsyncError(err, st);
    });

    ref.onDispose(() {
      subscription.cancel();
    });

    // Return the initial current user if already logged in (or null)
    return ref.read(authRepositoryProvider).currentUser;
  }

  Future<void> login(String email, String password) async {
    state = const AsyncLoading();
    try {
      final user = await ref.read(authRepositoryProvider).login(email, password);
      state = AsyncData(user);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> logout() async {
    state = const AsyncLoading();
    try {
      await ref.read(authRepositoryProvider).logout();
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}
