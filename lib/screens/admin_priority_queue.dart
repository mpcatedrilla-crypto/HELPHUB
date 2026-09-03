import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/report_provider.dart';
import '../theme/app_theme.dart';
import 'package:timeago/timeago.dart' as timeago;

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
      Provider.of<ReportProvider>(context, listen: false).fetchAllReports();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Priority Algorithm Queue'),
        actions: [
          const Center(child: _LiveBadge()),
          const SizedBox(width: 16),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Provider.of<AuthProvider>(context, listen: false).logout();
              Navigator.pushReplacementNamed(context, '/');
            },
          ),
        ],
      ),
      body: Consumer<ReportProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.allReports.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          final emergencyReports = provider.allReports
              .where((r) => r['is_critical_override'] == true && r['status'] != 'resolved' && r['status'] != 'rejected')
              .toList();
              
          final regularReports = provider.allReports
              .where((r) => !emergencyReports.contains(r))
              .toList();

          return RefreshIndicator(
            onRefresh: provider.fetchAllReports,
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
                  
                  ...emergencyReports.map((r) => _buildEmergencyCard(
                    r['profiles'] != null ? r['profiles']['full_name'] : 'Unknown',
                    '${r['concern_types']?['category_name'] ?? 'Emergency'} - ${r['title']}',
                    'Tap to view details', 
                    timeago.format(DateTime.parse(r['created_at'])),
                    isCritical: true,
                    reportId: r['id'],
                    provider: provider,
                  )),
                  
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
                  
                  ...regularReports.map((r) {
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
                    );
                  }),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmergencyCard(String name, String details, String phone, String time, {bool isCritical = false, required String reportId, required ReportProvider provider}) {
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
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.emergency, color: AppTheme.sosRed, size: 16),
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
                      Text(phone, style: const TextStyle(color: AppTheme.primaryBlue, fontSize: 14)),
                    ],
                  ),
                ),
              ],
            ),
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
                    onPressed: () {},
                    icon: const Icon(Icons.call),
                    label: const Text('Call'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryBlue,
                      side: const BorderSide(color: AppTheme.primaryBlue),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => provider.updateReportStatus(reportId, 'resolved'), 
                    icon: const Icon(Icons.check), 
                    label: const Text('Resolve'), 
                    style: _outlinedStyle()
                  )
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => provider.updateReportStatus(reportId, 'rejected'), 
                    icon: const Icon(Icons.cancel_outlined, color: Colors.grey), 
                    label: const Text('False Alarm', style: TextStyle(color: Colors.grey)), 
                    style: _outlinedStyle(color: Colors.grey)
                  )
                ),
              ],
            )
          ],
        ),
      ),
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

  Widget _buildPriorityItem(String score, String title, String subtitle, String badgeText, Color badgeColor, String date, {required String reportId, required ReportProvider provider}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
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
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
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
          // Simple action menu to change status
          showModalBottomSheet(
            context: context,
            builder: (ctx) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
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
                      provider.updateReportStatus(reportId, 'resolved');
                      Navigator.pop(ctx);
                    },
                  ),
                ],
              ),
            ),
          );
        },
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
      child: const Row(
        children: [
          Icon(Icons.fiber_manual_record, color: Colors.white, size: 8),
          SizedBox(width: 4),
          Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
