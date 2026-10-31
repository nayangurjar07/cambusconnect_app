import 'dart:convert';
import 'package:cambus_connect_app/features/student/student_providers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:intl/intl.dart';

class AdminScanPassScreen extends StatefulWidget {
  const AdminScanPassScreen({super.key});

  @override
  State<AdminScanPassScreen> createState() => _AdminScanPassScreenState();
}

class _AdminScanPassScreenState extends State<AdminScanPassScreen> {
  final MobileScannerController _scannerController = MobileScannerController();
  bool _isProcessing = false;
  Map<String, dynamic>? _lastScanResult;
  bool _lastScanValid = false;
  String _lastScanMessage = '';

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _handleScan(String scannedData) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      String lookupKey = scannedData.trim();
      String? totpToken;

      // 1. Parse JSON dynamic pass if present (matches web crypto.js generateTotpPayload)
      if (scannedData.trim().startsWith('{') && scannedData.trim().endsWith('}')) {
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

      // 2. Query Firestore by doc ID (students/{email})
      DocumentSnapshot? doc;
      final emailDoc = await firestore.collection('students').doc(cleanKey).get();
      if (emailDoc.exists) {
        doc = emailDoc;
      }

      // Fallback: query by studentId / collegeId
      if (doc == null || !doc.exists) {
        final queryId = await firestore
            .collection('students')
            .where('studentId', isEqualTo: lookupKey.trim())
            .limit(1)
            .get();
        if (queryId.docs.isNotEmpty) {
          doc = queryId.docs.first;
        }
      }

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
        final queryEmailField = await firestore
            .collection('students')
            .where('email', isEqualTo: cleanKey)
            .limit(1)
            .get();
        if (queryEmailField.docs.isNotEmpty) {
          doc = queryEmailField.docs.first;
        }
      }

      if (doc == null || !doc.exists) {
        setState(() {
          _lastScanResult = null;
          _lastScanValid = false;
          _lastScanMessage = 'Student pass not found for "$lookupKey".';
        });
        return;
      }

      final data = doc.data() as Map<String, dynamic>;

      // 3. Cryptographic Anti-Screenshot TOTP Verification
      if (totpToken != null) {
        final qrSecret = data['qrSecret'] as String?;
        if (qrSecret == null || qrSecret.isEmpty) {
          setState(() {
            _lastScanResult = data;
            _lastScanValid = false;
            _lastScanMessage = 'Pass Rejected: QR secret not provisioned.';
          });
          return;
        }

        if (!verifyTotp(totpToken, qrSecret)) {
          setState(() {
            _lastScanResult = data;
            _lastScanValid = false;
            _lastScanMessage = 'Pass Rejected: Expired or Forged QR token.';
          });
          return;
        }
      }

      // 4. Pass Validity Date Check (Handles Timestamp & ISO string)
      DateTime? validityDate;
      final rawValidity = data['passValidity'];
      if (rawValidity is Timestamp) {
        validityDate = rawValidity.toDate();
      } else if (rawValidity is String) {
        validityDate = DateTime.tryParse(rawValidity);
      }

      final isExpired = validityDate != null && validityDate.isBefore(DateTime.now());
      if (isExpired) {
        setState(() {
          _lastScanResult = data;
          _lastScanValid = false;
          _lastScanMessage =
              'Pass Expired on ${DateFormat('MMM d, yyyy').format(validityDate!)}';
        });
        return;
      }

      // 5. Pass Status Check (Active vs Inactive/Revoked)
      final status =
          (data['status'] ?? data['passStatus'] ?? 'Active').toString();
      final isActive = status.toLowerCase() == 'active';
      if (!isActive) {
        setState(() {
          _lastScanResult = data;
          _lastScanValid = false;
          _lastScanMessage = 'Pass Status: ${status.toUpperCase()}';
        });
        return;
      }

