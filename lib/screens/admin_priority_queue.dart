import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/auth_provider.dart';
import '../providers/report_provider.dart';
import '../providers/admin_provider.dart';
import '../theme/app_theme.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:camera/camera.dart';
import 'admin_drawer.dart';
import 'camera_screen.dart';

class AdminPriorityQueue extends StatefulWidget {
  const AdminPriorityQueue({super.key});

  @override
  State<AdminPriorityQueue> createState() => _AdminPriorityQueueState();
}

class _AdminPriorityQueueState extends State<AdminPriorityQueue> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final reportProvider = Provider.of<ReportProvider>(context, listen: false);
      final adminProvider = Provider.of<AdminProvider>(context, listen: false);
      
      reportProvider.fetchAllReports();
      adminProvider.fetchRoutingDestinations();
      
      adminProvider.startListeningForEmergencies(() {
        if (mounted) reportProvider.fetchAllReports();
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    Provider.of<AdminProvider>(context, listen: false).stopListeningForEmergencies();
    super.dispose();
  }

  Map<String, dynamic> _getBadgeInfo(Map<String, dynamic> r) {
    final score = r['priority_score'] ?? 0;
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

    // Status overrides
    switch (r['status']) {
      case 'acknowledged':
        badgeColor = AppTheme.primaryBlue; badgeText = 'ACKNOWLEDGED'; priorityLabel = 'Admin has acknowledged this report'; break;
      case 'in_progress':
        badgeColor = const Color(0xFF8B5CF6); badgeText = 'IN PROGRESS'; priorityLabel = 'Team is actively working on this'; break;
      case 'responding':
        badgeColor = AppTheme.statusCritical; badgeText = 'RESPONDING'; priorityLabel = 'Emergency team is responding'; break;
      case 'resolved':
        badgeColor = AppTheme.statusResolved; badgeText = 'RESOLVED'; priorityLabel = 'This report has been resolved'; break;
      case 'referred':
        badgeColor = const Color(0xFF0891B2); badgeText = 'REFERRED'; priorityLabel = 'Referred to another authority'; break;
      case 'false_alarm':
        badgeColor = Colors.orange.shade700; badgeText = 'FALSE ALARM'; priorityLabel = 'Determined to be a false alarm'; break;
      case 'closed':
        badgeColor = Colors.grey; badgeText = 'CLOSED'; priorityLabel = 'Report closed'; break;
      case 'archived':
        badgeColor = Colors.grey.shade400; badgeText = 'ARCHIVED'; priorityLabel = 'Report archived'; break;
    }

    return {'color': badgeColor, 'text': badgeText, 'label': priorityLabel};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Priority Queue'),
        actions: const [Center(child: _LiveBadge()), SizedBox(width: 16)],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard, size: 18), text: 'All'),
            Tab(icon: Icon(Icons.emergency, size: 18), text: 'Emergencies'),
            Tab(icon: Icon(Icons.hourglass_top, size: 18), text: 'Active'),
            Tab(icon: Icon(Icons.check_circle, size: 18), text: 'Resolved'),
          ],
        ),
      ),
      drawer: const AdminDrawer(),
      body: Consumer2<ReportProvider, AdminProvider>(
        builder: (context, provider, adminProvider, child) {
          if (provider.isLoading && provider.allReports.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          final allReports = provider.allReports;
          final emergencyReports = allReports.where((r) => r['is_critical_override'] == true).toList();
          final activeReports = allReports.where((r) => !['resolved', 'closed', 'archived', 'false_alarm'].contains(r['status'])).toList();
          final resolvedReports = allReports.where((r) => ['resolved', 'closed', 'archived', 'referred', 'false_alarm'].contains(r['status'])).toList();

          return TabBarView(
            controller: _tabController,
            children: [
              _buildReportList(allReports, provider, adminProvider, emptyMsg: 'No reports found.'),
              _buildReportList(emergencyReports, provider, adminProvider, emptyMsg: 'No active emergencies.'),
              _buildReportList(activeReports, provider, adminProvider, emptyMsg: 'No active reports.'),
              _buildReportList(resolvedReports, provider, adminProvider, emptyMsg: 'No resolved reports yet.'),
            ],
          );
        },
      ),
    );
  }

  Widget _buildReportList(List<Map<String, dynamic>> reports, ReportProvider provider, AdminProvider adminProvider, {required String emptyMsg}) {
    return RefreshIndicator(
      onRefresh: () async {
        provider.fetchAllReports();
        adminProvider.fetchRoutingDestinations();
      },
      child: reports.isEmpty
          ? ListView(
              children: [
                const SizedBox(height: 80),
                Center(child: Column(
                  children: [
                    const Icon(Icons.inbox, size: 64, color: Colors.grey),
                    const SizedBox(height: 12),
                    Text(emptyMsg, style: const TextStyle(color: Colors.grey, fontSize: 16)),
                  ],
                )),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: reports.length,
              itemBuilder: (context, index) {
                final r = reports[index];
                final badge = _getBadgeInfo(r);
                final score = r['priority_score'] ?? 0;
                return _buildPriorityItem(
                  score.toString(),
                  r['title'] ?? 'No Title',
                  '#${r['id'].toString().substring(0, 8).toUpperCase()} · ${r['profiles']?['full_name'] ?? 'Unknown'}',
                  badge['text'],
                  badge['color'],
                  timeago.format(DateTime.parse(r['created_at'])),
                  reportId: r['id'],
                  provider: provider,
                  adminProvider: adminProvider,
                  currentDestinationId: r['routing_destination_id'],
                  evidence: r['report_evidence'],
                  location: r['report_locations'],
                  priorityLabel: badge['label'],
                  currentStatus: r['status'] ?? 'submitted',
                  isEmergency: r['is_critical_override'] == true,
                ).animate().fade(duration: 300.ms).slideY(begin: 0.1, delay: (index * 40).ms);
              },
            ),
    );
  }

  Widget _buildEmergencyCard(String name, String details, String phone, String time, {bool isCritical = false, required String reportId, required ReportProvider provider, List<dynamic>? evidence, dynamic location}) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isCritical ? AppTheme.sosRed : Colors.grey.shade300, width: isCritical ? 1 : 0),
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
                      .animate(onPlay: (controller) => controller.repeat(reverse: true))
                      .scaleXY(end: 1.2, duration: 500.ms),
                  SizedBox(width: 8),
                  Text('CRITICAL - IMMEDIATE RESPONSE NEEDED', style: TextStyle(color: AppTheme.sosRed, fontWeight: FontWeight.bold, fontSize: 12)),
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
                          Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text(time, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(details, style: const TextStyle(color: Colors.grey, fontSize: 14)),
                    ],
                  ),
                ),
              ],
            ),
            if (location != null) ...[
              const SizedBox(height: 8),
              InkWell(
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => _FullScreenMapViewer(lat: location["latitude"], lng: location["longitude"])));
                },
                child: Row(
                  children: [
                    const Icon(Icons.map, color: AppTheme.primaryBlue, size: 16),
                    const SizedBox(width: 4),
                    const Text('View Pinned Map Location', style: TextStyle(fontSize: 14, color: AppTheme.primaryBlue, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
                  ],
                ),
              ),
            ],
            if (evidence != null && evidence.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Evidence Photos', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
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
                        Navigator.push(context, MaterialPageRoute(builder: (_) => _FullScreenImageViewer(url: url)));
                      },
                      child: Stack(
                        children: [
                          Container(
                            margin: const EdgeInsets.only(right: 8),
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              image: DecorationImage(image: NetworkImage(url), fit: BoxFit.cover),
                            ),
                          ),
                          Positioned(
                            bottom: 4,
                            right: 12,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
                              child: const Icon(Icons.fullscreen, color: Colors.white, size: 16),
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
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Acknowledging report...')));
                      final success = await provider.updateReportStatus(reportId, 'acknowledged');
                      if (success) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report successfully acknowledged!')));
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(provider.errorMessage ?? 'Database rejected the update. Please check RLS.')));
                      }
                    }, 
                    icon: const Icon(Icons.check_circle_outline), 
                    label: const Text('Acknowledge')
                  )
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showResolveDialog(context, provider, reportId), 
                    icon: const Icon(Icons.check), 
                    label: const Text('Resolve'), 
                    style: _outlinedStyle()
                  )
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  void _showResolveDialog(BuildContext context, ReportProvider provider, String reportId) {
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
                    const Text('Please provide details on how this issue was resolved.'),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesController,
                      decoration: const InputDecoration(labelText: 'Resolution Notes', border: OutlineInputBorder()),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final cameras = await availableCameras();
                        final imagePath = await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => CameraScreen(cameras: cameras)),
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
                    ]
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    if (notesController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notes are required')));
                      return;
                    }
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Submitting Resolution...')));
                    final success = await provider.resolveReport(reportId, notesController.text, proofImage);
                    if (success) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Resolution Sent to Resident for Confirmation')));
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(provider.errorMessage ?? 'Failed to update database. Did you run the SQL script?')));
                    }
                  },
                  child: const Text('Submit Resolution'),
                ),
              ],
            );
          }
        );
      }
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

  Widget _buildPriorityItem(String score, String title, String subtitle, String badgeText, Color badgeColor, String date, {required String reportId, required ReportProvider provider, required AdminProvider adminProvider, String? currentDestinationId, List<dynamic>? evidence, dynamic location, String priorityLabel = '', String currentStatus = 'submitted', bool isEmergency = false}) {
    
    String assignedTo = "Unassigned";
    if (currentDestinationId != null) {
      final dest = adminProvider.routingDestinations.where((d) => d['id'] == currentDestinationId).firstOrNull;
      if (dest != null) assignedTo = dest['destination_name'];
    }

    // Build context-aware next-status actions based on workflow
    List<Map<String, dynamic>> nextActions = [];
    if (isEmergency) {
      // Emergency workflow: submitted → acknowledged → responding → resolved|referred|false_alarm → closed
      if (currentStatus == 'submitted') {
        nextActions = [{'label': 'Acknowledge', 'icon': Icons.check_circle, 'status': 'acknowledged', 'color': AppTheme.primaryBlue}];
      } else if (currentStatus == 'acknowledged') {
        nextActions = [{'label': 'Mark Responding', 'icon': Icons.directions_run, 'status': 'responding', 'color': AppTheme.statusCritical}];
      } else if (currentStatus == 'responding') {
        nextActions = [
          {'label': 'Mark Resolved', 'icon': Icons.check, 'status': 'resolved', 'color': AppTheme.statusLow, 'requiresDialog': true},
          {'label': 'Refer to Authority', 'icon': Icons.call_made, 'status': 'referred', 'color': const Color(0xFF0891B2)},
          {'label': 'Mark False Alarm', 'icon': Icons.warning_amber, 'status': 'false_alarm', 'color': Colors.orange},
        ];
      } else if (['resolved', 'referred', 'false_alarm'].contains(currentStatus)) {
        nextActions = [{'label': 'Close Report', 'icon': Icons.folder_off, 'status': 'closed', 'color': Colors.grey}];
      }
    } else {
      // Normal workflow: submitted → acknowledged → in_progress → resolved → closed → archived
      if (currentStatus == 'submitted') {
        nextActions = [{'label': 'Acknowledge / Under Review', 'icon': Icons.visibility, 'status': 'acknowledged', 'color': AppTheme.primaryBlue}];
      } else if (currentStatus == 'acknowledged') {
        nextActions = [{'label': 'Mark In Progress', 'icon': Icons.engineering, 'status': 'in_progress', 'color': const Color(0xFF8B5CF6)}];
      } else if (currentStatus == 'in_progress') {
        nextActions = [{'label': 'Mark Resolved', 'icon': Icons.check, 'status': 'resolved', 'color': AppTheme.statusLow, 'requiresDialog': true}];
      } else if (currentStatus == 'resolved') {
        nextActions = [{'label': 'Close Report', 'icon': Icons.folder_off, 'status': 'closed', 'color': Colors.grey}];
      } else if (currentStatus == 'closed') {
        nextActions = [{'label': 'Archive Report', 'icon': Icons.archive, 'status': 'archived', 'color': Colors.grey.shade600}];
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 6, color: badgeColor),
            Expanded(
              child: Column(
                children: [
                  ListTile(
                    contentPadding: const EdgeInsets.only(left: 12, right: 12, top: 8, bottom: 4),
                    leading: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: badgeColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(score, style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold, fontSize: 18)),
                          Text('score', style: TextStyle(color: badgeColor, fontSize: 10)),
                        ],
                      ),
                    ),
                    title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(subtitle, style: const TextStyle(fontSize: 12)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(10)),
                              child: Text(badgeText, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 6),
                            Expanded(child: Text(priorityLabel, style: TextStyle(fontSize: 10, color: Colors.grey.shade600), overflow: TextOverflow.ellipsis)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.group, size: 12, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text('Assigned to: $assignedTo', style: const TextStyle(fontSize: 12, color: AppTheme.primaryBlue, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        if (location != null) ...[
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => _FullScreenMapViewer(lat: location["latitude"], lng: location["longitude"])));
                            },
                            child: Row(
                              children: [
                                const Icon(Icons.map, color: AppTheme.primaryBlue, size: 14),
                                const SizedBox(width: 4),
                                const Text('View Pinned Map Location', style: TextStyle(fontSize: 12, color: AppTheme.primaryBlue, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
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
                        Text(date, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        builder: (ctx) => SafeArea(
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Row(
                                    children: [
                                      Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(12)),
                                        child: Text(badgeText, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ),
                                ),
                                // Workflow Status Actions
                                if (nextActions.isNotEmpty) ...[
                                  const Divider(),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                    child: Align(alignment: Alignment.centerLeft, child: Text('WORKFLOW ACTIONS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2))),
                                  ),
                                  ...nextActions.map((action) => ListTile(
                                    leading: Icon(action['icon'], color: action['color']),
                                    title: Text(action['label'], style: TextStyle(color: action['color'], fontWeight: FontWeight.w600)),
                                    onTap: () async {
                                      Navigator.pop(ctx);
                                      if (action['requiresDialog'] == true) {
                                        _showResolveDialog(context, provider, reportId);
                                      } else {
                                        final success = await provider.updateReportStatus(reportId, action['status']);
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                            content: Text(success ? 'Status updated to "${action['label']}"' : (provider.errorMessage ?? 'Update failed')),
                                            backgroundColor: success ? Colors.green : Colors.red,
                                          ));
                                        }
                                      }
                                    },
                                  )),
                                ],
                                const Divider(),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                                  child: Align(alignment: Alignment.centerLeft, child: Text('DISPATCH TEAM', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2))),
                                ),
                                ...adminProvider.routingDestinations.map((dest) => ListTile(
                                  leading: const Icon(Icons.local_shipping),
                                  title: Text(dest['destination_name']),
                                  trailing: currentDestinationId == dest['id'] ? const Icon(Icons.check, color: AppTheme.primaryBlue) : null,
                                  onTap: () {
                                    adminProvider.assignReportDestination(reportId, dest['id']);
                                    Navigator.pop(ctx);
                                  },
                                )),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  if (evidence != null && evidence.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 12, right: 12, bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Evidence Photos', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
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
                                    Navigator.push(context, MaterialPageRoute(builder: (_) => _FullScreenImageViewer(url: url)));
                                  },
                                  child: Stack(
                                    children: [
                                      Container(
                                        margin: const EdgeInsets.only(right: 8),
                                        width: 90,
                                        height: 90,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(10),
                                          image: DecorationImage(image: NetworkImage(url), fit: BoxFit.cover),
                                        ),
                                      ),
                                      Positioned(
                                        bottom: 4,
                                        right: 12,
                                        child: Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
                                          child: const Icon(Icons.fullscreen, color: Colors.white, size: 16),
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

class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.sosRed,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: const [
          Icon(Icons.fiber_manual_record, color: Colors.white, size: 8),
          SizedBox(width: 4),
          Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ).animate(onPlay: (controller) => controller.repeat(reverse: true)).fade(end: 0.5, duration: 800.ms),
    );
  }
}


class _FullScreenImageViewer extends StatelessWidget {
  final String url;
  const _FullScreenImageViewer({required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.network(url),
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
      appBar: AppBar(title: const Text('Pinned Location')),
      body: FlutterMap(
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
                width: 80,
                height: 80,
                child: const Icon(Icons.location_on, color: Colors.red, size: 40),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

