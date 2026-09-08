import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter/material.dart';

import 'dart:io';

import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/report_status.dart';
import '../providers/report_provider.dart';
import '../providers/admin_provider.dart';
import '../theme/app_theme.dart';

import 'package:timeago/timeago.dart' as timeago;
import 'package:camera/camera.dart';

import 'admin_drawer.dart';
import 'camera_screen.dart';

enum _UrgencyFilter { all, high, medium, low }

class AdminPriorityQueue extends StatefulWidget {
  const AdminPriorityQueue({super.key});

  @override
  State<AdminPriorityQueue> createState() => _AdminPriorityQueueState();
}

class _AdminPriorityQueueState extends State<AdminPriorityQueue>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  _UrgencyFilter _selectedUrgency = _UrgencyFilter.all;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final reportProvider = Provider.of<ReportProvider>(
        context,
        listen: false,
      );
      final adminProvider = Provider.of<AdminProvider>(context, listen: false);

      reportProvider.fetchAllReports();

      adminProvider.startListeningForEmergencies(() {
        if (mounted) reportProvider.fetchAllReports();
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    Provider.of<AdminProvider>(
      context,
      listen: false,
    ).stopListeningForEmergencies();
    super.dispose();
  }

  Map<String, dynamic> _getBadgeInfo(Map<String, dynamic> r) {
    final score = _priorityScore(r);
    final isCritical = r['is_critical_override'] == true;
    Color badgeColor;
    String badgeText;
    String priorityLabel;

    if (isCritical || score > 80) {
      badgeColor = AppTheme.statusCritical;
      badgeText = 'CRITICAL';
      priorityLabel = 'Immediate danger or serious public safety concern';
    } else if (score > 60) {
      badgeColor = AppTheme.statusHigh;
      badgeText = 'HIGH';
      priorityLabel = 'Urgent concern requiring quick action';
    } else if (score > 30) {
      badgeColor = AppTheme.statusMedium;
      badgeText = 'MEDIUM';
      priorityLabel = 'Important concern, not an emergency';
    } else {
      badgeColor = AppTheme.statusLow;
      badgeText = 'LOW';
      priorityLabel = 'Routine or lower-urgency concern';
    }

    return {'color': badgeColor, 'text': badgeText, 'label': priorityLabel};
  }

  double _priorityScore(Map<String, dynamic> report) {
    final raw = report['priority_score'];
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw?.toString() ?? '') ?? 0;
  }

  bool _isCriticalReport(Map<String, dynamic> report) {
    return report['is_critical_override'] == true ||
        _priorityScore(report) > 80;
  }

  _UrgencyFilter _urgencyOf(Map<String, dynamic> report) {
    final score = _priorityScore(report);
    if (score > 60) return _UrgencyFilter.high;
    if (score > 30) return _UrgencyFilter.medium;
    return _UrgencyFilter.low;
  }

  String _reporterLabel(Map<String, dynamic> report) {
    final profile = report['profiles'];
    if (profile is Map) {
      final name = profile['full_name']?.toString().trim();
      final status = profile['status']?.toString();
      if (name != null && name.isNotEmpty) {
        return status == 'pending' ? '$name - Pending verification' : name;
      }
    }
    return report['resident_id'] == null
        ? 'Deleted resident account'
        : 'Resident profile unavailable';
  }

  String _shortReportId(dynamic value) {
    final id = value?.toString() ?? '';
    if (id.isEmpty) return 'UNASSIGNED';
    return id.substring(0, id.length.clamp(0, 8)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 68,
        titleSpacing: 4,
        title: Row(
          children: [
            SizedBox(
              width: 42,
              height: 42,
              child: Image.asset(
                'assets/images/helphub_crest.png',
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Priority queue'),
                  SizedBox(height: 2),
                  Text(
                    'Community response command',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: const [
          Center(child: _LiveBadge()),
          SizedBox(width: 16),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: const Color(0xFF79A8FF),
          indicatorWeight: 3,
          dividerColor: Colors.white12,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700),
          tabs: const [
            Tab(icon: Icon(Icons.dashboard, size: 18), text: 'All'),
            Tab(icon: Icon(Icons.emergency, size: 18), text: 'Emergencies'),
            Tab(icon: Icon(Icons.hourglass_top, size: 18), text: 'Active'),
            Tab(icon: Icon(Icons.check_circle, size: 18), text: 'Resolved'),
          ],
        ),
      ),
      drawer: const AdminDrawer(),
      body: Consumer<ReportProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.allReports.isEmpty) {
            return const _QueueSkeleton();
          }

          final allReports = provider.allReports;
          final nonCriticalReports = allReports
              .where((report) => !_isCriticalReport(report))
              .toList();
          final emergencyReports = allReports
              .where(
                (r) =>
                    _isCriticalReport(r) &&
                    ReportStatus.fromDatabase(r['status']).isActive,
              )
              .toList();
          final activeReports = allReports
              .where((r) => ReportStatus.fromDatabase(r['status']).isActive)
              .toList();
          final resolvedReports = allReports
              .where((r) => ReportStatus.fromDatabase(r['status']).isCompleted)
              .toList();

          return TabBarView(
            controller: _tabController,
            children: [
              _buildUrgencyReportList(nonCriticalReports, provider),
              _buildReportList(
                emergencyReports,
                provider,
                emptyMsg: 'No active emergencies',
                emptyDetail: 'Everything is calm. Critical SOS reports will surface here immediately.',
                emptyIcon: Icons.health_and_safety_rounded,
              ),
              _buildReportList(
                activeReports,
                provider,
                emptyMsg: 'No active reports',
                emptyDetail: 'There are no reports currently awaiting action.',
                emptyIcon: Icons.task_alt_rounded,
              ),
              _buildReportList(
                resolvedReports,
                provider,
                emptyMsg: 'No resolved reports yet',
                emptyDetail: 'Completed response cases will be collected here.',
                emptyIcon: Icons.inventory_2_rounded,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildUrgencyReportList(
    List<Map<String, dynamic>> reports,
    ReportProvider provider,
  ) {
    final filteredReports = _selectedUrgency == _UrgencyFilter.all
        ? reports
        : reports
              .where((report) => _urgencyOf(report) == _selectedUrgency)
              .toList();
    final selectedLabel = switch (_selectedUrgency) {
      _UrgencyFilter.all => 'reports',
      _UrgencyFilter.high => 'high-urgency reports',
      _UrgencyFilter.medium => 'medium-urgency reports',
      _UrgencyFilter.low => 'low-urgency reports',
    };

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: AppTheme.outline)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'FILTER BY URGENCY',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.7,
                ),
              ),
              const SizedBox(height: 9),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _UrgencyFilter.values.map((filter) {
                    final count = filter == _UrgencyFilter.all
                        ? reports.length
                        : reports
                              .where((report) => _urgencyOf(report) == filter)
                              .length;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _UrgencyChoice(
                        filter: filter,
                        count: count,
                        selected: _selectedUrgency == filter,
                        onTap: () => setState(() => _selectedUrgency = filter),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _buildReportList(
            filteredReports,
            provider,
            emptyMsg: 'No $selectedLabel',
            emptyDetail: _selectedUrgency == _UrgencyFilter.all
                ? 'New low, medium, and high urgency reports will appear here.'
                : 'Select another urgency or pull down to refresh the queue.',
            emptyIcon: Icons.filter_alt_off_rounded,
          ),
        ),
      ],
    );
  }

  Widget _buildReportList(
    List<Map<String, dynamic>> reports,
    ReportProvider provider, {
    required String emptyMsg,
    required String emptyDetail,
    required IconData emptyIcon,
  }) {
    return RefreshIndicator(
      onRefresh: provider.fetchAllReports,
      child: reports.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 28),
              children: [
                const SizedBox(height: 96),
                _EmptyQueueState(
                  icon: emptyIcon,
                  title: emptyMsg,
                  message: emptyDetail,
                ),
              ],
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              itemCount: reports.length,
              itemBuilder: (context, index) {
                final r = reports[index];
                final badge = _getBadgeInfo(r);
                final score = r['priority_score'] ?? 0;
                return _buildPriorityItem(
                      score.toString(),
                      r['title'] ?? 'No Title',
                      '#${_shortReportId(r['id'])} · ${_reporterLabel(r)}',
                      badge['text'],
                      badge['color'],
                      timeago.format(DateTime.parse(r['created_at'])),
                      reportId: r['id'],
                      provider: provider,
                      evidence: r['report_evidence'],
                      location: r['report_locations'],
                      priorityLabel: badge['label'],
                      currentStatus: r['status'] ?? 'submitted',
                      isEmergency: _isCriticalReport(r),
                    )
                    .animate()
                    .fadeIn(
                      duration: 260.ms,
                      delay: (index.clamp(0, 6) * 45).ms,
                    )
                    .slideY(begin: 0.06, end: 0, curve: Curves.easeOutCubic);
              },
            ),
    );
  }

  Widget _buildEmergencyCard(
    String name,
    String details,
    String phone,
    String time, {
    bool isCritical = false,
    required String reportId,
    required ReportProvider provider,
    List<dynamic>? evidence,
    dynamic location,
  }) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isCritical ? AppTheme.sosRed : Colors.grey.shade300,
          width: isCritical ? 1 : 0,
        ),
      ),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (isCritical) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.emergency, color: AppTheme.sosRed, size: 16)
                      .animate(
                        onPlay: (controller) =>
                            controller.repeat(reverse: true),
                      )
                      .scaleXY(end: 1.2, duration: 500.ms),
                  SizedBox(width: 8),
                  Text(
                    'CRITICAL - IMMEDIATE RESPONSE NEEDED',
                    style: TextStyle(
                      color: AppTheme.sosRed,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  backgroundColor: AppTheme.surfaceColor,
                  child: Icon(Icons.person, color: AppTheme.primaryBlue),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            time,
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        details,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (location != null) ...[
              const SizedBox(height: 8),
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => _FullScreenMapViewer(
                        lat: location["latitude"],
                        lng: location["longitude"],
                      ),
                    ),
                  );
                },
                child: Row(
                  children: [
                    const Icon(
                      Icons.map,
                      color: AppTheme.primaryBlue,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'View Pinned Map Location',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.primaryBlue,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (evidence != null && evidence.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Evidence Photos',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 90,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: evidence.length,
                  itemBuilder: (context, index) {
                    final storagePath = evidence[index]['storage_path'];
                    final url = provider.getEvidenceUrl(storagePath);
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => _FullScreenImageViewer(url: url),
                          ),
                        );
                      },
                      child: Stack(
                        children: [
                          Container(
                            margin: const EdgeInsets.only(right: 8),
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              image: DecorationImage(
                                image: NetworkImage(url),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 4,
                            right: 12,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Icon(
                                Icons.fullscreen,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Acknowledging report...'),
                        ),
                      );
                      final success = await provider.updateReportStatus(
                        reportId,
                        ReportStatus.acknowledged,
                      );
                      if (success) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Report successfully acknowledged!'),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              provider.errorMessage ?? 'Database rejected the update. Please check RLS.',
                            ),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Acknowledge'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        _showResolveDialog(context, provider, reportId),
                    icon: const Icon(Icons.check),
                    label: const Text('Resolve'),
                    style: _outlinedStyle(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showResolveDialog(
    BuildContext context,
    ReportProvider provider,
    String reportId,
  ) {
    final TextEditingController notesController = TextEditingController();
    File? proofImage;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Resolve Report'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Please provide details on how this issue was resolved.',
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesController,
                      decoration: const InputDecoration(
                        labelText: 'Resolution Notes',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final cameras = await availableCameras();
                        final imagePath = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                CameraScreen(cameras: cameras),
                          ),
                        );
                        if (imagePath != null) {
                          setState(() {
                            proofImage = File(imagePath as String);
                          });
                        }
                      },
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Attach Proof (Optional)'),
                    ),
                    if (proofImage != null) ...[
                      const SizedBox(height: 8),
                      Image.file(proofImage!, height: 100),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (notesController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Notes are required')),
                      );
                      return;
                    }
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Submitting Resolution...')),
                    );
                    final success = await provider.resolveReport(
                      reportId,
                      notesController.text,
                      proofImage,
                    );
                    if (success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Resolution Sent to Resident for Confirmation',
                          ),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            provider.errorMessage ?? 'Failed to update database. Did you run the SQL script?',
                          ),
                        ),
                      );
                    }
                  },
                  child: const Text('Submit Resolution'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  ButtonStyle _outlinedStyle({Color? color}) {
    return OutlinedButton.styleFrom(
      foregroundColor: color ?? Colors.black87,
      side: BorderSide(color: Colors.grey.shade300),
      padding: const EdgeInsets.symmetric(vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Widget _buildPriorityItem(
    String score,
    String title,
    String subtitle,
    String badgeText,
    Color badgeColor,
    String date, {
    required String reportId,
    required ReportProvider provider,
    List<dynamic>? evidence,
    dynamic location,
    String priorityLabel = '',
    String currentStatus = 'submitted',
    bool isEmergency = false,
  }) {
    final reportStatus = ReportStatus.fromDatabase(currentStatus);
    final statusLabel = reportStatus.label;
    final statusColor = switch (reportStatus) {
      ReportStatus.acknowledged => AppTheme.primaryBlue,
      ReportStatus.inProgress =>
        isEmergency ? AppTheme.statusCritical : AppTheme.statusProgress,
      ReportStatus.resolved => AppTheme.statusLow,
      ReportStatus.referred => AppTheme.statusReferred,
      ReportStatus.falseAlarm => AppTheme.statusHigh,
      ReportStatus.closed || ReportStatus.archived => AppTheme.statusResolved,
      ReportStatus.submitted => AppTheme.textSecondary,
    };

    // Build context-aware next-status actions based on workflow
    List<Map<String, dynamic>> nextActions = [];
    if (isEmergency) {
      // Emergency workflow: submitted → acknowledged → in_progress → resolved|referred|false_alarm → closed
      if (reportStatus == ReportStatus.submitted) {
        nextActions = [
          {
            'label': 'Acknowledge',
            'icon': Icons.check_circle,
            'status': ReportStatus.acknowledged,
            'color': AppTheme.primaryBlue,
          },
        ];
      } else if (reportStatus == ReportStatus.acknowledged) {
        nextActions = [
          {
            'label': 'Mark In Progress',
            'icon': Icons.directions_run,
            'status': ReportStatus.inProgress,
            'color': AppTheme.statusCritical,
          },
        ];
      } else if (reportStatus == ReportStatus.inProgress) {
        nextActions = [
          {
            'label': 'Mark Resolved',
            'icon': Icons.check,
            'status': ReportStatus.resolved,
            'color': AppTheme.statusLow,
            'requiresDialog': true,
          },
          {
            'label': 'Refer to Authority',
            'icon': Icons.call_made,
            'status': ReportStatus.referred,
            'color': const Color(0xFF0891B2),
          },
          {
            'label': 'Mark False Alarm',
            'icon': Icons.warning_amber,
            'status': ReportStatus.falseAlarm,
            'color': Colors.orange,
          },
        ];
      } else if ({
        ReportStatus.resolved,
        ReportStatus.referred,
        ReportStatus.falseAlarm,
      }.contains(reportStatus)) {
        nextActions = [
          {
            'label': 'Close Report',
            'icon': Icons.folder_off,
            'status': ReportStatus.closed,
            'color': Colors.grey,
          },
        ];
      } else if (reportStatus == ReportStatus.closed) {
        nextActions = [
          {
            'label': 'Archive Report',
            'icon': Icons.archive,
            'status': ReportStatus.archived,
            'color': Colors.grey.shade600,
          },
        ];
      }
    } else {
      // Normal workflow: submitted → acknowledged → in_progress → resolved → closed → archived
      if (reportStatus == ReportStatus.submitted) {
        nextActions = [
          {
            'label': 'Acknowledge / Under Review',
            'icon': Icons.visibility,
            'status': ReportStatus.acknowledged,
            'color': AppTheme.primaryBlue,
          },
        ];
      } else if (reportStatus == ReportStatus.acknowledged) {
        nextActions = [
          {
            'label': 'Mark In Progress',
            'icon': Icons.engineering,
            'status': ReportStatus.inProgress,
            'color': const Color(0xFF8B5CF6),
          },
        ];
      } else if (reportStatus == ReportStatus.inProgress) {
        nextActions = [
          {
            'label': 'Mark Resolved',
            'icon': Icons.check,
            'status': ReportStatus.resolved,
            'color': AppTheme.statusLow,
            'requiresDialog': true,
          },
        ];
      } else if (reportStatus == ReportStatus.resolved) {
        nextActions = [
          {
            'label': 'Close Report',
            'icon': Icons.folder_off,
            'status': ReportStatus.closed,
            'color': Colors.grey,
          },
        ];
      } else if (reportStatus == ReportStatus.closed) {
        nextActions = [
          {
            'label': 'Archive Report',
            'icon': Icons.archive,
            'status': ReportStatus.archived,
            'color': Colors.grey.shade600,
          },
        ];
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      elevation: isEmergency ? 3 : 1,
      shadowColor: (isEmergency ? AppTheme.statusCritical : AppTheme.navy)
          .withValues(alpha: isEmergency ? 0.16 : 0.08),
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: isEmergency
              ? AppTheme.statusCritical.withValues(alpha: 0.35)
              : AppTheme.outline,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 5, color: badgeColor),
            Expanded(
              child: Column(
                children: [
                  ListTile(
                    contentPadding: const EdgeInsets.fromLTRB(15, 12, 14, 8),
                    leading: Container(
                      width: 56,
                      height: 58,
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.09),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: badgeColor.withValues(alpha: 0.18),
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            score,
                            style: TextStyle(
                              color: badgeColor,
                              fontWeight: FontWeight.w800,
                              fontSize: 20,
                              height: 1,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'SCORE',
                            style: TextStyle(
                              color: badgeColor,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.7,
                            ),
                          ),
                        ],
                      ),
                    ),
                    title: Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 9),
                        Wrap(
                          spacing: 7,
                          runSpacing: 6,
                          children: [
                            _StatusPill(
                              label: badgeText,
                              color: badgeColor,
                              icon: isEmergency
                                  ? Icons.emergency_rounded
                                  : Icons.flag_rounded,
                              filled: true,
                            ),
                            _StatusPill(
                              label: statusLabel,
                              color: statusColor,
                              icon: Icons.sync_rounded,
                            ),
                          ],
                        ),
                        if (location != null) ...[
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => _FullScreenMapViewer(
                                    lat: location["latitude"],
                                    lng: location["longitude"],
                                  ),
                                ),
                              );
                            },
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.location_on_rounded,
                                  color: AppTheme.primaryBlue,
                                  size: 15,
                                ),
                                const SizedBox(width: 5),
                                const Text(
                                  'Open pinned location',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.primaryBlue,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                const Icon(
                                  Icons.arrow_outward_rounded,
                                  color: AppTheme.primaryBlue,
                                  size: 13,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          date,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Icon(
                          Icons.more_horiz_rounded,
                          color: AppTheme.textSecondary,
                          size: 20,
                        ),
                      ],
                    ),
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        useSafeArea: true,
                        builder: (ctx) => ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: MediaQuery.sizeOf(ctx).height * 0.82,
                          ),
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    4,
                                    20,
                                    18,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            width: 42,
                                            height: 42,
                                            decoration: BoxDecoration(
                                              color: badgeColor.withValues(
                                                alpha: 0.1,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Icon(
                                              isEmergency
                                                  ? Icons.emergency_rounded
                                                  : Icons.assignment_rounded,
                                              color: badgeColor,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              title,
                                              style: Theme.of(ctx)
                                                  .textTheme
                                                  .titleLarge,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          _StatusPill(
                                            label: badgeText,
                                            color: badgeColor,
                                            icon: Icons.flag_rounded,
                                            filled: true,
                                          ),
                                          _StatusPill(
                                            label: statusLabel,
                                            color: statusColor,
                                            icon: Icons.sync_rounded,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        priorityLabel,
                                        style: Theme.of(ctx)
                                            .textTheme
                                            .bodyMedium,
                                      ),
                                    ],
                                  ),
                                ),
                                // Workflow Status Actions
                                if (nextActions.isNotEmpty) ...[
                                  const Divider(),
                                  const _SheetSectionLabel('NEXT ACTION'),
                                  ...nextActions.map(
                                    (action) => Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 3,
                                      ),
                                      child: ListTile(
                                        tileColor: (action['color'] as Color)
                                            .withValues(alpha: 0.07),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),
                                        leading: Container(
                                          width: 38,
                                          height: 38,
                                          decoration: BoxDecoration(
                                            color: (action['color'] as Color)
                                                .withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: Icon(
                                            action['icon'],
                                            color: action['color'],
                                            size: 20,
                                          ),
                                        ),
                                        title: Text(
                                          action['label'],
                                          style: const TextStyle(
                                            color: AppTheme.onSurfaceColor,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        trailing: Icon(
                                          Icons.arrow_forward_rounded,
                                          color: action['color'],
                                          size: 19,
                                        ),
                                        onTap: () async {
                                          final messenger =
                                              ScaffoldMessenger.of(context);
                                          Navigator.pop(ctx);
                                          if (action['requiresDialog'] ==
                                              true) {
                                            _showResolveDialog(
                                              context,
                                              provider,
                                              reportId,
                                            );
                                          } else {
                                            final success = await provider
                                                .updateReportStatus(
                                                  reportId,
                                                  action['status']
                                                      as ReportStatus,
                                                );
                                            messenger.showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  success
                                                      ? 'Status updated to "${action['label']}"'
                                                      : (provider
                                                                .errorMessage ??
                                                            'Update failed'),
                                                ),
                                                backgroundColor: success
                                                    ? Colors.green
                                                    : Colors.red,
                                              ),
                                            );
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 16),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  if (evidence != null && evidence.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 12,
                        right: 12,
                        bottom: 12,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Evidence Photos',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 6),
                          SizedBox(
                            height: 90,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: evidence.length,
                              itemBuilder: (context, index) {
                                final storagePath =
                                    evidence[index]['storage_path'];
                                final url = provider.getEvidenceUrl(
                                  storagePath,
                                );
                                return GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            _FullScreenImageViewer(url: url),
                                      ),
                                    );
                                  },
                                  child: Stack(
                                    children: [
                                      Container(
                                        margin: const EdgeInsets.only(right: 8),
                                        width: 90,
                                        height: 90,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          image: DecorationImage(
                                            image: NetworkImage(url),
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        bottom: 4,
                                        right: 12,
                                        child: Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: BoxDecoration(
                                            color: Colors.black54,
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.fullscreen,
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.color,
    required this.icon,
    this.filled = false,
  });

  final String label;
  final Color color;
  final IconData icon;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final foreground = filled ? Colors.white : color;
    return Semantics(
      label: label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: filled ? color : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: filled ? color : color.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: foreground, size: 12),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: foreground,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.55,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetSectionLabel extends StatelessWidget {
  const _SheetSectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppTheme.textSecondary,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}

class _EmptyQueueState extends StatelessWidget {
  const _EmptyQueueState({
    required this.icon,
    required this.title,
    required this.message,
  });
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$title. $message',
      child:
          Column(
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 112,
                        height: 112,
                        decoration: const BoxDecoration(
                          color: Color(0xFFE7F0FF),
                          shape: BoxShape.circle,
                        ),
                      ),
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.navy.withValues(alpha: 0.08),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Icon(
                          icon,
                          size: 34,
                          color: AppTheme.primaryBlue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: Text(
                      message,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.swipe_down_rounded,
                        color: AppTheme.textSecondary,
                        size: 16,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Pull down to refresh',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              )
              .animate()
              .fadeIn(duration: 350.ms)
              .slideY(begin: 0.04, end: 0, curve: Curves.easeOutCubic),
    );
  }
}

class _UrgencyChoice extends StatelessWidget {
  const _UrgencyChoice({
    required this.filter,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final _UrgencyFilter filter;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = switch (filter) {
      _UrgencyFilter.all => 'All priorities',
      _UrgencyFilter.high => 'High',
      _UrgencyFilter.medium => 'Medium',
      _UrgencyFilter.low => 'Low',
    };
    final color = switch (filter) {
      _UrgencyFilter.all => AppTheme.primaryBlue,
      _UrgencyFilter.high => AppTheme.statusHigh,
      _UrgencyFilter.medium => AppTheme.statusMedium,
      _UrgencyFilter.low => AppTheme.statusLow,
    };
    final foreground = selected && filter == _UrgencyFilter.medium
        ? AppTheme.navy
        : selected
        ? Colors.white
        : AppTheme.onSurfaceColor;

    return Semantics(
      button: true,
      selected: selected,
      label: '$label, $count reports',
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: selected ? color : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected ? color : color.withValues(alpha: 0.45),
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.18),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 7),
                Container(
                  constraints: const BoxConstraints(minWidth: 21),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? Colors.white.withValues(alpha: 0.22)
                        : color.withValues(alpha: 0.11),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: foreground,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
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
}

class _QueueSkeleton extends StatelessWidget {
  const _QueueSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      itemCount: 4,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) => Container(
        height: 154,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          border: Border.all(color: AppTheme.outline),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SkeletonBlock(width: 56, height: 58, radius: 15),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SkeletonBlock(width: index.isEven ? 190 : 230, height: 16),
                  const SizedBox(height: 10),
                  const _SkeletonBlock(width: 150, height: 11),
                  const SizedBox(height: 14),
                  const Row(
                    children: [
                      _SkeletonBlock(width: 72, height: 24, radius: 12),
                      SizedBox(width: 8),
                      _SkeletonBlock(width: 94, height: 24, radius: 12),
                    ],
                  ),
                  const Spacer(),
                  const _SkeletonBlock(width: 170, height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkeletonBlock extends StatelessWidget {
  const _SkeletonBlock({
    required this.width,
    required this.height,
    this.radius = 6,
  });
  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: AppTheme.surfaceMuted,
            borderRadius: BorderRadius.circular(radius),
          ),
        )
        .animate(onPlay: (controller) => controller.repeat(reverse: true))
        .fade(begin: 0.45, end: 1, duration: 760.ms, curve: Curves.easeInOut);
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        border: Border.all(color: Colors.white24),
        borderRadius: BorderRadius.circular(12),
      ),
      child:
          Row(
                children: const [
                  Icon(
                    Icons.fiber_manual_record,
                    color: Color(0xFF5DE2A5),
                    size: 8,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'LIVE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              )
              .animate(onPlay: (controller) => controller.repeat(reverse: true))
              .fade(begin: 0.65, end: 1, duration: 1100.ms),
    );
  }
}

class _FullScreenImageViewer extends StatelessWidget {
  final String url;
  const _FullScreenImageViewer({required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050B14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF050B14),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Evidence photo', style: TextStyle(fontSize: 16)),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                'Pinch to zoom',
                style: TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: InteractiveViewer(
            minScale: 0.8,
            maxScale: 5,
            boundaryMargin: const EdgeInsets.all(48),
            child: Image.network(
              url,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, progress) => progress == null
                  ? child
                  : const SizedBox(
                      width: 44,
                      height: 44,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: Colors.white,
                      ),
                    ),
              errorBuilder: (_, __, ___) => const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.broken_image_rounded,
                    color: Colors.white54,
                    size: 48,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Could not load this evidence photo',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FullScreenMapViewer extends StatelessWidget {
  final double lat;
  final double lng;

  const _FullScreenMapViewer({required this.lat, required this.lng});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pinned location'),
            Text(
              'Reported incident coordinates',
              style: TextStyle(
                color: Colors.white60,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: LatLng(lat, lng),
              initialZoom: 16.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.helphub',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: LatLng(lat, lng),
                    width: 72,
                    height: 72,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                              width: 54,
                              height: 54,
                              decoration: BoxDecoration(
                                color: AppTheme.statusCritical.withValues(
                                  alpha: 0.18,
                                ),
                                shape: BoxShape.circle,
                              ),
                            )
                            .animate(
                              onPlay: (controller) => controller.repeat(),
                            )
                            .scaleXY(begin: 0.7, end: 1.2, duration: 1400.ms)
                            .fadeOut(begin: 0.7),
                        Container(
                          width: 38,
                          height: 38,
                          decoration: const BoxDecoration(
                            color: AppTheme.statusCritical,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 10,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.location_on_rounded,
                            color: Colors.white,
                            size: 23,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 20,
            child: SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.navy.withValues(alpha: 0.18),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppTheme.criticalSurface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.my_location_rounded,
                        color: AppTheme.statusCritical,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Incident coordinates',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}',
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
