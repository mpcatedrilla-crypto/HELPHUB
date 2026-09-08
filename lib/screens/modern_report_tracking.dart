import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../models/report_status.dart';
import '../providers/report_provider.dart';

class ModernReportTracking extends StatefulWidget {
  const ModernReportTracking({super.key});

  @override
  State<ModernReportTracking> createState() => _ModernReportTrackingState();
}

class _ModernReportTrackingState extends State<ModernReportTracking> {
  static const _blue = Color(0xFF075EB8);
  static const _cyan = Color(0xFF55D8DD);
  static const _purple = Color(0xFF2400B8);
  static const _ink = Color(0xFF111111);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReportProvider>().fetchMyReports();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _blue,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final designHeight = constraints.maxHeight < 640
              ? 640.0
              : constraints.maxHeight;
          final canvas = SizedBox(
            height: designHeight,
            child: CustomPaint(
              painter: const _ReportsBackgroundPainter(),
              child: Column(
                children: [
                  const _ReportsBrandHeader(),
                  const _ReportsTitleCard(),
                  Expanded(child: _reportsPanel()),
                  const SizedBox(height: 88),
                ],
              ),
            ),
          );
          return Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomLeft,
                end: Alignment.topRight,
                colors: [_cyan, _blue],
              ),
            ),
            child: constraints.maxHeight < 640
                ? SingleChildScrollView(primary: false, child: canvas)
                : canvas,
          );
        },
      ),
    );
  }

  Widget _reportsPanel() {
    return Consumer<ReportProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading && provider.myReports.isEmpty) {
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(33, 23, 33, 12),
            itemCount: 3,
            itemBuilder: (_, index) => const _ReportSkeleton(),
          );
        }

        if (provider.myReports.isEmpty) {
          return RefreshIndicator(
            color: _purple,
            onRefresh: provider.fetchMyReports,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(33, 38, 33, 12),
              children: const [_ReportsEmptyState()],
            ),
          );
        }

        return RefreshIndicator(
          color: _purple,
          onRefresh: provider.fetchMyReports,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(33, 23, 33, 12),
            itemCount: provider.myReports.length,
            itemBuilder: (context, index) {
              final report = provider.myReports[index];
              final status = _reportStatus(report['status']?.toString());
              final categoryName =
                  report['concern_types']?['category_name']?.toString() ??
                  'Community report';
              return _ReportRow(
                    report: report,
                    status: status,
                    onTap: () => _showReportDetails(
                      context,
                      report,
                      status,
                      categoryName,
                    ),
                  )
                  .animate()
                  .fade(delay: (index * 55).ms, duration: 260.ms)
                  .slideY(begin: .08, end: 0);
            },
          ),
        );
      },
    );
  }

  _StatusStyle _reportStatus(String? rawStatus) {
    final status = ReportStatus.fromDatabase(rawStatus);
    final color = switch (status) {
      ReportStatus.resolved => const Color(0xFF4DB848),
      ReportStatus.acknowledged => const Color(0xFFFF7B3A),
      ReportStatus.inProgress => const Color(0xFFF2B72D),
      ReportStatus.referred => const Color(0xFF0891B2),
      ReportStatus.falseAlarm => const Color(0xFFCE5A0A),
      ReportStatus.closed => const Color(0xFF64748B),
      ReportStatus.archived => const Color(0xFF475569),
      ReportStatus.submitted => const Color(0xFF3217E6),
    };
    return _StatusStyle(status.label, color);
  }

  void _showReportDetails(
    BuildContext context,
    Map<String, dynamic> report,
    _StatusStyle status,
    String categoryName,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: .58,
          minChildSize: .42,
          maxChildSize: .9,
          expand: false,
          builder: (context, controller) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(24, 10, 24, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD2D6DC),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            report['title']?.toString() ?? 'Report details',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        _StatusPill(status: status),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      categoryName,
                      style: const TextStyle(color: Colors.black54),
                    ),
                    const Divider(height: 32),
                    const Text(
                      'Description',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      report['description']?.toString() ??
                          'No description provided.',
                    ),
                    const Divider(height: 32),
                    Row(
                      children: [
                        Expanded(
                          child: _DetailItem(
                            label: 'Score',
                            value: '${report['priority_score'] ?? 0}',
                            color: _blue,
                          ),
                        ),
                        Expanded(
                          child: _DetailItem(
                            label: 'Status',
                            value: status.label,
                            color: status.color,
                          ),
                        ),
                        Expanded(
                          child: _DetailItem(
                            label: 'Urgency',
                            value:
                                '${report['resident_declared_urgency'] ?? 0}/5',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.pop(context),
                        style: FilledButton.styleFrom(
                          backgroundColor: _purple,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(46),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('Close'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ReportsBackgroundPainter extends CustomPainter {
  const _ReportsBackgroundPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final gradient = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
        colors: [
          _ModernReportTrackingState._cyan,
          _ModernReportTrackingState._blue,
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, gradient);

    final footerTop = size.height - 88;
    final lowerCorner = footerTop - 98;
    final white = Path()
      ..moveTo(size.width * .23, 146)
      ..lineTo(size.width, 146)
      ..lineTo(size.width, lowerCorner)
      ..lineTo(size.width * .76, footerTop)
      ..lineTo(size.width * .19, footerTop)
      ..lineTo(0, lowerCorner - 1)
      ..lineTo(0, 245)
      ..close();
    canvas.drawPath(white, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ReportsBrandHeader extends StatelessWidget {
  const _ReportsBrandHeader();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 144,
      child: SafeArea(
        bottom: false,
        child: Center(
          child: Image.asset(
            'assets/images/helphub_crest.png',
            width: 72,
            height: 76,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
        ),
      ),
    );
  }
}

class _ReportsTitleCard extends StatelessWidget {
  const _ReportsTitleCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 68,
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 11),
      decoration: BoxDecoration(
        color: _ModernReportTrackingState._purple,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'My Reports',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'View all reports submitted',
            style: TextStyle(color: Colors.white, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _ReportRow extends StatelessWidget {
  const _ReportRow({
    required this.report,
    required this.status,
    required this.onTap,
  });

  final Map<String, dynamic> report;
  final _StatusStyle status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = report['title']?.toString().trim();
    final description = report['description']?.toString().trim();
    final category = report['concern_types']?['category_name']
        ?.toString()
        .trim();
    final date = _formatDate(report['created_at']?.toString());

    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 76,
            padding: const EdgeInsets.fromLTRB(12, 9, 8, 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _ModernReportTrackingState._ink),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title?.isNotEmpty == true ? title! : 'Untitled report',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _ModernReportTrackingState._ink,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _StatusPill(status: status),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  description?.isNotEmpty == true
                      ? description!
                      : 'No description provided.',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFF666A70), fontSize: 9),
                ),
                const Spacer(),
                Row(
                  children: [
                    const Icon(
                      Icons.sell_outlined,
                      size: 10,
                      color: _ModernReportTrackingState._purple,
                    ),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        category?.isNotEmpty == true
                            ? category!
                            : 'Community report',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF666A70),
                          fontSize: 8,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (date != null) ...[
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.schedule_rounded,
                        size: 10,
                        color: Color(0xFF777B80),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        date,
                        style: const TextStyle(
                          color: Color(0xFF777B80),
                          fontSize: 8,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _formatDate(String? rawDate) {
    if (rawDate == null || rawDate.isEmpty) return null;
    final parsed = DateTime.tryParse(rawDate)?.toLocal();
    if (parsed == null) return null;
    final month = parsed.month.toString().padLeft(2, '0');
    final day = parsed.day.toString().padLeft(2, '0');
    return '$month/$day/${parsed.year}';
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final _StatusStyle status;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 19),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: status.color),
      ),
      child: Text(
        status.label,
        style: const TextStyle(
          color: _ModernReportTrackingState._ink,
          fontSize: 6.5,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _ReportsEmptyState extends StatelessWidget {
  const _ReportsEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _ModernReportTrackingState._ink),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.assignment_outlined,
            color: _ModernReportTrackingState._purple,
            size: 31,
          ),
          SizedBox(height: 7),
          Text(
            'No reports submitted yet',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 3),
          Text(
            'Your submitted reports will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 9, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

class _ReportSkeleton extends StatelessWidget {
  const _ReportSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
          height: 76,
          margin: const EdgeInsets.only(bottom: 7),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F2F5),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFD7DADE)),
          ),
        )
        .animate(onPlay: (controller) => controller.repeat(reverse: true))
        .fade(begin: .45, end: .9, duration: 650.ms);
  }
}

class _DetailItem extends StatelessWidget {
  const _DetailItem({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.black54),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: color ?? _ModernReportTrackingState._ink,
          ),
        ),
      ],
    );
  }
}

class _StatusStyle {
  const _StatusStyle(this.label, this.color);

  final String label;
  final Color color;
}
