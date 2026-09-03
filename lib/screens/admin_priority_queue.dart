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

class _AdminPriorityQueueState extends State<AdminPriorityQueue> {
  @override
  void initState() {
    super.initState();
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
    Provider.of<AdminProvider>(context, listen: false).stopListeningForEmergencies();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Priority Queue'),
        actions: const [
          Center(child: _LiveBadge()),
          SizedBox(width: 16),
        ],
      ),
      drawer: const AdminDrawer(),
      body: Consumer2<ReportProvider, AdminProvider>(
        builder: (context, provider, adminProvider, child) {
          if (provider.isLoading && provider.allReports.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          final emergencyReports = provider.allReports
              .where((r) => r['is_critical_override'] == true && r['status'] != 'resolved' && r['status'] != 'rejected' && r['status'] != 'pending_confirmation')
              .toList();
              
          final regularReports = provider.allReports
              .where((r) => !emergencyReports.contains(r) && r['status'] != 'resolved' && r['status'] != 'rejected' && r['status'] != 'pending_confirmation')
              .toList();

          return RefreshIndicator(
            onRefresh: () async {
              provider.fetchAllReports();
              adminProvider.fetchRoutingDestinations();
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Active SOS & Emergencies', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.sosRed)),
                  const SizedBox(height: 12),
                  
                  if (emergencyReports.isEmpty)
                    const Text('No active emergencies.', style: TextStyle(color: Colors.grey)),
                  
                  ...emergencyReports.asMap().entries.map((entry) => _buildEmergencyCard(
                    entry.value['profiles'] != null ? entry.value['profiles']['full_name'] : 'Unknown',
                    '${entry.value['concern_types']?['category_name'] ?? 'Emergency'} - ${entry.value['title']}',
                    'Tap to view details', 
                    timeago.format(DateTime.parse(entry.value['created_at'])),
                    isCritical: true,
                    reportId: entry.value['id'],
                    provider: provider,
                    evidence: entry.value['report_evidence'],
                  ).animate().fade(duration: 400.ms).slideX(delay: (entry.key * 100).ms)),
                  
                  const SizedBox(height: 32),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Priority Queue', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      TextButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.sort, size: 16),
                        label: const Text('Score'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  if (regularReports.isEmpty)
                    const Text('No reports in queue.', style: TextStyle(color: Colors.grey)),
                  
                  ...regularReports.asMap().entries.map((entry) {
                    final r = entry.value;
                    final score = r['priority_score'] ?? 0;
                    Color badgeColor = AppTheme.statusMedium;
                    String badgeText = 'MEDIUM';
                    if (score > 80) { badgeColor = AppTheme.statusCritical; badgeText = 'CRITICAL'; }
                    else if (score > 60) { badgeColor = AppTheme.statusHigh; badgeText = 'HIGH'; }
                    
                    if (r['status'] == 'resolved') {
                      badgeColor = AppTheme.statusResolved;
                      badgeText = 'RESOLVED';
                    } else if (r['status'] == 'acknowledged') {
                      badgeColor = AppTheme.primaryBlue;
                      badgeText = 'ACKED';
                    }

                    return _buildPriorityItem(
                      score.toString(),
                      r['title'] ?? 'No Title',
                      '#${r['id'].toString().substring(0, 8).toUpperCase()} - ${r['profiles']?['full_name'] ?? 'Unknown'}',
                      badgeText,
                      badgeColor,
                      timeago.format(DateTime.parse(r['created_at'])),
                      reportId: r['id'],
                      provider: provider,
                      adminProvider: adminProvider,
                      currentDestinationId: r['routing_destination_id'],
                      evidence: r['report_evidence'],
                    ).animate().fade(duration: 400.ms).slideY(begin: 0.2, delay: (entry.key * 50).ms);
                  }),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmergencyCard(String name, String details, String phone, String time, {bool isCritical = false, required String reportId, required ReportProvider provider, List<dynamic>? evidence}) {
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
            if (evidence != null && evidence.isNotEmpty) ...[
              const SizedBox(height: 16),
              SizedBox(
                height: 80,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: evidence.length,
                  itemBuilder: (context, index) {
                    final storagePath = evidence[index]['storage_path'];
                    final url = provider.getEvidenceUrl(storagePath);
                    return Container(
                      margin: const EdgeInsets.only(right: 8),
                      width: 80,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        image: DecorationImage(image: NetworkImage(url), fit: BoxFit.cover),
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
                    onPressed: () => provider.updateReportStatus(reportId, 'acknowledged'), 
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

  Widget _buildPriorityItem(String score, String title, String subtitle, String badgeText, Color badgeColor, String date, {required String reportId, required ReportProvider provider, required AdminProvider adminProvider, String? currentDestinationId, List<dynamic>? evidence}) {
    
    String assignedTo = "Unassigned";
    if (currentDestinationId != null) {
      final dest = adminProvider.routingDestinations.where((d) => d['id'] == currentDestinationId).firstOrNull;
      if (dest != null) assignedTo = dest['destination_name'];
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.all(12),
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
                    const Icon(Icons.group, size: 12, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text('Assigned to: $assignedTo', style: const TextStyle(fontSize: 12, color: AppTheme.primaryBlue, fontWeight: FontWeight.bold)),
                  ],
                )
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(badgeText, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 4),
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
                        const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text('Report Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                        ListTile(
                          leading: const Icon(Icons.check_circle, color: AppTheme.primaryBlue),
                          title: const Text('Mark Acknowledged'),
                          onTap: () {
                            provider.updateReportStatus(reportId, 'acknowledged');
                            Navigator.pop(ctx);
                          },
                        ),
                          ListTile(
                            leading: const Icon(Icons.check, color: AppTheme.statusResolved),
                            title: const Text('Mark Resolved'),
                            onTap: () {
                              Navigator.pop(ctx);
                              _showResolveDialog(context, provider, reportId);
                            },
                          ),
                        const Divider(),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          child: Align(alignment: Alignment.centerLeft, child: Text('Dispatch Team', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
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
              child: SizedBox(
                height: 80,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: evidence.length,
                  itemBuilder: (context, index) {
                    final storagePath = evidence[index]['storage_path'];
                    final url = provider.getEvidenceUrl(storagePath);
                    return Container(
                      margin: const EdgeInsets.only(right: 8),
                      width: 80,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        image: DecorationImage(image: NetworkImage(url), fit: BoxFit.cover),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
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
