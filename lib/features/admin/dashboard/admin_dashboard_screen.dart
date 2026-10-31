import 'package:cambus_connect_app/features/admin/admin_providers.dart';
import 'package:cambus_connect_app/features/auth/auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).value;
    final statsAsync = ref.watch(adminStatsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FF),
      body: CustomScrollView(
        slivers: [
          // ── Header ──────────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            backgroundColor: const Color(0xFF0037B0),
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                icon: const Icon(Icons.logout_rounded),
                tooltip: 'Sign Out',
                onPressed: () => ref.read(authControllerProvider.notifier).logout(),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF0037B0), Color(0xFF0052FF)],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 32),
                        Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.admin_panel_settings_rounded,
                                  color: Colors.white, size: 24),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Welcome back,',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.75),
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  user?.name ?? 'Admin',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFD761A).withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Administrator · Cambus Connect',
                            style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Body ────────────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // KPI Stats
                const Text(
                  'Overview',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1D29),
                  ),
                ),
                const SizedBox(height: 12),

                statsAsync.when(
                  loading: () => const _StatsShimmer(),
                  error: (e, _) => _StatsGrid(
                    stats: const AdminStats(
                      totalStudents: 0,
                      activePasses: 0,
                      totalBuses: 0,
                      totalNotifications: 0,
                    ),
                  ),
                  data: (stats) => _StatsGrid(stats: stats),
                ),

                const SizedBox(height: 28),

                // Quick Actions
                const Text(
                  'Quick Actions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1D29),
                  ),
                ),
                const SizedBox(height: 12),

                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.15,
                  children: [
                    _ActionTile(
                      icon: Icons.people_alt_rounded,
                      label: 'Students',
                      subtitle: 'Manage & Search',
                      color: const Color(0xFF0037B0),
                      onTap: () => context.push('/admin/students'),
                    ),
                    _ActionTile(
                      icon: Icons.directions_bus_rounded,
                      label: 'Buses',
                      subtitle: 'Routes & Fleet',
                      color: const Color(0xFF006C47),
                      onTap: () => context.push('/student/buses'),
                    ),
                    _ActionTile(
                      icon: Icons.map_rounded,
                      label: 'Live Tracking',
                      subtitle: 'Bus Locations',
                      color: const Color(0xFFFD761A),
                      onTap: () => context.push('/student/track'),
                    ),
                    _ActionTile(
                      icon: Icons.notifications_active_rounded,
                      label: 'Notifications',
                      subtitle: 'Broadcast',
                      color: const Color(0xFF6750A4),
                      onTap: () => context.push('/student/notifications'),
                    ),
                    _ActionTile(
                      icon: Icons.qr_code_scanner_rounded,
                      label: 'Scan Pass',
                      subtitle: 'Verify Students',
                      color: const Color(0xFF00796B),
                      onTap: () => context.push('/admin/scan'),
                    ),
                    _ActionTile(
                      icon: Icons.support_agent_rounded,
                      label: 'Support',
                      subtitle: 'Help Requests',
                      color: const Color(0xFFB00020),
                      onTap: () => context.push('/support'),
                    ),
                  ],
                ),

                const SizedBox(height: 20),
                // Hidden Import Button
                GestureDetector(
                  onDoubleTap: () async {
                    // Import dummy students logic
                    final firestore = FirebaseFirestore.instance;
                    final batch = firestore.batch();
                    
                    final dummyData = [
                      {'studentId':'IIST23001','collegeId':'IIST-BLR','name':'Aarav Patel','email':'aarav.p@student.iist.ac.in','branch':'Computer Science','year':'2nd Year','assignedRoute':'Route A (City Center)','boardingStop':'MG Road Metro','emergencyPhone':'9876543210','passStatus':'active','role':'student'},
                      {'studentId':'IIST23002','collegeId':'IIST-BLR','name':'Aditi Sharma','email':'aditi.s@student.iist.ac.in','branch':'Computer Science','year':'2nd Year','assignedRoute':'Route A (City Center)','boardingStop':'Brigade Road','emergencyPhone':'9876543211','passStatus':'active','role':'student'},
                      {'studentId':'IIST22015','collegeId':'IIST-BLR','name':'Rohan Kumar','email':'rohan.k@student.iist.ac.in','branch':'Electronics','year':'3rd Year','assignedRoute':'Route B (North Campus)','boardingStop':'Hebbal Flyover','emergencyPhone':'9876543212','passStatus':'pending','role':'student'},
                      {'studentId':'IIST22016','collegeId':'IIST-BLR','name':'Sneha Gupta','email':'sneha.g@student.iist.ac.in','branch':'Mechanical','year':'3rd Year','assignedRoute':'Route C (South Zone)','boardingStop':'Silk Board','emergencyPhone':'9876543213','passStatus':'active','role':'student'},
                      {'studentId':'IIST24005','collegeId':'IIST-BLR','name':'Vikram Singh','email':'vikram.s@student.iist.ac.in','branch':'Civil','year':'1st Year','assignedRoute':'Route A (City Center)','boardingStop':'MG Road Metro','emergencyPhone':'9876543214','passStatus':'pending','role':'student'},
                      {'studentId':'IIST24006','collegeId':'IIST-BLR','name':'Pooja Verma','email':'pooja.v@student.iist.ac.in','branch':'Computer Science','year':'1st Year','assignedRoute':'Route D (East End)','boardingStop':'Indiranagar','emergencyPhone':'9876543215','passStatus':'active','role':'student'},
                      {'studentId':'IIST21045','collegeId':'IIST-BLR','name':'Karan Desai','email':'karan.d@student.iist.ac.in','branch':'Information Tech','year':'4th Year','assignedRoute':'Route B (North Campus)','boardingStop':'Yelahanka','emergencyPhone':'9876543216','passStatus':'active','role':'student'},
                      {'studentId':'IIST21046','collegeId':'IIST-BLR','name':'Neha Reddy','email':'neha.r@student.iist.ac.in','branch':'Electronics','year':'4th Year','assignedRoute':'Route C (South Zone)','boardingStop':'BTM Layout','emergencyPhone':'9876543217','passStatus':'expired','role':'student'},
                      {'studentId':'IIST23088','collegeId':'IIST-BLR','name':'Arjun Nair','email':'arjun.n@student.iist.ac.in','branch':'Mechanical','year':'2nd Year','assignedRoute':'Route D (East End)','boardingStop':'Whitefield','emergencyPhone':'9876543218','passStatus':'active','role':'student'},
                      {'studentId':'IIST23089','collegeId':'IIST-BLR','name':'Ananya Rao','email':'ananya.r@student.iist.ac.in','branch':'Civil','year':'2nd Year','assignedRoute':'Route A (City Center)','boardingStop':'Shivajinagar','emergencyPhone':'9876543219','passStatus':'active','role':'student'}
                    ];

                    for (var s in dummyData) {
                      final docRef = firestore.collection('users').doc(s['studentId']);
                      batch.set(docRef, {
                        ...s,
                        'createdAt': DateTime.now().toIso8601String(),
                        'passValidity': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
                      });
                    }

                    try {
                      await batch.commit();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Imported dummy students successfully!')),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error importing: $e')),
                        );
                      }
                    }
                  },
                  child: Container(
                    height: 50,
                    color: Colors.transparent,
                    child: const Center(
                      child: Text('Version 1.0.0', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stats Grid ───────────────────────────────────────────────────────────────

class _StatsGrid extends StatelessWidget {
  final AdminStats stats;
  const _StatsGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.3,
      children: [
        _StatCard(
          label: 'Total Students',
          value: stats.totalStudents.toString(),
          icon: Icons.school_rounded,
          color: const Color(0xFF0037B0),
        ),
        _StatCard(
          label: 'Active Passes',
          value: stats.activePasses.toString(),
          icon: Icons.credit_card_rounded,
          color: const Color(0xFF006C47),
        ),
        _StatCard(
          label: 'Total Buses',
          value: stats.totalBuses.toString(),
          icon: Icons.directions_bus_rounded,
          color: const Color(0xFFFD761A),
        ),
        _StatCard(
          label: 'Notifications',
          value: stats.totalNotifications.toString(),
          icon: Icons.notifications_rounded,
          color: const Color(0xFF6750A4),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Action Tile ───────────────────────────────────────────────────────────────

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1D29),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Shimmer Loading ───────────────────────────────────────────────────────────

class _StatsShimmer extends StatelessWidget {
  const _StatsShimmer();

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.3,
      children: List.generate(
        4,
        (_) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      ),
    );
  }
}
