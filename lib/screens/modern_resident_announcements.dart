import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../providers/admin_provider.dart';

class ModernResidentAnnouncements extends StatefulWidget {
  const ModernResidentAnnouncements({super.key});

  @override
  State<ModernResidentAnnouncements> createState() =>
      _ModernResidentAnnouncementsState();
}

class _ModernResidentAnnouncementsState
    extends State<ModernResidentAnnouncements> {
  static const blue = Color(0xFF075EB8);
  static const cyan = Color(0xFF55D8DD);
  static const purple = Color(0xFF2400B8);
  static const ink = Color(0xFF111111);

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    await context.read<AdminProvider>().fetchAnnouncements();
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: blue,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final height = constraints.maxHeight < 640
              ? 640.0
              : constraints.maxHeight;
          final page = SizedBox(
            height: height,
            child: CustomPaint(
              painter: const _AnnouncementBackgroundPainter(),
              child: Column(
                children: [
                  const _BrandHeader(),
                  const _TitleBanner(),
                  Expanded(child: _announcementList()),
                  const SizedBox(height: 60),
                ],
              ),
            ),
          );
          return Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomLeft,
                end: Alignment.topRight,
                colors: [cyan, blue],
              ),
            ),
            child: constraints.maxHeight < 640
                ? SingleChildScrollView(primary: false, child: page)
                : page,
          );
        },
      ),
    );
  }

  Widget _announcementList() {
    return Consumer<AdminProvider>(
      builder: (context, provider, _) {
        if (_loading && provider.announcements.isEmpty) {
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(38, 25, 33, 12),
            itemCount: 3,
            itemBuilder: (_, _) => const _SkeletonCard(),
          );
        }
        if (provider.announcements.isEmpty) {
          return RefreshIndicator(
            color: purple,
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(38, 34, 33, 12),
              children: const [_EmptyAnnouncements()],
            ),
          );
        }
        return RefreshIndicator(
          color: purple,
          onRefresh: _refresh,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(38, 25, 33, 16),
            itemCount: provider.announcements.length,
            itemBuilder: (context, index) {
              final announcement = provider.announcements[index];
              final style = _severity(announcement['severity']?.toString());
              return _AnnouncementCard(
                    announcement: announcement,
                    severity: style,
                    onTap: () => _openAnnouncement(announcement, style),
                  )
                  .animate()
                  .fade(delay: (index * 55).ms, duration: 280.ms)
                  .slideY(begin: .08, end: 0);
            },
          ),
        );
      },
    );
  }

  _SeverityStyle _severity(String? severity) {
    switch ((severity ?? 'info').toLowerCase()) {
      case 'critical':
        return const _SeverityStyle('CRITICAL', Color(0xFFFF343F));
      case 'warning':
        return const _SeverityStyle('WARNING', Color(0xFFF39422));
      default:
        return const _SeverityStyle('COMMUNITY UPDATE', purple);
    }
  }

  void _openAnnouncement(
    Map<String, dynamic> announcement,
    _SeverityStyle severity,
  ) {
    final title = _text(announcement['title'], 'Announcement');
    final message = _text(
      announcement['message'],
      'No additional details were provided.',
    );
    final author = _text(
      announcement['profiles']?['full_name'],
      'Barangay Administrator',
    );
    final created = DateTime.tryParse(
      announcement['created_at']?.toString() ?? '',
    )?.toLocal();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: .58,
        minChildSize: .4,
        maxChildSize: .9,
        expand: false,
        builder: (context, controller) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: SingleChildScrollView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(24, 10, 24, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 22),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD4D7DC),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: severity.color.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    Icons.campaign_rounded,
                    color: severity.color,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  severity.label,
                  style: TextStyle(
                    color: severity.color,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .7,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  style: const TextStyle(
                    color: ink,
                    fontSize: 22,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  created == null
                      ? 'Posted by $author'
                      : 'Posted ${timeago.format(created)} by $author',
                  style: const TextStyle(
                    color: Color(0xFF70757C),
                    fontSize: 12,
                  ),
                ),
                const Divider(height: 34),
                Text(
                  message,
                  style: const TextStyle(
                    color: Color(0xFF2B2E33),
                    fontSize: 15,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: purple,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Close',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _text(dynamic value, String fallback) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? fallback : text;
  }
}

class _AnnouncementBackgroundPainter extends CustomPainter {
  const _AnnouncementBackgroundPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final gradient = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
        colors: [
          _ModernResidentAnnouncementsState.cyan,
          _ModernResidentAnnouncementsState.blue,
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, gradient);
    final footerTop = size.height - 60;
    final lowerCorner = footerTop - 98;
    final white = Path()
      ..moveTo(size.width * .23, 148)
      ..lineTo(size.width, 148)
      ..lineTo(size.width, lowerCorner)
      ..lineTo(size.width * .76, footerTop)
      ..lineTo(size.width * .19, footerTop)
      ..lineTo(0, lowerCorner)
      ..lineTo(0, 218)
      ..close();
    canvas.drawPath(white, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 116,
      child: SafeArea(
        bottom: false,
        child: Center(
          child: Image.asset(
            'assets/images/helphub_crest.png',
            width: 67,
            height: 72,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
        ),
      ),
    );
  }
}

class _TitleBanner extends StatelessWidget {
  const _TitleBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: _ModernResidentAnnouncementsState.purple,
        borderRadius: BorderRadius.circular(15),
      ),
      alignment: Alignment.center,
      child: const Text(
        'Announcements',
        style: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  const _AnnouncementCard({
    required this.announcement,
    required this.severity,
    required this.onTap,
  });

  final Map<String, dynamic> announcement;
  final _SeverityStyle severity;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = _ModernResidentAnnouncementsState._text(
      announcement['title'],
      'Community announcement',
    );
    final message = _ModernResidentAnnouncementsState._text(
      announcement['message'],
      'Tap to read this announcement.',
    );
    final created = DateTime.tryParse(
      announcement['created_at']?.toString() ?? '',
    )?.toLocal();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            constraints: const BoxConstraints(minHeight: 112),
            padding: const EdgeInsets.fromLTRB(13, 12, 13, 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: severity.color, width: 1.2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: severity.color.withValues(alpha: .1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.campaign_rounded,
                        color: severity.color,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _ModernResidentAnnouncementsState.ink,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            message,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF666A70),
                              fontSize: 11,
                              height: 1.25,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        created == null ? '' : timeago.format(created),
                        style: const TextStyle(
                          color: Color(0xFF85898F),
                          fontSize: 9,
                        ),
                      ),
                    ),
                    Text(
                      'View this announcement',
                      style: TextStyle(
                        color: severity.color,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: severity.color,
                      size: 14,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyAnnouncements extends StatelessWidget {
  const _EmptyAnnouncements();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _ModernResidentAnnouncementsState.purple),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.campaign_outlined,
            color: _ModernResidentAnnouncementsState.purple,
            size: 40,
          ),
          SizedBox(height: 12),
          Text(
            'No active announcements',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 5),
          Text(
            'Barangay updates and advisories will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
          height: 112,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F2F5),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFD6D9DE)),
          ),
        )
        .animate(onPlay: (controller) => controller.repeat(reverse: true))
        .fade(begin: .45, end: .9, duration: 650.ms);
  }
}

class _SeverityStyle {
  const _SeverityStyle(this.label, this.color);

  final String label;
  final Color color;
}