      // 6. Approved
      setState(() {
        _lastScanResult = data;
        _lastScanValid = true;
        _lastScanMessage =
            'Approved: ${data['name'] ?? 'Student'} (${data['busRoute'] ?? data['assignedRoute'] ?? 'Bus Pass'})';
      });
    } catch (e) {
      setState(() {
        _lastScanResult = null;
        _lastScanValid = false;
        _lastScanMessage = 'Scan verification error: $e';
      });
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Scan Pass',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          // Scanner
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                MobileScanner(
                  controller: _scannerController,
                  onDetect: (capture) {
                    final barcodes = capture.barcodes;
                    if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
                      _handleScan(barcodes.first.rawValue!);
                    }
                  },
                ),
                // Scan overlay
                Center(
                  child: Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _isProcessing
                            ? const Color(0xFFF59E0B)
                            : const Color(0xFF00E676),
                        width: 2.5,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
                // Status indicator
                Positioned(
                  top: 16,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _isProcessing
                            ? 'Verifying...'
                            : 'Point camera at student QR code',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 13),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Results Panel
          Expanded(
            flex: 2,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: _lastScanResult != null
                    ? _buildResultCard()
                    : _lastScanMessage.isNotEmpty
                        ? _buildErrorCard()
                        : _buildWaitingCard(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard() {
    final data = _lastScanResult!;
    DateTime? passValidity;
    final rawValidity = data['passValidity'];
    if (rawValidity is Timestamp) {
      passValidity = rawValidity.toDate();
    } else if (rawValidity is String) {
      passValidity = DateTime.tryParse(rawValidity);
    }

    return Column(
      children: [
        // Status
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _lastScanValid
                ? const Color(0xFFF0FDF4)
                : const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _lastScanValid
                  ? const Color(0xFF86EFAC)
                  : const Color(0xFFFECACA),
            ),
          ),
          child: Row(
            children: [
              Icon(
                _lastScanValid
                    ? Icons.check_circle_rounded
                    : Icons.cancel_rounded,
                color: _lastScanValid
                    ? const Color(0xFF16A34A)
                    : const Color(0xFFEF4444),
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _lastScanMessage,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _lastScanValid
                            ? const Color(0xFF16A34A)
                            : const Color(0xFFEF4444),
                      ),
                    ),
                    Text(
                      DateFormat('hh:mm:ss a').format(DateTime.now()),
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Student Info
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              _infoRow('Name', data['name'] ?? 'Unknown'),
              const Divider(height: 20),
              _infoRow('Student ID',
                  data['studentId'] ?? data['collegeId'] ?? data['enrollment'] ?? '—'),
              const Divider(height: 20),
              _infoRow('Branch', data['branch'] ?? '—'),
              const Divider(height: 20),
              _infoRow('Route',
                  data['busRoute'] ?? data['assignedRoute'] ?? 'Not Assigned'),
              if (data['assignedBusNumber'] != null || data['busNumber'] != null) ...[
                const Divider(height: 20),
                _infoRow('Bus Number',
                    (data['assignedBusNumber'] ?? data['busNumber']).toString()),
              ],
              if (passValidity != null) ...[
                const Divider(height: 20),
                _infoRow('Valid Until',
                    DateFormat('MMM d, yyyy').format(passValidity)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Scan Again
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _lastScanResult = null;
                _lastScanMessage = '';
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
            label: const Text('Scan Another',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 48, color: Color(0xFFEF4444)),
          const SizedBox(height: 12),
          Text(_lastScanMessage,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFEF4444)),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => setState(() => _lastScanMessage = ''),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildWaitingCard() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFBFDBFE)),
          ),
          child: const Icon(Icons.qr_code_scanner_rounded,
              size: 48, color: Color(0xFF2563EB)),
        ),
        const SizedBox(height: 20),
        const Text('Ready to Scan',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B))),
        const SizedBox(height: 8),
        Text(
          'Point your camera at a student\'s digital pass QR code to verify.',
          style: TextStyle(fontSize: 13, color: Colors.grey[500]),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500)),
        Text(value,
            style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF1E293B),
                fontWeight: FontWeight.w600)),
      ],
    );
  }
}
