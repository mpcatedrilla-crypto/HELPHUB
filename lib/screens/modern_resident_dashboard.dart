import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../providers/admin_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/report_provider.dart';
import 'resident_announcements_screen.dart';

class ModernResidentDashboard extends StatefulWidget {
  const ModernResidentDashboard({super.key});

  @override
  State<ModernResidentDashboard> createState() =>
      _ModernResidentDashboardState();
}

class _ModernResidentDashboardState extends State<ModernResidentDashboard> {
  static const _blue = Color(0xFF075EB8);
  static const _cyan = Color(0xFF55D8DD);
  static const _purple = Color(0xFF2400B8);
  static const _red = Color(0xFFFF313C);
  static const _ink = Color(0xFF111111);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    await Future.wait([
      context.read<ReportProvider>().fetchMyReports(),
      context.read<AdminProvider>().fetchAnnouncements(),
      context.read<ProfileProvider>().loadProfile(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final reports = context.watch<ReportProvider>();
    final admin = context.watch<AdminProvider>();
    final profile = context.watch<ProfileProvider>();

    return Scaffold(
      backgroundColor: Colors.white,
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: _blue,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: CustomPaint(
                  painter: const _DashboardBackgroundPainter(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _DashboardHeader(
                        profile: profile,
                        onNotifications: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ResidentAnnouncementsScreen(),
                          ),
                        ),
                        onProfile: () =>
                            Navigator.pushNamed(context, '/profile'),
                      ),
                      _WelcomeCard(
                        name: _firstName(profile.fullName, auth.userName),
                      ),
                      const SizedBox(height: 25),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 34),
                        child: GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 2,
                          crossAxisSpacing: 7,
                          mainAxisSpacing: 10,
                          childAspectRatio: 1.87,
                          children:
                              [
                                    _ActionCard(
                                      title: 'Report Concern',
                                      subtitle: 'Submit a new concern',
                                      icon: Icons.assignment_add,
                                      onTap: () => Navigator.pushNamed(
                                        context,
                                        '/report_concern',
                                      ),
                                    ),
                                    _ActionCard(
                                      title: 'My Reports',
                                      subtitle: 'View submitted concerns',
                                      icon: Icons.fact_check_outlined,
                                      badge: reports.activeReportsCount,
                                      onTap: () => Navigator.pushNamed(
                                        context,
                                        '/report_tracking',
                                      ),
                                    ),
                                    _ActionCard(
                                      title: 'Announcements',
                                      subtitle: 'View latest updates',
                                      icon: Icons.campaign_outlined,
                                      badge: admin.announcements.length,
                                      onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const ResidentAnnouncementsScreen(),
                                        ),
                                      ),
                                    ),
                                    _ActionCard(
                                      title: 'Emergency SOS',
                                      subtitle: 'Get immediate help',
                                      icon: Icons.sos_rounded,
                                      emergency: true,
                                      onTap: () => Navigator.pushNamed(
                                        context,
                                        '/emergency_sos',
                                      ),
                                    ),
                                  ]
                                  .animate(interval: 55.ms)
                                  .fade()
                                  .scale(begin: const Offset(.96, .96)),
                        ),
                      ),
                      const SizedBox(height: 15),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 27),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Recent Reports',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pushNamed(
                                context,
                                '/report_tracking',
                              ),
                              style: TextButton.styleFrom(
                                foregroundColor: _purple,
                                minimumSize: const Size(0, 30),
                                padding: EdgeInsets.zero,
                                textStyle: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              child: const Text('View all'),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(37, 0, 30, 34),
                        child: _recentReports(reports),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  String _firstName(String profileName, String? fallback) {
    final value = profileName == 'Resident'
        ? (fallback ?? 'Resident')
        : profileName;
    return value.trim().split(RegExp(r'\s+')).first;
  }

  Widget _recentReports(ReportProvider provider) {
    if (provider.isLoading && provider.myReports.isEmpty) {
      return Column(
        children: List.generate(4, (index) => const _ReportSkeleton()),
      );
    }
    if (provider.myReports.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: _blue.withValues(alpha: .25)),
        ),
        child: const Column(
          children: [
            Icon(Icons.inbox_outlined, color: _blue, size: 28),
            SizedBox(height: 5),
            Text(
              'No recent reports yet',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      );
    }
    return Column(
      children: provider.myReports.take(4).toList().asMap().entries.map((
        entry,
      ) {
        return _RecentReportCard(report: entry.value)
            .animate()
            .fade(delay: (entry.key * 70).ms)
            .slideX(begin: .05);
      }).toList(),
    );
  }
}

