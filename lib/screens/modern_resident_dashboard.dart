import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../models/report_status.dart';
import '../providers/admin_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/report_provider.dart';
import 'modern_resident_announcements.dart';

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
    final profile = context.read<ProfileProvider>();
    await Future.wait([
      profile.loadProfile(),
      context.read<AdminProvider>().fetchAnnouncements(),
    ]);
    if (!mounted) return;
    if (profile.isVerified) {
      await context.read<ReportProvider>().fetchMyReports();
    } else {
      context.read<ReportProvider>().clearMyReports();
    }
  }

  void _openProtectedFeature(
    ProfileProvider profile,
    String route,
    String featureName,
  ) {
    if (profile.isVerified) {
      Navigator.pushNamed(context, route);
      return;
    }
    final isSos = route == '/emergency_sos';
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        icon: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: (isSos ? _red : _purple).withValues(alpha: .1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isSos ? Icons.sos_rounded : Icons.lock_person_outlined,
            color: isSos ? _red : _purple,
            size: 34,
          ),
        ),
        title: Text(
          isSos ? 'SOS is locked' : '$featureName is locked',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        content: Text(
          isSos
              ? 'You cannot use Emergency SOS until your resident account has been verified. Please submit or check your verification request in your profile.'
              : 'You cannot open $featureName until your resident account has been verified. Please submit or check your verification request in your profile.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.black54, height: 1.45),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _purple,
                    side: const BorderSide(color: _purple),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Close'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    Navigator.pushNamed(context, '/profile');
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: _purple,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('View Profile'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
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
                            builder: (_) => const ModernResidentAnnouncements(),
                          ),
                        ),
                        onProfile: () =>
                            Navigator.pushNamed(context, '/profile'),
                      ),
                      _WelcomeCard(
                        name: _firstName(profile.fullName, auth.userName),
                        isVerified: profile.isVerified,
                      ),
                      if (!profile.isVerified)
                        _DashboardVerificationBanner(
                          onTap: () => Navigator.pushNamed(context, '/profile'),
                        ),
                      const SizedBox(height: 22),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: constraints.maxWidth < 360
                              ? 1.12
                              : 1.25,
                          children:
                              [
                                    _ActionCard(
                                      title: 'Report Concern',
                                      subtitle: 'Submit a new concern',
                                      icon: Icons.assignment_add,
                                      locked: !profile.isVerified,
                                      onTap: () => _openProtectedFeature(
                                        profile,
                                        '/report_concern',
                                        'Report Concern',
                                      ),
                                    ),
                                    _ActionCard(
                                      title: 'My Reports',
                                      subtitle: 'View submitted concerns',
                                      icon: Icons.fact_check_outlined,
                                      badge: reports.totalReportsCount,
                                      locked: !profile.isVerified,
                                      onTap: () => _openProtectedFeature(
                                        profile,
                                        '/report_tracking',
                                        'My Reports',
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
                                              const ModernResidentAnnouncements(),
                                        ),
                                      ),
                                    ),
                                    _ActionCard(
                                      title: 'Emergency SOS',
                                      subtitle: 'Get immediate help',
                                      icon: Icons.sos_rounded,
                                      emergency: true,
                                      locked: !profile.isVerified,
                                      onTap: () => _openProtectedFeature(
                                        profile,
                                        '/emergency_sos',
                                        'Emergency SOS',
                                      ),
                                    ),
                                  ]
                                  .animate(interval: 55.ms)
                                  .fade()
                                  .scale(begin: const Offset(.96, .96)),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Recent Reports',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: _ink,
                              ),
                            ),
                            TextButton(
                              onPressed: () => _openProtectedFeature(
                                profile,
                                '/report_tracking',
                                'My Reports',
                              ),
                              style: TextButton.styleFrom(
                                foregroundColor: _purple,
                                minimumSize: const Size(0, 38),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('View all'),
                                  SizedBox(width: 2),
                                  Icon(Icons.arrow_forward_rounded, size: 15),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 128),
                        child: profile.isVerified
                            ? _recentReports(reports)
                            : const _VerificationNotice(),
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
    final designFooterTop = size.height > 640 ? size.height - 94 : 546.0;
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
      height: 112,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 16, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                children: [
                  Image.asset(
                    'assets/images/helphub_crest.png',
                    width: 54,
                    height: 58,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                  const SizedBox(width: 8),
                  const Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'HelpHub',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -.3,
                        ),
                      ),
                      Text(
                        'Resident portal',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const Spacer(),
              _HeaderCircleButton(
                onTap: onNotifications,
                child: const Icon(
                  Icons.notifications_none_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Semantics(
                button: true,
                label: 'Your profile',
                child: InkWell(
                  onTap: onProfile,
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.white,
                      backgroundImage: profile.avatarUrl == null
                          ? const AssetImage(
                              'assets/images/default_resident_avatar.png',
                            )
                          : NetworkImage(profile.avatarUrl!),
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

class _HeaderCircleButton extends StatelessWidget {
  const _HeaderCircleButton({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: .16),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(width: 42, height: 42, child: Center(child: child)),
      ),
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({required this.name, required this.isVerified});
  final String name;
  final bool isVerified;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 112,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.fromLTRB(18, 18, 12, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2600B7), Color(0xFF2200CB)],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2400B8).withValues(alpha: .24),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
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
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Stay informed. Report concerns.\nHelp keep your community safe.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    Icon(
                      isVerified
                          ? Icons.verified_rounded
                          : Icons.schedule_rounded,
                      color: isVerified
                          ? const Color(0xFF67E8F9)
                          : Colors.white70,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isVerified
                          ? 'Verified resident'
                          : 'Verification required',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Image.asset(
            'assets/images/community_line_art.png',
            width: 98,
            height: 82,
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
    this.locked = false,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool emergency;
  final int badge;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final color = emergency
        ? _ModernResidentDashboardState._red
        : _ModernResidentDashboardState._purple;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: emergency ? const Color(0xFFFFF6F6) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withValues(alpha: .55), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: .10),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: .10),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(icon, color: color, size: 27),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: emergency ? color : const Color(0xFF121A2B),
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (badge > 0)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 23,
                      minHeight: 23,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      badge > 99 ? '99+' : '$badge',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              if (locked)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    width: 25,
                    height: 25,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lock_rounded,
                      color: Colors.white,
                      size: 14,
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

class _DashboardVerificationBanner extends StatelessWidget {
  const _DashboardVerificationBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Material(
        color: const Color(0xFFF2F7FF),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF075EB8).withValues(alpha: .18),
              ),
            ),
            child: const Row(
              children: [
                CircleAvatar(
                  radius: 19,
                  backgroundColor: Color(0xFFE0ECFF),
                  child: Icon(
                    Icons.verified_user_outlined,
                    color: Color(0xFF075EB8),
                    size: 21,
                  ),
                ),
                SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Complete your verification',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Unlock reports and Emergency SOS',
                        style: TextStyle(
                          color: Color(0xFF667085),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: Color(0xFF075EB8)),
              ],
            ),
          ),
        ),
      ),
    ).animate().fade().slideY(begin: -.08);
  }
}

