import 'package:cambus_connect_app/data/models/user_model.dart';
import 'package:cambus_connect_app/features/admin/dashboard/admin_dashboard_screen.dart';
import 'package:cambus_connect_app/features/admin/students/admin_students_screen.dart';
import 'package:cambus_connect_app/features/auth/auth_controller.dart';
import 'package:cambus_connect_app/features/auth/login_screen.dart';
import 'package:cambus_connect_app/features/student/home/student_home_screen.dart';
import 'package:cambus_connect_app/features/student/buses/bus_directory_screen.dart';
import 'package:cambus_connect_app/features/student/notifications/notifications_screen.dart';
import 'package:cambus_connect_app/features/student/pass/digital_bus_pass_screen.dart';
import 'package:cambus_connect_app/features/student/profile/student_profile_screen.dart';
import 'package:cambus_connect_app/features/student/tracking/live_bus_tracking_screen.dart';
import 'package:cambus_connect_app/features/admin/scan/admin_scan_pass_screen.dart';
import 'package:cambus_connect_app/features/driver/dashboard/driver_dashboard_screen.dart';
import 'package:cambus_connect_app/features/owner/dashboard/owner_dashboard_screen.dart';
import 'package:cambus_connect_app/features/support/support_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authControllerProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final isLoading = authState.isLoading;

      // Don't redirect while auth is loading
      if (isLoading) return null;

      final user = authState.value;
      final isAuth = user != null;
      final isGoingToLogin = state.matchedLocation == '/login';

      // Not authenticated → send to login
      if (!isAuth) {
        return isGoingToLogin ? null : '/login';
      }

      // Authenticated → redirect away from login based on role
      if (isGoingToLogin) {
        switch (user.role) {
          case UserRole.admin:
            return '/admin/dashboard';
          case UserRole.student:
            return '/student/home';
          case UserRole.driver:
            return '/driver/dashboard';
          case UserRole.owner:
            return '/owner/dashboard';
          case UserRole.unknown:
            // Unknown role: stay on login, they cannot proceed
            return '/login';
        }
      }

      // Role-based route protection
      final isAdminRoute = state.matchedLocation.startsWith('/admin');
      final isStudentRoute = state.matchedLocation.startsWith('/student');
      final isDriverRoute = state.matchedLocation.startsWith('/driver');
      final isOwnerRoute = state.matchedLocation.startsWith('/owner');

      if (isAdminRoute && user.role != UserRole.admin) {
        // Allow drivers to access the scan pass screen for passenger verification
        if (state.matchedLocation == '/admin/scan' && user.role == UserRole.driver) {
          return null;
        }
        return '/student/home';
      }

      if (isDriverRoute && user.role != UserRole.driver) {
        return '/login';
      }

      if (isOwnerRoute && user.role != UserRole.owner) {
        return '/login';
      }

      // If it's a student route, and the user is NOT a student AND NOT an admin
      if (isStudentRoute && user.role != UserRole.student && user.role != UserRole.admin) {
        return '/admin/dashboard';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      // ── Student Routes ───────────────────────────────────────────────
      GoRoute(
        path: '/student/home',
        builder: (context, state) => const StudentHomeScreen(),
      ),
      GoRoute(
        path: '/student/pass',
        builder: (context, state) => const DigitalBusPassScreen(),
      ),
      GoRoute(
        path: '/student/track',
        builder: (context, state) => const LiveBusTrackingScreen(),
      ),
      GoRoute(
        path: '/student/buses',
        builder: (context, state) => const BusDirectoryScreen(),
      ),
      GoRoute(
        path: '/student/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/student/profile',
        builder: (context, state) => const StudentProfileScreen(),
      ),
      // ── Admin Routes ─────────────────────────────────────────────────
      GoRoute(
        path: '/admin/dashboard',
        builder: (context, state) => const AdminDashboardScreen(),
      ),
      GoRoute(
        path: '/admin/students',
        builder: (context, state) => const AdminStudentsScreen(),
      ),
      GoRoute(
        path: '/admin/scan',
        builder: (context, state) => const AdminScanPassScreen(),
      ),
      // ── Driver Routes ────────────────────────────────────────────────
      GoRoute(
        path: '/driver/dashboard',
        builder: (context, state) => const DriverDashboardScreen(),
      ),
      GoRoute(
        path: '/driver/scan',
        builder: (context, state) => const AdminScanPassScreen(),
      ),
      // ── Owner Routes ─────────────────────────────────────────────────
      GoRoute(
        path: '/owner/dashboard',
        builder: (context, state) => const OwnerDashboardScreen(),
      ),
      // ── Shared Routes ────────────────────────────────────────────────
      GoRoute(
        path: '/support',
        builder: (context, state) => const SupportScreen(),
      ),
    ],
  );
});
