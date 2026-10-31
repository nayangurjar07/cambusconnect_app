import 'dart:async';
import 'dart:convert';
import 'package:cambus_connect_app/core/firestore_parsers.dart';
import 'package:cambus_connect_app/features/student/student_providers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class AdminScanPassScreen extends StatefulWidget {
  const AdminScanPassScreen({super.key});

  @override
  State<AdminScanPassScreen> createState() => _AdminScanPassScreenState();
}

class _AdminScanPassScreenState extends State<AdminScanPassScreen>
    with SingleTickerProviderStateMixin {
  final MobileScannerController _scannerController = MobileScannerController();
  late final AnimationController _laserController;
  bool _isProcessing = false;
  bool _torchEnabled = false;

  @override
  void initState() {
    super.initState();
    _laserController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _laserController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _handleScan(String scannedData) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      String lookupKey = scannedData.trim();
      String? scannedBus;
      String? totpToken;

      // 1. Check Canonical CAMBUS:{collegeId}:{assignedBus}:{dateIso} format
      if (scannedData.startsWith('CAMBUS:')) {
        final parts = scannedData.split(':');
        if (parts.length >= 4) {
          lookupKey = parts[1].trim();
          scannedBus = parts[2].trim();
        }
      }
      // 2. Check JSON TOTP payload format
      else if (scannedData.trim().startsWith('{') && scannedData.trim().endsWith('}')) {
        try {
          final payload = jsonDecode(scannedData) as Map<String, dynamic>;
          lookupKey = (payload['email'] ??
                  payload['studentId'] ??
                  payload['collegeId'] ??
                  payload['enrollment'] ??
                  lookupKey)
              .toString();
          totpToken = payload['totp']?.toString();
        } catch (_) {}
      }

      final firestore = FirebaseFirestore.instance;
      final cleanKey = lookupKey.toLowerCase().trim();

      // Query student record
      DocumentSnapshot? doc;
      final emailDoc = await firestore.collection('students').doc(cleanKey).get();
      if (emailDoc.exists) {
        doc = emailDoc;
      }

      // Query fallbacks
      if (doc == null || !doc.exists) {
        final queryCollege = await firestore
            .collection('students')
            .where('collegeId', isEqualTo: lookupKey.trim())
            .limit(1)
            .get();
        if (queryCollege.docs.isNotEmpty) {
          doc = queryCollege.docs.first;
        }
      }

      if (doc == null || !doc.exists) {
        final queryEnroll = await firestore
            .collection('students')
            .where('enrollment', isEqualTo: lookupKey.trim())
            .limit(1)
            .get();
        if (queryEnroll.docs.isNotEmpty) {
          doc = queryEnroll.docs.first;
        }
      }

      if (doc == null || !doc.exists) {
        final queryEmail = await firestore
            .collection('students')
            .where('email', isEqualTo: cleanKey)
            .limit(1)
            .get();
        if (queryEmail.docs.isNotEmpty) {
          doc = queryEmail.docs.first;
        }
      }

      if (doc == null || !doc.exists) {
        HapticFeedback.vibrate();
        _showResultSheet(
          title: 'Pass Not Found',
          subtitle: 'No campus registration for "$lookupKey"',
          status: _ScanStatus.error,
        );
        return;
      }

      final data = doc.data() as Map<String, dynamic>;
      final studentName = data['name']?.toString() ?? 'Student';
      final collegeId = (data['collegeId'] ?? data['enrollment'] ?? lookupKey).toString();
      final routeName = data['busRoute'] ?? data['assignedRoute'] ?? 'Not Assigned';

      // 3. Cryptographic TOTP Verification (if present)
      if (totpToken != null) {
        final qrSecret = data['qrSecret'] as String?;
        if (qrSecret == null || qrSecret.isEmpty || !verifyTotp(totpToken, qrSecret)) {
          HapticFeedback.vibrate();
          _showResultSheet(
            title: 'Invalid or Forged Pass',
            subtitle: 'TOTP cryptographic signature mismatch',
            status: _ScanStatus.error,
          );
          return;
        }
      }

      // 4. Pass Expiration Check
      final isPassActive = FirestoreParsers.isPassActive(data['passValidity']);
      final statusStr = (data['status'] ?? data['passStatus'] ?? 'Active').toString();
      final isStatusActive = statusStr.toLowerCase() == 'active';

      if (!isPassActive || !isStatusActive) {
        HapticFeedback.vibrate();
        final expiryDate = FirestoreParsers.parseDate(data['passValidity']);
        final formatted = expiryDate != null ? DateFormat('dd MMM yyyy').format(expiryDate) : 'Expired';
        _showResultSheet(
          title: 'Pass Inactive / Expired',
          subtitle: '$studentName • Valid Until: $formatted',
          status: _ScanStatus.error,
        );
        return;
      }

      // 5. Anti-Passback Check
      final todayIso = FirestoreParsers.toIsoDateString(DateTime.now());
      final boardingDocRef = firestore.collection('daily_boardings').doc('${todayIso}_$collegeId');
      final boardingDoc = await boardingDocRef.get();

      if (boardingDoc.exists) {
        HapticFeedback.vibrate();
        _showResultSheet(
          title: 'Already Boarded Today',
          subtitle: '$studentName has already scanned today (Anti-passback alert)',
          status: _ScanStatus.warning,
          studentName: studentName,
          collegeId: collegeId,
          route: routeName,
        );
        return;
      }

      // 6. Record Boarding in Firestore
      await boardingDocRef.set({
        'collegeId': collegeId,
        'studentName': studentName,
        'busId': scannedBus ?? data['assignedBusId'] ?? '',
        'scannedAt': FieldValue.serverTimestamp(),
        'date': todayIso,
      });

      // 7. Approved!
      HapticFeedback.heavyImpact();
      _showResultSheet(
        title: 'Boarding Approved',
        subtitle: '$studentName ($collegeId)',
        status: _ScanStatus.success,
        studentName: studentName,
        collegeId: collegeId,
        route: routeName,
      );
    } catch (e) {
      HapticFeedback.vibrate();
      _showResultSheet(
        title: 'Scan Error',
        subtitle: e.toString(),
        status: _ScanStatus.error,
      );
    }
  }

  void _showResultSheet({
    required String title,
    required String subtitle,
    required _ScanStatus status,
    String? studentName,
    String? collegeId,
    String? route,
  }) {
    Color bg;
    IconData icon;
    switch (status) {
      case _ScanStatus.success:
        bg = const Color(0xFF059669);
        icon = Icons.check_circle_rounded;
        break;
      case _ScanStatus.warning:
        bg = const Color(0xFFD97706);
        icon = Icons.warning_amber_rounded;
        break;
      case _ScanStatus.error:
        bg = const Color(0xFFDC2626);
        icon = Icons.cancel_rounded;
        break;
    }

    Timer? autoDismissTimer;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      builder: (ctx) {
        autoDismissTimer = Timer(const Duration(milliseconds: 2500), () {
          if (ctx.mounted) Navigator.of(ctx).pop();
        });

        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: bg.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: bg, size: 34),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: bg,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF475569),
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (route != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Route: $route',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    ).whenComplete(() {
      autoDismissTimer?.cancel();
      // Ready for next student
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Camera Feed ──
          MobileScanner(
            controller: _scannerController,
            onDetect: (capture) {
              final barcodes = capture.barcodes;
              if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
                _handleScan(barcodes.first.rawValue!);
              }
            },
          ),

          // ── Dark HUD Overlay with Viewfinder Reticle ──
          SafeArea(
            child: Column(
              children: [
                // Top App Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                        onPressed: () => context.pop(),
                      ),
                      const Text(
                        'Driver Scanner HUD',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          _torchEnabled ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                          color: _torchEnabled ? const Color(0xFFFBBF24) : Colors.white,
                        ),
                        onPressed: () {
                          _scannerController.toggleTorch();
                          setState(() => _torchEnabled = !_torchEnabled);
                        },
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Viewfinder Reticle Box with Animated Laser Sweep
                Center(
                  child: Container(
                    width: 270,
                    height: 270,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white30, width: 1.5),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Stack(
                      children: [
                        // Reticle Corners
                        const _ReticleCorner(alignment: Alignment.topLeft),
                        const _ReticleCorner(alignment: Alignment.topRight),
                        const _ReticleCorner(alignment: Alignment.bottomLeft),
                        const _ReticleCorner(alignment: Alignment.bottomRight),

                        // Animated Laser Line
                        AnimatedBuilder(
                          animation: _laserController,
                          builder: (context, child) {
                            return Positioned(
                              top: _laserController.value * 250,
                              left: 10,
                              right: 10,
                              child: Container(
                                height: 2.5,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00E5FF),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF00E5FF).withValues(alpha: 0.8),
                                      blurRadius: 10,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),
                const Text(
                  'Align QR code inside frame',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const Spacer(),

                // Switch Camera Button
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: IconButton(
                    iconSize: 32,
                    icon: const Icon(Icons.flip_camera_ios_rounded, color: Colors.white70),
                    onPressed: () => _scannerController.switchCamera(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _ScanStatus { success, warning, error }

class _ReticleCorner extends StatelessWidget {
  final Alignment alignment;
  const _ReticleCorner({required this.alignment});

  @override
  Widget build(BuildContext context) {
    final isTop = alignment == Alignment.topLeft || alignment == Alignment.topRight;
    final isLeft = alignment == Alignment.topLeft || alignment == Alignment.bottomLeft;

    return Align(
      alignment: alignment,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          border: Border(
            top: isTop ? const BorderSide(color: Color(0xFF00E5FF), width: 3.5) : BorderSide.none,
            bottom: !isTop ? const BorderSide(color: Color(0xFF00E5FF), width: 3.5) : BorderSide.none,
            left: isLeft ? const BorderSide(color: Color(0xFF00E5FF), width: 3.5) : BorderSide.none,
            right: !isLeft ? const BorderSide(color: Color(0xFF00E5FF), width: 3.5) : BorderSide.none,
          ),
        ),
      ),
    );
  }
}