class _DashboardBackgroundPainter extends CustomPainter {
  const _DashboardBackgroundPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final top = Paint()
      ..shader = const LinearGradient(
        colors: [
          _ModernResidentDashboardState._cyan,
          _ModernResidentDashboardState._blue,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, 150));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, 105), top);
    const designFooterTop = 546.0;
    final bottom = Path()
      ..moveTo(0, designFooterTop)
      ..lineTo(size.width * .45, designFooterTop + 94)
      ..lineTo(size.width, designFooterTop + 94)
      ..lineTo(size.width, designFooterTop - 34)
      ..lineTo(size.width * .73, designFooterTop + 22)
      ..close();
    canvas.drawPath(bottom, top);
    canvas.drawRect(
      Rect.fromLTWH(0, designFooterTop + 93, size.width, size.height),
      top,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({
    required this.profile,
    required this.onNotifications,
    required this.onProfile,
  });
  final ProfileProvider profile;
  final VoidCallback onNotifications;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 105,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Image.asset(
                'assets/images/helphub_crest.png',
                width: 60,
                height: 62,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
              const Spacer(),
              IconButton(
                onPressed: onNotifications,
                icon: const Icon(
                  Icons.notifications_rounded,
                  color: _ModernResidentDashboardState._purple,
                ),
              ),
              IconButton(
                onPressed: onProfile,
                tooltip: 'Your profile',
                icon: CircleAvatar(
                  radius: 13,
                  backgroundColor: _ModernResidentDashboardState._purple,
                  backgroundImage: profile.avatarUrl == null
                      ? null
                      : NetworkImage(profile.avatarUrl!),
                  child: profile.avatarUrl == null
                      ? const Icon(
                          Icons.person_rounded,
                          color: Colors.white,
                          size: 18,
                        )
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 88,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.fromLTRB(14, 17, 14, 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2600B7), Color(0xFF2200CB)],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome, $name!',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Manage your concern and stay updated',
                  style: TextStyle(color: Colors.white, fontSize: 11),
                ),
              ],
            ),
          ),
          Image.asset(
            'assets/images/community_line_art.png',
            width: 92,
            height: 70,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
        ],
      ),
    ).animate().fade().slideY(begin: -.08);
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.emergency = false,
    this.badge = 0,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool emergency;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final color = emergency
        ? _ModernResidentDashboardState._red
        : _ModernResidentDashboardState._purple;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color, width: 1.8),
          ),
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: color, size: emergency ? 33 : 35),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 9),
                    ),
                  ],
                ),
              ),
              if (badge > 0)
                Positioned(
                  right: 6,
                  top: 5,
                  child: CircleAvatar(
                    radius: 8,
                    backgroundColor: color,
                    child: Text(
                      badge > 9 ? '9+' : '$badge',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 7,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentReportCard extends StatelessWidget {
  const _RecentReportCard({required this.report});
  final Map<String, dynamic> report;

  @override
  Widget build(BuildContext context) {
    final status = (report['status'] ?? 'submitted').toString();
    final statusData = _status(status);
    return Container(
      height: 49,
      margin: const EdgeInsets.only(bottom: 5),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _ModernResidentDashboardState._ink),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (report['title'] ?? 'Community concern').toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  (report['concern_types']?['category_name'] ?? 'Report')
                      .toString(),
                  style: const TextStyle(fontSize: 8, color: Colors.black54),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
            decoration: BoxDecoration(
              border: Border.all(color: statusData.$1),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(
              statusData.$2,
              style: TextStyle(
                color: statusData.$1,
                fontSize: 7,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  (Color, String) _status(String status) {
    switch (status) {
      case 'resolved':
        return (const Color(0xFF42B649), 'RESOLVED');
      case 'in_progress':
      case 'responding':
        return (const Color(0xFFF0B323), 'IN PROGRESS');
      case 'acknowledged':
      case 'pending_confirmation':
        return (const Color(0xFFFF7043), 'UNDER REVIEW');
      default:
        return (_ModernResidentDashboardState._purple, 'SUBMITTED');
    }
  }
}

class _ReportSkeleton extends StatelessWidget {
  const _ReportSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
          height: 49,
          margin: const EdgeInsets.only(bottom: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFE9EEF5),
            borderRadius: BorderRadius.circular(10),
          ),
        )
        .animate(onPlay: (controller) => controller.repeat(reverse: true))
        .fade(begin: .45, end: .9, duration: 650.ms);
  }
}
