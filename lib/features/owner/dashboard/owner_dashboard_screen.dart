import 'package:cambus_connect_app/features/auth/auth_controller.dart';
import 'package:cambus_connect_app/features/owner/owner_providers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class OwnerDashboardScreen extends ConsumerStatefulWidget {
  const OwnerDashboardScreen({super.key});

  @override
  ConsumerState<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends ConsumerState<OwnerDashboardScreen> {
  bool _showRegisterModal = false;

  // Form controllers
  final _nameCtrl = TextEditingController();
  final _domainCtrl = TextEditingController();
  final _adminEmailCtrl = TextEditingController();
  final _subEndCtrl = TextEditingController();
  final _apiKeyCtrl = TextEditingController();
  final _projectIdCtrl = TextEditingController();
  final _authDomainCtrl = TextEditingController();
  final _dbUrlCtrl = TextEditingController();
  final _storageBucketCtrl = TextEditingController();
  final _senderIdCtrl = TextEditingController();
  final _appIdCtrl = TextEditingController();
  final _measurementIdCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _domainCtrl.dispose();
    _adminEmailCtrl.dispose();
    _subEndCtrl.dispose();
    _apiKeyCtrl.dispose();
    _projectIdCtrl.dispose();
    _authDomainCtrl.dispose();
    _dbUrlCtrl.dispose();
    _storageBucketCtrl.dispose();
    _senderIdCtrl.dispose();
    _appIdCtrl.dispose();
    _measurementIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _registerTenant() async {
    if (_nameCtrl.text.trim().isEmpty || _domainCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('College name and domain are required.')),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('tenants').add({
        'name': _nameCtrl.text.trim(),
        'domain': _domainCtrl.text.trim(),
        'adminEmail': _adminEmailCtrl.text.trim(),
        'subscriptionEnd': _subEndCtrl.text.trim(),
        'status': 'active',
        'projectId': _projectIdCtrl.text.trim(),
        'firebaseConfig': {
          'apiKey': _apiKeyCtrl.text.trim(),
          'authDomain': _authDomainCtrl.text.trim(),
          'databaseURL': _dbUrlCtrl.text.trim(),
          'storageBucket': _storageBucketCtrl.text.trim(),
          'messagingSenderId': _senderIdCtrl.text.trim(),
          'appId': _appIdCtrl.text.trim(),
          'measurementId': _measurementIdCtrl.text.trim(),
        },
        'registeredAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        setState(() => _showRegisterModal = false);
        _clearForm();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('College registered successfully!'),
            backgroundColor: Color(0xFF2E7D32),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _clearForm() {
    _nameCtrl.clear();
    _domainCtrl.clear();
    _adminEmailCtrl.clear();
    _subEndCtrl.clear();
    _apiKeyCtrl.clear();
    _projectIdCtrl.clear();
    _authDomainCtrl.clear();
    _dbUrlCtrl.clear();
    _storageBucketCtrl.clear();
    _senderIdCtrl.clear();
    _appIdCtrl.clear();
    _measurementIdCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).value;
    final tenantsAsync = ref.watch(tenantsProvider);
    final statsAsync = ref.watch(ownerStatsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FC),
      body: Stack(
        children: [
          Column(
            children: [
              // Top Bar
              Container(
                color: const Color(0xFF0F172A),
                padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
                child: Container(
                  height: 64,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFF4F46E5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.admin_panel_settings_rounded,
                            color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('CAMBUS CONNECT',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 1.5)),
                          Text('Owner Dashboard',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.indigo[300],
                                  letterSpacing: 1.5)),
                        ],
                      ),
                      const Spacer(),
                      // User info
                      Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFF334155)),
                            ),
                            child: Center(
                              child: Text('O',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: Colors.indigo[300])),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(user?.name ?? 'Owner',
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Body
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Tenant Directory',
                                  style: TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F172A))),
                              const SizedBox(height: 4),
                              Text(
                                'Configure and monitor registered colleges',
                                style: TextStyle(
                                    fontSize: 13, color: Colors.grey[500]),
                              ),
                            ],
                          ),
                          ElevatedButton.icon(
                            onPressed: () =>
                                setState(() => _showRegisterModal = true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4F46E5),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Register College',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 13)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Metrics Grid
                      statsAsync.when(
                        data: (stats) => Row(
                          children: [
                            _metricCard(Icons.school_rounded,
                                'Total Institutes', '${stats.totalTenants}',
                                iconColor: const Color(0xFF4F46E5),
                                iconBg: const Color(0xFFEEF2FF)),
                            const SizedBox(width: 12),
                            _metricCard(Icons.check_circle_rounded,
                                'Active Tenants', '${stats.activeTenants}',
                                iconColor: const Color(0xFF16A34A),
                                iconBg: const Color(0xFFF0FDF4)),
                            const SizedBox(width: 12),
                            _metricCard(Icons.pending_rounded,
                                'Suspended', '${stats.suspendedTenants}',
                                iconColor: const Color(0xFFD97706),
                                iconBg: const Color(0xFFFFFBEB)),
                            const SizedBox(width: 12),
                            _metricCard(Icons.dns_rounded, 'DB Status', '',
                                iconColor: const Color(0xFF7C3AED),
                                iconBg: const Color(0xFFF5F3FF),
                                trailing: Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF22C55E),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    const Text('Connected',
                                        style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF16A34A))),
                                  ],
                                )),
                          ],
                        ),
                        loading: () => const Center(
                            child: CircularProgressIndicator(strokeWidth: 2)),
                        error: (err, stack) => const SizedBox.shrink(),
                      ),
                      const SizedBox(height: 24),

                      // Tenants Table
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          children: [
                            // Table Header
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 16),
                              decoration: const BoxDecoration(
                                color: Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(20)),
                                border: Border(
                                    bottom: BorderSide(
                                        color: Color(0xFFE2E8F0))),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('REGISTERED TENANTS',
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF64748B),
                                          letterSpacing: 1)),
                                  tenantsAsync.when(
                                    data: (t) => Text(
                                        'Showing ${t.length} tenants',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF94A3B8))),
                                    loading: () => const SizedBox.shrink(),
                                    error: (err, stack) =>
                                        const SizedBox.shrink(),
                                  ),
                                ],
                              ),
                            ),

                            // Table Body
                            tenantsAsync.when(
                              data: (tenants) {
                                if (tenants.isEmpty) {
                                  return Padding(
                                    padding: const EdgeInsets.all(40),
                                    child: Column(
                                      children: [
                                        Icon(Icons.school_outlined,
                                            size: 48,
                                            color: Colors.grey[300]),
                                        const SizedBox(height: 12),
                                        Text('No tenants registered yet.',
                                            style: TextStyle(
                                                color: Colors.grey[400],
                                                fontSize: 14)),
                                      ],
                                    ),
                                  );
                                }

                                return Column(
                                  children: tenants
                                      .map((t) => _tenantRow(t))
                                      .toList(),
                                );
                              },
                              loading: () => const Padding(
                                padding: EdgeInsets.all(40),
                                child: Center(
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2)),
                              ),
                              error: (e, _) => Padding(
                                padding: const EdgeInsets.all(40),
                                child: Center(
                                    child: Text('Error: $e',
                                        style: const TextStyle(
                                            color: Colors.red))),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Logout
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              ref.read(authControllerProvider.notifier).logout(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF450A0A).withValues(alpha: 0.4),
                            foregroundColor: const Color(0xFFEF4444),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(
                                  color: Color(0xFF7F1D1D), width: 0.5),
                            ),
                          ),
                          icon: const Icon(Icons.logout_rounded, size: 18),
                          label: const Text('Sign Out',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 13)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Register Modal
          if (_showRegisterModal) _buildRegisterModal(),
        ],
      ),
    );
  }

  Widget _metricCard(IconData icon, String label, String value,
      {required Color iconColor,
      required Color iconBg,
      Widget? trailing}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF94A3B8),
                          letterSpacing: 0.5)),
                  const SizedBox(height: 4),
                  trailing ??
                      Text(value,
                          style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tenantRow(TenantModel tenant) {
    final isActive = tenant.status == 'active';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Row(
        children: [
          // Name
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.school_rounded,
                      color: Color(0xFF4F46E5), size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tenant.name,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A)),
                          overflow: TextOverflow.ellipsis),
                      Text(tenant.domain,
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF94A3B8)),
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Project ID
          Expanded(
            flex: 2,
            child: Text(tenant.firebaseProjectId ?? '—',
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF64748B))),
          ),
          // Status
          Expanded(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isActive
                    ? const Color(0xFFF0FDF4)
                    : const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                tenant.status.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isActive
                      ? const Color(0xFF16A34A)
                      : const Color(0xFFD97706),
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          // Subscription End
          Expanded(
            flex: 2,
            child: Text(
              tenant.subscriptionEnd != null
                  ? DateFormat('MMM d, yyyy').format(tenant.subscriptionEnd!)
                  : '—',
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterModal() {
    return GestureDetector(
      onTap: () => setState(() => _showRegisterModal = false),
      child: Container(
        color: const Color(0xFF0F172A).withValues(alpha: 0.6),
        child: Center(
          child: GestureDetector(
            onTap: () {}, // prevent close on modal tap
            child: Container(
              margin: const EdgeInsets.all(24),
              constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Modal Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF8FAFC),
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(24)),
                      border: Border(
                          bottom: BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Register New College',
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F172A))),
                            Text(
                                'Add tenant subdomain and database configuration',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey[400])),
                          ],
                        ),
                        IconButton(
                          onPressed: () =>
                              setState(() => _showRegisterModal = false),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),

                  // Form
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                  child: _formField(
                                      'College Name *', _nameCtrl,
                                      hint: 'e.g. Indore Institute')),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: _formField(
                                      'Subdomain/Domain *', _domainCtrl,
                                      hint: 'e.g. iist.cambusconnect.in')),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                  child: _formField(
                                      'Admin Email *', _adminEmailCtrl,
                                      hint: 'e.g. admin@iist.in')),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: _formField(
                                      'Subscription End *', _subEndCtrl,
                                      hint: 'YYYY-MM-DD')),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Text('FIREBASE CONFIG PARAMETERS',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.indigo[600],
                                  letterSpacing: 0.8)),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                  child: _formField(
                                      'API Key *', _apiKeyCtrl,
                                      hint: 'AIzaSy...')),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: _formField(
                                      'Project ID *', _projectIdCtrl,
                                      hint: 'e.g. cambus-medicaps')),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                  child: _formField(
                                      'Auth Domain *', _authDomainCtrl,
                                      hint: 'project.firebaseapp.com')),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: _formField(
                                      'Database URL *', _dbUrlCtrl,
                                      hint: 'https://...')),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                  child: _formField(
                                      'Storage Bucket *', _storageBucketCtrl,
                                      hint: 'project.firebasestorage.app')),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: _formField(
                                      'Messaging Sender ID *', _senderIdCtrl,
                                      hint: '560938631277')),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                  child: _formField('App ID *', _appIdCtrl,
                                      hint: '1:560938...:web:...')),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: _formField(
                                      'Measurement ID', _measurementIdCtrl,
                                      hint: 'G-9JD5KC...')),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Actions
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => setState(
                                      () => _showRegisterModal = false),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                  ),
                                  child: const Text('Cancel',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _registerTenant,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF4F46E5),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                  ),
                                  child: const Text('Register Tenant',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _formField(String label, TextEditingController controller,
      {String hint = ''}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF475569))),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }
}
