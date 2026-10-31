import 'dart:async';
import 'dart:io' show Platform;
import 'package:cambus_connect_app/features/student/student_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cambus_connect_app/data/models/student_model.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';

class DigitalBusPassScreen extends ConsumerStatefulWidget {
  const DigitalBusPassScreen({super.key});

  @override
  ConsumerState<DigitalBusPassScreen> createState() => _DigitalBusPassScreenState();
}

class _DigitalBusPassScreenState extends ConsumerState<DigitalBusPassScreen> {
  static const platform = MethodChannel('cambus.security/flags');

  // QR refreshes strictly on the 15-minute window boundary or on pass change.
  Timer? _qrRefreshTimer;
  String? _currentQrPayload;
  BusPassModel? _currentPass;
  int? _lastTimeIndex;

  // Dedicated notifier: only the small countdown label rebuilds every second
  final ValueNotifier<int> _secondsNotifier = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _secureScreen();
    _startRefreshTimer();
  }

  void _startRefreshTimer() {
    _updateQr();
    _qrRefreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _tickCountdown();
    });
  }

  void _tickCountdown() {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final windowMs = 15 * 60 * 1000;
    final timeIndex = nowMs ~/ windowMs;
    final msIntoWindow = nowMs % windowMs;
    final secondsLeft = ((windowMs - msIntoWindow) / 1000).ceil();

    _secondsNotifier.value = secondsLeft;

    // Only regenerate cryptographic QR token when 15-min window boundary actually rotates
    if (timeIndex != _lastTimeIndex) {
      _updateQr();
    }
  }

  /// Generates a fresh TOTP QR payload on-device when time window rotates.
  void _updateQr() {
    if (_currentPass?.qrSecret == null) return;
    final pass = _currentPass!;

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final windowMs = 15 * 60 * 1000;
    final timeIndex = nowMs ~/ windowMs;
    final msIntoWindow = nowMs % windowMs;
    final secondsLeft = ((windowMs - msIntoWindow) / 1000).ceil();

    _lastTimeIndex = timeIndex;
    _secondsNotifier.value = secondsLeft;

    final payload = generateQrPayload(
      pass.email,
      pass.qrSecret!,
      studentId: pass.displayId,
    );

    if (mounted && payload != _currentQrPayload) {
      setState(() {
        _currentQrPayload = payload;
      });
    }
  }

  Future<void> _secureScreen() async {
    if (Platform.isAndroid) {
      try {
        await platform.invokeMethod('secureScreen');
      } catch (e) {
        debugPrint('Could not secure screen: $e');
      }
    }
  }

  @override
  void dispose() {
    _qrRefreshTimer?.cancel();
    _secondsNotifier.dispose();
    if (Platform.isAndroid) {
      platform.invokeMethod('unsecureScreen').catchError((_) => false);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final passState = ref.watch(studentPassProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: colorScheme.onSurface, // Dark text
        title: const Text('Digital Pass', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Container(
        color: colorScheme.surface, // Flat background
        child: SafeArea(
          child: passState.when(
            data: (pass) {
              if (pass == null) {
                return Center(child: Text('No pass data available.', style: TextStyle(color: colorScheme.onSurface)));
              }
              
              if (_currentPass != pass) {
                _currentPass = pass;
                // Generate QR immediately when pass data loads
                WidgetsBinding.instance.addPostFrameCallback((_) => _updateQr());
              }

              final isActive = pass.status.toLowerCase() == 'active';
              final isExpired = pass.passValidity.isBefore(DateTime.now());
              final statusColor = isActive && !isExpired ? const Color(0xFF10B981) : colorScheme.error;

              return Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  child: Column(
                    children: [
                      const SizedBox(height: 50), // Push down below appbar
                      // Anti-fraud Live Clock
                      const _LiveClock(),
                      const SizedBox(height: 24),
                      
                      // ID Card
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5), // Flat border
                        ),
                        child: Column(
                          children: [
                            // Header
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.05),
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                                border: Border(bottom: BorderSide(color: statusColor.withValues(alpha: 0.2))),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      color: statusColor.withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(Icons.person_rounded, size: 36, color: statusColor),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          pass.studentName,
                                          style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF1A1D29),
                                          ),
                                        ),
                                        Text(
                                          pass.displayId,
                                          style: const TextStyle(color: Color(0xFF6B7280), fontSize: 14),
                                        ),
                                        Text(
                                          pass.branch ?? '',
                                          style: const TextStyle(
                                            color: Color(0xFF0037B0),
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            // QR Section
                            Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(24),
                                      border: Border.all(color: const Color(0xFFE2E8F0), width: 2),
                                    ),
                                    child: _currentQrPayload != null
                                        ? QrImageView(
                                            data: _currentQrPayload!,
                                            version: QrVersions.auto,
                                            size: 200.0,
                                            dataModuleStyle: const QrDataModuleStyle(
                                              dataModuleShape: QrDataModuleShape.square,
                                              color: Color(0xFF1E293B),
                                            ),
                                            eyeStyle: const QrEyeStyle(
                                              eyeShape: QrEyeShape.square,
                                              color: Color(0xFF1E293B),
                                            ),
                                          )
                                        : const SizedBox(
                                            width: 200,
                                            height: 200,
                                            child: Center(
                                              child: CircularProgressIndicator(),
                                            ),
                                          ),
                                  ),
                                  const SizedBox(height: 16),
                                  // TOTP countdown pill (isolated repaint - zero parent rebuild)
                                  if (pass.qrSecret != null)
                                    ValueListenableBuilder<int>(
                                      valueListenable: _secondsNotifier,
                                      builder: (context, seconds, _) {
                                        return Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                          margin: const EdgeInsets.only(bottom: 12),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: const Color(0xFFE2E8F0)),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.refresh_rounded,
                                                  size: 14, color: Color(0xFF64748B)),
                                              const SizedBox(width: 6),
                                              Text(
                                                'Refreshes in ${seconds}s',
                                                style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Color(0xFF64748B),
                                                    fontWeight: FontWeight.w600),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  // Status Badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: statusColor,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          isActive && !isExpired
                                              ? Icons.check_circle_outline_rounded
                                              : Icons.cancel_outlined,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          isActive && !isExpired ? 'VALID PASS' : 'INVALID PASS',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            // Footer Info
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: const BoxDecoration(
                                color: Color(0xFFF9FAFB),
                                borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
                              ),
                              child: Column(
                                children: [
                                  _InfoRow(label: 'Roll / ID', value: pass.displayId),
                                  const SizedBox(height: 12),
                                  _InfoRow(label: 'Assigned Route', value: pass.assignedRoute ?? 'Unassigned'),
                                  const SizedBox(height: 12),
                                  _InfoRow(label: 'Boarding Stop', value: pass.boardingStop ?? 'Unassigned'),
                                  const SizedBox(height: 12),
                                  _InfoRow(
                                    label: 'Valid Until', 
                                    value: DateFormat.yMMMd().format(pass.passValidity),
                                    valueColor: isExpired ? const Color(0xFFBA1A1A) : null,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 32),
                      Text(
                        'Screenshots are disabled for security.\nDo not share your digital pass.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 12),
                      ),
                    ],
                  ),
                ),
              );
            },
            loading: () => Center(child: CircularProgressIndicator(color: colorScheme.primary)),
            error: (err, stack) => Center(child: Text('Error: $err', style: TextStyle(color: colorScheme.error))),
          ),
        ),
      ),
    );
  }
}

// ── Anti-Fraud Live Clock ────────────────────────────────────────────────────
class _LiveClock extends StatefulWidget {
  const _LiveClock();

  @override
  State<_LiveClock> createState() => _LiveClockState();
}

class _LiveClockState extends State<_LiveClock> {
  late Timer _timer;
  late DateTime _now;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9), // Slate 100
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)), // Slate 200
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.access_time_rounded, color: Color(0xFF64748B), size: 16),
          const SizedBox(width: 8),
          Text(
            DateFormat('MMM dd, yyyy • hh:mm:ss a').format(_now),
            style: const TextStyle(
              color: Color(0xFF1E293B),
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Info Row ────────────────────────────────────────────────────────────────
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: const TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w500, fontSize: 13),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: valueColor ?? const Color(0xFF1A1D29),
              fontSize: 13,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
