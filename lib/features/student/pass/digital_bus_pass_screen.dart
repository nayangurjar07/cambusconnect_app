import 'dart:async';
import 'dart:io' show Platform;
import 'package:cambus_connect_app/core/firestore_parsers.dart';
import 'package:cambus_connect_app/data/models/student_model.dart';
import 'package:cambus_connect_app/features/student/student_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screen_brightness/screen_brightness.dart';

class DigitalBusPassScreen extends ConsumerStatefulWidget {
  const DigitalBusPassScreen({super.key});

  @override
  ConsumerState<DigitalBusPassScreen> createState() => _DigitalBusPassScreenState();
}

class _DigitalBusPassScreenState extends ConsumerState<DigitalBusPassScreen> {
  static const platform = MethodChannel('cambus.security/flags');

  Timer? _qrRefreshTimer;
  String? _currentQrPayload;
  BusPassModel? _currentPass;
  int? _lastTimeIndex;
  double? _previousBrightness;

  final ValueNotifier<int> _secondsNotifier = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _secureScreen();
    _boostBrightness();
    _startRefreshTimer();
  }

  Future<void> _boostBrightness() async {
    try {
      _previousBrightness = await ScreenBrightness().application;
      await ScreenBrightness().setApplicationScreenBrightness(1.0);
    } catch (e) {
      debugPrint('Screen brightness boost failed: $e');
    }
  }

  Future<void> _restoreBrightness() async {
    try {
      if (_previousBrightness != null) {
        await ScreenBrightness().setApplicationScreenBrightness(_previousBrightness!);
      } else {
        await ScreenBrightness().resetApplicationScreenBrightness();
      }
    } catch (e) {
      debugPrint('Screen brightness restore failed: $e');
    }
  }

  void _startRefreshTimer() {
    _updateQr();
    _qrRefreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _tickCountdown();
    });
  }

  void _tickCountdown() {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    const windowMs = 15 * 60 * 1000;
    final timeIndex = nowMs ~/ windowMs;
    final msIntoWindow = nowMs % windowMs;
    final secondsLeft = ((windowMs - msIntoWindow) / 1000).ceil();

    _secondsNotifier.value = secondsLeft;

    if (timeIndex != _lastTimeIndex) {
      _updateQr();
    }
  }

  void _updateQr() {
    if (_currentPass == null) return;
    final pass = _currentPass!;

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    const windowMs = 15 * 60 * 1000;
    final timeIndex = nowMs ~/ windowMs;
    final msIntoWindow = nowMs % windowMs;
    final secondsLeft = ((windowMs - msIntoWindow) / 1000).ceil();

    _lastTimeIndex = timeIndex;
    _secondsNotifier.value = secondsLeft;

    // Canonical deterministic format: CAMBUS:{collegeId}:{assignedBus}:{todayIso}
    final payload = generateCanonicalQrPayload(
      collegeId: pass.displayId,
      assignedBusId: pass.assignedRoute,
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
    _restoreBrightness();
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
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: const Color(0xFF0F172A),
        title: const Text(
          'Campus Boarding Pass',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: passState.when(
          data: (pass) {
            if (pass == null) {
              return const Center(
                child: Text('No bus pass record found for your account.'),
              );
            }

            if (_currentPass != pass) {
              _currentPass = pass;
              WidgetsBinding.instance.addPostFrameCallback((_) => _updateQr());
            }

            final isActive = pass.status.toLowerCase() == 'active';
            final isPassActive = FirestoreParsers.isPassActive(pass.passValidity);
            final isValid = isActive && isPassActive;

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                children: [
                  // Anti-fraud Live Clock Watermark
                  const _LiveClock(),
                  const SizedBox(height: 18),

                  // Apple Wallet Ticket Card with Perforated Stub
                  ClipPath(
                    clipper: TicketClipper(punchRadius: 14, punchDistanceRatio: 0.69),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // ── Pass Header ──
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isValid
                                    ? [const Color(0xFF0037B0), const Color(0xFF0052FF)]
                                    : [const Color(0xFF991B1B), const Color(0xFFDC2626)],
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.directions_bus_filled_rounded,
                                    color: Colors.white,
                                    size: 26,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'CAMBUS CONNECT',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 1.5,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        pass.studentName,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    isValid ? 'ACTIVE' : 'EXPIRED',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // ── QR Code Section ──
                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.03),
                                        blurRadius: 10,
                                      ),
                                    ],
                                  ),
                                  child: _currentQrPayload != null
                                      ? QrImageView(
                                          data: _currentQrPayload!,
                                          version: QrVersions.auto,
                                          size: 190.0,
                                          dataModuleStyle: const QrDataModuleStyle(
                                            dataModuleShape: QrDataModuleShape.square,
                                            color: Color(0xFF0F172A),
                                          ),
                                          eyeStyle: const QrEyeStyle(
                                            eyeShape: QrEyeShape.square,
                                            color: Color(0xFF0037B0),
                                          ),
                                        )
                                      : const SizedBox(
                                          width: 190,
                                          height: 190,
                                          child: Center(
                                            child: CircularProgressIndicator(),
                                          ),
                                        ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  pass.displayId,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 2,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Hold near driver scanner on bus boarding',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // ── Dashed Perforation Line ──
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: CustomPaint(
                              size: const Size(double.infinity, 1.5),
                              painter: DashedLinePainter(),
                            ),
                          ),

                          // ── Ticket Stub Metadata ──
                          Container(
                            padding: const EdgeInsets.all(22),
                            color: const Color(0xFFF8FAFC),
                            child: Column(
                              children: [
                                _InfoRow(label: 'Assigned Route', value: pass.assignedRoute ?? 'Not Assigned'),
                                const SizedBox(height: 10),
                                _InfoRow(label: 'Boarding Stop', value: pass.boardingStop ?? 'Not Assigned'),
                                const SizedBox(height: 10),
                                _InfoRow(
                                  label: 'Valid Until',
                                  value: DateFormat.yMMMd().format(pass.passValidity),
                                  valueColor: isValid ? null : const Color(0xFFDC2626),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shield_outlined, size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 6),
                      Text(
                        'Anti-fraud auto-brightness & screen security active',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
          loading: () => Center(
            child: CircularProgressIndicator(color: colorScheme.primary),
          ),
          error: (err, _) => Center(
            child: Text('Error loading pass: $err'),
          ),
        ),
      ),
    );
  }
}

// ── Anti-Fraud Live Clock Watermark ──────────────────────────────────────────
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
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.alarm_on_rounded, color: Color(0xFF0037B0), size: 16),
          const SizedBox(width: 8),
          Text(
            DateFormat('EEE, d MMM yyyy • HH:mm:ss').format(_now),
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontWeight: FontWeight.bold,
              fontSize: 12,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Ticket Stub Notch Clipper ───────────────────────────────────────────────
class TicketClipper extends CustomClipper<Path> {
  final double punchRadius;
  final double punchDistanceRatio;

  TicketClipper({this.punchRadius = 14.0, this.punchDistanceRatio = 0.69});

  @override
  Path getClip(Size size) {
    final path = Path();
    final punchY = size.height * punchDistanceRatio;

    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width, punchY - punchRadius);
    path.arcToPoint(
      Offset(size.width, punchY + punchRadius),
      radius: Radius.circular(punchRadius),
      clockwise: false,
    );
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.lineTo(0, punchY + punchRadius);
    path.arcToPoint(
      Offset(0, punchY - punchRadius),
      radius: Radius.circular(punchRadius),
      clockwise: false,
    );
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

// ── Dashed Perforation Line ────────────────────────────────────────────────
class DashedLinePainter extends CustomPainter {
  final Color color;
  DashedLinePainter({this.color = const Color(0xFFCBD5E1)});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5;
    const dashWidth = 5.0;
    const dashSpace = 4.0;
    double startX = 0;
    while (startX < size.width) {
      canvas.drawLine(Offset(startX, 0), Offset(startX + dashWidth, 0), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? const Color(0xFF0F172A),
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
