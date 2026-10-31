import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cambus_connect_app/features/auth/auth_controller.dart';
import 'package:cambus_connect_app/features/driver/driver_providers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class DriverDashboardScreen extends ConsumerStatefulWidget {
  const DriverDashboardScreen({super.key});

  @override
  ConsumerState<DriverDashboardScreen> createState() => _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends ConsumerState<DriverDashboardScreen> {
  int _selectedTab = 0;
  bool _isTracking = false;
  StreamSubscription<Position>? _positionStream;
  Timer? _durationTimer;
  DateTime? _shiftStartTime;
  double _lat = 0.0;
  double _lng = 0.0;
  double _accuracy = 0.0;
  int _headcount = 0;
  String _shiftDuration = '00:00:00';
  String _alertMessage = '';
  String _alertType = 'alert';

  // Telemetry write throttling & battery preservation
  DateTime? _lastFirestoreLocationUpdate;
  Position? _lastRecordedPosition;

  @override
  void dispose() {
    _stopTracking();
    _durationTimer?.cancel();
    super.dispose();
  }

  Future<void> _startTracking() async {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      final result = await Geolocator.requestPermission();
      if (result == LocationPermission.denied || result == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission is required for GPS tracking.')),
          );
        }
        return;
      }
    }

    setState(() {
      _isTracking = true;
      _shiftStartTime = DateTime.now();
    });

    // Start duration timer
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_shiftStartTime != null && mounted) {
        final diff = DateTime.now().difference(_shiftStartTime!);
        setState(() {
          _shiftDuration = _formatDuration(diff);
        });
      }
    });

    // Start GPS stream with Android Foreground Service settings
    LocationSettings locationSettings;
    if (defaultTargetPlatform == TargetPlatform.android) {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 20,
        intervalDuration: const Duration(seconds: 12),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'CamBus Driver Live Tracking',
          notificationText: 'Broadcasting real-time bus location to students',
          notificationIcon: AndroidResource(name: 'ic_launcher'),
          enableWakeLock: true,
        ),
      );
    } else {
      locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 20,
      );
    }

    _positionStream = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((position) {
      if (mounted) {
        setState(() {
          _lat = position.latitude;
          _lng = position.longitude;
          _accuracy = position.accuracy;
        });

        // Update Firestore with live location
        _updateFirestoreLocation(position);
      }
    });

    // Create shift session in Firestore (harmonized with 'driverSessions')
    final user = ref.read(authControllerProvider).value;
    final driverProfile = ref.read(driverProfileProvider).value;
    if (user != null) {
      FirebaseFirestore.instance.collection('driverSessions').add({
        'driverEmail': user.email,
        'startTime': FieldValue.serverTimestamp(),
        'busId': driverProfile?.assignedBusId ?? '',
        'busNumber': driverProfile?.assignedBusNumber ?? 'Bus',
        'route': driverProfile?.assignedRoute ?? 'Route',
        'status': 'active',
      });
    }
  }

  void _stopTracking() {
    _positionStream?.cancel();
    _positionStream = null;
    _durationTimer?.cancel();
    _durationTimer = null;
    _lastFirestoreLocationUpdate = null;
    _lastRecordedPosition = null;
    if (mounted) {
      setState(() {
        _isTracking = false;
        _shiftStartTime = null;
        _shiftDuration = '00:00:00';
      });
    }
  }

  Future<void> _updateFirestoreLocation(Position position) async {
    final driverProfile = ref.read(driverProfileProvider).value;
    final busId = driverProfile?.assignedBusId?.trim();
    if (busId == null || busId.isEmpty || busId.toLowerCase() == 'not assigned') return;

    final now = DateTime.now();
    // Throttle: minimum 10 seconds between Firestore writes, unless displacement > 20m
    if (_lastFirestoreLocationUpdate != null && _lastRecordedPosition != null) {
      final elapsedMs =
          now.difference(_lastFirestoreLocationUpdate!).inMilliseconds;
      final distanceMoved = Geolocator.distanceBetween(
        _lastRecordedPosition!.latitude,
        _lastRecordedPosition!.longitude,
        position.latitude,
        position.longitude,
      );

      // Skip database write if under 10 seconds AND moved less than 20 meters
      if (elapsedMs < 10000 && distanceMoved < 20.0) {
        return;
      }
    }

    _lastFirestoreLocationUpdate = now;
    _lastRecordedPosition = position;

    try {
      await FirebaseFirestore.instance
          .collection('buses')
          .doc(busId)
          .update({
        'latitude': position.latitude,
        'longitude': position.longitude,
        'location': {
          'lat': position.latitude,
          'lng': position.longitude,
        },
        'speed': position.speed * 3.6, // m/s to km/h
        'heading': position.heading,
        'accuracy': position.accuracy,
        'lastUpdated': FieldValue.serverTimestamp(),
        'lastGpsUpdate': FieldValue.serverTimestamp(),
        'locationSource': 'driver_app',
        'status': 'On Route',
      });
    } catch (e) {
      debugPrint('Error updating bus location: $e');
    }
  }

  Future<void> _sendAlert() async {
    if (_alertMessage.trim().isEmpty) return;

    final user = ref.read(authControllerProvider).value;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance.collection('notifications').add({
        'title': _getAlertTitle(_alertType),
        'message': _alertMessage.trim(),
        'type': _alertType,
        'senderEmail': user.email,
        'senderRole': 'driver',
        'targetAudience': 'students',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        setState(() => _alertMessage = '');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Alert broadcast successfully!'),
            backgroundColor: Color(0xFF2E7D32),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send alert: $e')),
        );
      }
    }
  }

  String _getAlertTitle(String type) {
    switch (type) {
      case 'delay':
        return '⚠️ Route Delay';
      case 'crowd':
        return '👥 Heavy Rush';
      default:
        return '🚨 Route Alert';
    }
  }

  String _formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).value;
    final driverProfileAsync = ref.watch(driverProfileProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F7),
      body: Column(
        children: [
          // Top Bar
          Container(
            color: Colors.white,
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFE8EAF0))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.directions_bus_filled_rounded,
                          color: Color(0xFFE65100), size: 24),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Cambus Connect',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1A1A2E))),
                          Text('Driver Terminal',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[500])),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.qr_code_scanner_rounded,
                            color: Color(0xFF2563EB), size: 22),
                        tooltip: 'Scan Student Pass',
                        onPressed: () => context.push('/driver/scan'),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: _isTracking
                              ? const Color(0xFFE8F5E9)
                              : const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _isTracking
                                    ? const Color(0xFF43A047)
                                    : const Color(0xFF9CA3AF),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _isTracking ? 'Tracking' : 'Idle',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _isTracking
                                    ? const Color(0xFF2E7D32)
                                    : const Color(0xFF9CA3AF),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Body
          Expanded(
            child: IndexedStack(
              index: _selectedTab,
              children: [
                _buildDashboardTab(user, driverProfileAsync),
                _buildAlertsTab(),
                _buildProfileTab(user, driverProfileAsync),
              ],
            ),
          ),

          // Bottom Nav
          Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE8EAF0))),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  _buildNavItem(0, Icons.dashboard_rounded, 'Dashboard'),
                  _buildNavItem(1, Icons.notifications_rounded, 'Alerts'),
                  _buildNavItem(2, Icons.account_circle_rounded, 'Profile'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isActive = _selectedTab == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedTab = index),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 22,
                  color: isActive
                      ? const Color(0xFFE65100)
                      : const Color(0xFF9CA3AF)),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  color: isActive
                      ? const Color(0xFFE65100)
                      : const Color(0xFF9CA3AF),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // DASHBOARD TAB
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildDashboardTab(dynamic user, AsyncValue<DriverProfile?> profileAsync) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting
          Text(
            'Hello, ${user?.name ?? 'Driver'}!',
            style: const TextStyle(
                fontSize: 28, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E)),
          ),
          const SizedBox(height: 4),
          Text(
            DateFormat('MMMM d, yyyy').format(DateTime.now()),
            style: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
          ),
          const SizedBox(height: 20),

          // GPS Tracking Card + Driver Info
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // GPS Tracking Card
              Expanded(
                flex: 3,
                child: _buildCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.satellite_alt_rounded,
                                  color: Colors.grey[400], size: 18),
                              const SizedBox(width: 8),
                              const Text('GPS Tracking',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1A1A2E))),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _isTracking
                                  ? const Color(0xFFE8F5E9)
                                  : const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _isTracking
                                        ? const Color(0xFF43A047)
                                        : const Color(0xFF9CA3AF),
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  _isTracking ? 'Active' : 'Inactive',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: _isTracking
                                        ? const Color(0xFF2E7D32)
                                        : const Color(0xFF9CA3AF),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Broadcast live location to transit controllers and student apps.',
                        style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                      ),
                      const SizedBox(height: 14),

                      // Signal Area
                      Container(
                        height: 120,
                        decoration: BoxDecoration(
                          color: _isTracking
                              ? const Color(0xFFE8F5E9)
                              : const Color(0xFFF0F2F7),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.satellite_alt_rounded,
                                size: 40,
                                color: _isTracking
                                    ? const Color(0xFF2E7D32)
                                    : Colors.grey[400],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _isTracking
                                    ? 'Transmitting: High Accuracy'
                                    : 'Signal Ready: High Accuracy',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: _isTracking
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: _isTracking
                                      ? const Color(0xFF388E3C)
                                      : Colors.grey[400],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Start / Stop Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed:
                              _isTracking ? _stopTracking : _startTracking,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isTracking
                                ? const Color(0xFFE53935)
                                : const Color(0xFFF5A623),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: Icon(_isTracking
                              ? Icons.stop_rounded
                              : Icons.play_arrow_rounded),
                          label: Text(
                            _isTracking
                                ? 'Stop GPS Tracking'
                                : 'Start GPS Tracking',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Driver Info Card
              Expanded(
                flex: 2,
                child: _buildCard(
                  child: Column(
                    children: [
                      _infoRow(Icons.person_rounded, 'Logged Email',
                          user?.email ?? 'Loading...'),
                      const Divider(height: 24),
                      _infoRow(Icons.school_rounded, 'Institute',
                          profileAsync.value?.collegeName ?? 'Loading...'),
                      const Divider(height: 24),
                      _infoRow(Icons.verified_rounded, 'Status', 'VERIFIED',
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: const Text('VERIFIED',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF2E7D32))),
                          )),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Stats Row
          Row(
            children: [
              _buildStatCard('Latitude', _lat.toStringAsFixed(4)),
              const SizedBox(width: 12),
              _buildStatCard('Longitude', _lng.toStringAsFixed(4)),
              const SizedBox(width: 12),
              _buildStatCard('Accuracy', '${_accuracy.toStringAsFixed(0)} m'),
              const SizedBox(width: 12),
              _buildStatCard('Duration', _shiftDuration),
            ],
          ),
          const SizedBox(height: 16),

          // Headcount Card
          _buildCard(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.people_alt_rounded,
                            size: 18, color: Color(0xFF9CA3AF)),
                        const SizedBox(width: 8),
                        const Text('Live Headcount',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1A1A2E))),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('Cap: 50',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue[700])),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _headcountBtn(Icons.remove, () {
                      if (_headcount > 0) setState(() => _headcount--);
                    }),
                    const SizedBox(width: 24),
                    Text(
                      '$_headcount',
                      style: const TextStyle(
                          fontSize: 52,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1A2E)),
                    ),
                    const SizedBox(width: 24),
                    _headcountBtn(Icons.add, () {
                      if (_headcount < 50) setState(() => _headcount++);
                    }),
                  ],
                ),
                const SizedBox(height: 8),
                Text('CURRENT PASSENGERS',
                    style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 1.5,
                        color: Colors.grey[400])),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // ALERTS TAB
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildAlertsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Route Announcements',
              style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A2E))),
          const SizedBox(height: 4),
          Text(
            'Broadcast route alerts to students and check system notices.',
            style: TextStyle(fontSize: 13, color: Colors.grey[400]),
          ),
          const SizedBox(height: 20),

          // Broadcast Alert Card
          _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.campaign_rounded,
                        color: Color(0xFFF5A623), size: 18),
                    const SizedBox(width: 8),
                    const Text('Broadcast Route Alert',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A1A2E))),
                  ],
                ),
                const SizedBox(height: 16),

                Text('Alert Type',
                    style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFE8EAF0)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _alertType,
                      isExpanded: true,
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF1A1A2E)),
                      items: const [
                        DropdownMenuItem(
                            value: 'alert',
                            child: Text('🚨 Route Consolidation / Merge')),
                        DropdownMenuItem(
                            value: 'delay',
                            child: Text('⚠️ Route Delay / Traffic')),
                        DropdownMenuItem(
                            value: 'crowd',
                            child: Text('👥 Heavy Rush / Extra Bus')),
                      ],
                      onChanged: (val) =>
                          setState(() => _alertType = val ?? 'alert'),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                Text('Message to Students',
                    style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                const SizedBox(height: 6),
                TextField(
                  maxLines: 4,
                  onChanged: (v) => _alertMessage = v,
                  decoration: InputDecoration(
                    hintText: 'Type your broadcast message here...',
                    hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: Color(0xFFE8EAF0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: Color(0xFFE8EAF0)),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
                const SizedBox(height: 14),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _sendAlert,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.send_rounded, size: 17),
                    label: const Text('Broadcast Alert',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Recent Alerts
          _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.history_rounded,
                        size: 18, color: Color(0xFF9CA3AF)),
                    const SizedBox(width: 8),
                    const Text('Recent System Notices',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A1A2E))),
                  ],
                ),
                const SizedBox(height: 14),
                _buildRecentNotifications(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentNotifications() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .orderBy('createdAt', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('No recent notices.',
                  style: TextStyle(color: Colors.grey[400], fontSize: 13)),
            ),
          );
        }

        return Column(
          children: snapshot.data!.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final ts = (data['createdAt'] as Timestamp?)?.toDate();
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 16, color: Color(0xFF9CA3AF)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(data['title'] ?? 'Notice',
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1A1A2E))),
                        Text(data['message'] ?? '',
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF6B7280)),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  if (ts != null)
                    Text(DateFormat('MMM d').format(ts),
                        style: const TextStyle(
                            fontSize: 10, color: Color(0xFF9CA3AF))),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // PROFILE TAB
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildProfileTab(dynamic user, AsyncValue<DriverProfile?> profileAsync) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('My Profile',
              style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A2E))),
          const SizedBox(height: 20),

          _buildCard(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: const Color(0xFF263238),
                  child: Text(
                    (user?.name ?? 'D')[0].toUpperCase(),
                    style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: Colors.white),
                  ),
                ),
                const SizedBox(height: 16),
                Text(user?.name ?? 'Driver',
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A2E))),
                const SizedBox(height: 4),
                Text(user?.email ?? '',
                    style: const TextStyle(
                        fontSize: 13, color: Color(0xFF9CA3AF))),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: const Text('VERIFIED',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF2E7D32))),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3E0),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: const Text('DRIVER',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFE65100))),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          _buildCard(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.school_rounded,
                      color: Color(0xFF0037B0)),
                  title: const Text('Institute',
                      style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))),
                  subtitle: Text(
                      profileAsync.value?.collegeName ?? 'Cambus Connect',
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A2E))),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.directions_bus_rounded,
                      color: Color(0xFFF5A623)),
                  title: const Text('Assigned Bus',
                      style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))),
                  subtitle: Text(
                      profileAsync.value?.assignedBusNumber ?? 'Not assigned',
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A2E))),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.route_rounded,
                      color: Color(0xFF006C47)),
                  title: const Text('Active Route',
                      style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))),
                  subtitle: Text(
                      profileAsync.value?.assignedRoute ?? 'Not assigned',
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A2E))),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () =>
                  ref.read(authControllerProvider.notifier).logout(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFF5F5),
                foregroundColor: const Color(0xFFE53935),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFFFED7D7)),
                ),
              ),
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: const Text('Sign Out',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8EAF0)),
      ),
      child: child,
    );
  }

  Widget _buildStatCard(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE8EAF0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(fontSize: 11, color: Colors.grey[400])),
            const SizedBox(height: 6),
            Text(value,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A2E))),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value,
      {Widget? trailing}) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF263238),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(fontSize: 11, color: Colors.grey[400])),
              trailing ??
                  Text(value,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A2E)),
                      overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }

  Widget _headcountBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFE8EAF0), width: 1.5),
        ),
        child: Icon(icon, color: const Color(0xFF374151), size: 22),
      ),
    );
  }
}
