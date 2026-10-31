import 'package:cambus_connect_app/app/router/app_router.dart';
import 'package:cambus_connect_app/app/theme/app_theme.dart';
import 'package:cambus_connect_app/core/stag_lifecycle_guard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CambusConnectApp extends ConsumerWidget {
  const CambusConnectApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    // Initialize STAG Lifecycle Guard
    ref.watch(stagGuardProvider);

    return MaterialApp.router(
      title: 'Cambus Connect Enterprise',
      theme: AppTheme.lightTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