class _VerificationNotice extends StatelessWidget {
  const _VerificationNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF2400B8).withValues(alpha: .3),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D2400B8),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: const Row(
        children: [
          Icon(Icons.verified_user_outlined, color: Color(0xFF2400B8)),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Your recent reports will appear here after your account is verified.',
              style: TextStyle(
                fontSize: 11,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
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
    final category =
        (report['concern_types']?['category_name'] ?? 'Community report')
            .toString();
    final title = (report['title'] ?? report['description'] ?? category)
        .toString();
    return Container(
      constraints: const BoxConstraints(minHeight: 74),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F0F2765),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: statusData.$1.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.description_outlined,
              color: statusData.$1,
              size: 22,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF182230),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  category,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF667085),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: statusData.$1.withValues(alpha: .08),
              border: Border.all(color: statusData.$1.withValues(alpha: .55)),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(
              statusData.$2,
              style: TextStyle(
                color: statusData.$1,
                fontSize: 8,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  (Color, String) _status(String status) {
    final reportStatus = ReportStatus.fromDatabase(status);
    final color = switch (reportStatus) {
      ReportStatus.resolved => const Color(0xFF42B649),
      ReportStatus.inProgress => const Color(0xFFF0B323),
      ReportStatus.acknowledged => const Color(0xFFFF7043),
      ReportStatus.referred => const Color(0xFF0891B2),
      ReportStatus.falseAlarm => const Color(0xFFCE5A0A),
      ReportStatus.closed => const Color(0xFF64748B),
      ReportStatus.archived => const Color(0xFF475569),
      ReportStatus.submitted => _ModernResidentDashboardState._purple,
    };
    return (color, reportStatus.label);
  }
}

class _ReportSkeleton extends StatelessWidget {
  const _ReportSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
          height: 74,
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFE9EEF5),
            borderRadius: BorderRadius.circular(16),
          ),
        )
        .animate(onPlay: (controller) => controller.repeat(reverse: true))
        .fade(begin: .45, end: .9, duration: 650.ms);
  }
}
