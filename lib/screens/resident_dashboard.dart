import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/auth_provider.dart';
import '../providers/report_provider.dart';
import '../providers/admin_provider.dart';
import '../theme/app_theme.dart';

class ResidentDashboard extends StatefulWidget {
  const ResidentDashboard({super.key});

  @override
  State<ResidentDashboard> createState() => _ResidentDashboardState();
}

class _ResidentDashboardState extends State<ResidentDashboard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ReportProvider>(context, listen: false).fetchMyReports();
      Provider.of<AdminProvider>(context, listen: false).fetchAnnouncements();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('HelpHub Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              auth.logout();
              Navigator.pushReplacementNamed(context, '/');
            },
          ),
        ],
      ),
      body: Consumer2<ReportProvider, AdminProvider>(
        builder: (context, provider, adminProvider, child) {
          return RefreshIndicator(
            onRefresh: () async {
              provider.fetchMyReports();
              adminProvider.fetchAnnouncements();
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome back,\n${auth.userName ?? "Resident"}',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                  ).animate().fade().slideY(begin: -0.2),
                  const SizedBox(height: 24),
                  
                  // Announcements Banner
                  if (adminProvider.announcements.isNotEmpty) ...[
                    Card(
                      color: AppTheme.surfaceColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: AppTheme.primaryBlue, width: 1),
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.campaign, color: AppTheme.primaryBlue),
                        title: Text(adminProvider.announcements.first['title'] ?? 'Announcement', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(adminProvider.announcements.first['message'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {},
                      ),
                    ).animate().fade(duration: 400.ms).scale(),
                    const SizedBox(height: 24),
                  ],

                  // Quick Access Grid
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.5,
                    children: [
                      _buildActionCard(
                        context,
                        title: 'Report Concern',
                        icon: Icons.report_problem,
                        color: AppTheme.primaryBlue,
                        onTap: () => Navigator.pushNamed(context, '/report_concern'),
                      ),
                      _buildActionCard(
                        context,
                        title: 'My Reports',
                        icon: Icons.list_alt,
                        color: Colors.white,
                        textColor: AppTheme.primaryBlue,
                        badgeCount: provider.activeReportsCount,
                        onTap: () => Navigator.pushNamed(context, '/report_tracking'),
                      ),
                      _buildActionCard(
                        context,
                        title: 'Emergency SOS',
                        icon: Icons.emergency,
                        color: AppTheme.sosRed,
                        onTap: () => Navigator.pushNamed(context, '/emergency_sos'),
                      ),
                      _buildActionCard(
                        context,
                        title: 'Announcements',
                        icon: Icons.campaign,
                        color: Colors.white,
                        textColor: AppTheme.primaryBlue,
                        badgeCount: adminProvider.announcements.length,
                        onTap: () {},
                      ),
                    ].animate(interval: 50.ms).fade().scale(),
                  ),
                  const SizedBox(height: 24),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Recent Reports', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      TextButton(
                        onPressed: () => Navigator.pushNamed(context, '/report_tracking'), 
                        child: const Text('View all')
                      ),
                    ],
                  ).animate().fade(),
                  const SizedBox(height: 12),
                  
                  if (provider.isLoading && provider.myReports.isEmpty)
                    const Center(child: CircularProgressIndicator())
                  else if (provider.myReports.isEmpty)
                    const Text('No recent reports.')
                  else
                    ...provider.myReports.take(3).toList().asMap().entries.map((entry) {
                      final report = entry.value;
                      Color statusColor = AppTheme.statusMedium;
                      if (report['status'] == 'submitted') statusColor = Colors.orange;
                      if (report['status'] == 'resolved') statusColor = AppTheme.statusResolved;
                      
                      return _buildReportListTile(context, report, statusColor).animate().fade(duration: 400.ms).slideX(delay: (entry.key * 100).ms);
                    }),
                  
                  // Temporary admin link
                  if (auth.role == UserRole.admin)
                    Padding(
                      padding: const EdgeInsets.only(top: 32),
                      child: Center(
                        child: TextButton.icon(
                          icon: const Icon(Icons.admin_panel_settings),
                          onPressed: () => Navigator.pushNamed(context, '/admin_queue'),
                          label: const Text('Enter Admin Dashboard'),
                          style: TextButton.styleFrom(
                            backgroundColor: AppTheme.surfaceColor,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          )
                        ),
                      ),
                    ).animate().fade().scale(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildActionCard(BuildContext context, {required String title, required IconData icon, required Color color, Color textColor = Colors.white, int badgeCount = 0, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(icon, color: textColor, size: 28),
                  Text(title, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
            ),
            if (badgeCount > 0)
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: AppTheme.sosRed,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    badgeCount.toString(),
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ).animate(onPlay: (controller) => controller.repeat(reverse: true)).scaleXY(end: 1.1, duration: 600.ms),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportListTile(BuildContext context, Map<String, dynamic> report, Color statusColor) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.report, color: AppTheme.primaryBlue),
            ),
            title: Text(report['title'] ?? 'No Title', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(report['concern_types'] != null ? report['concern_types']['category_name'] : 'Other'),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                (report['status'] ?? 'Unknown').toUpperCase(),
                style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 10),
              ),
            ),
          ),
          if (report['report_evidence'] != null && report['report_evidence'].isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
              child: SizedBox(
                height: 80,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: report['report_evidence'].length,
                  itemBuilder: (context, index) {
                    final storagePath = report['report_evidence'][index]['storage_path'];
                    final url = Provider.of<ReportProvider>(context, listen: false).getEvidenceUrl(storagePath);
                    return Container(
                      margin: const EdgeInsets.only(right: 8),
                      width: 80,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        image: DecorationImage(
                          image: NetworkImage(url),
                          fit: BoxFit.cover,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

          if (report['status'] == 'pending_confirmation')
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.orange.withOpacity(0.1),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Admin Resolution Notes:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(report['admin_resolution_notes'] ?? 'No notes provided.'),
                  const SizedBox(height: 8),
                  if (report['admin_proof_url'] != null)
                    Image.network(report['admin_proof_url'], height: 100),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.statusResolved, foregroundColor: Colors.white),
                      onPressed: () {
                        Provider.of<ReportProvider>(context, listen: false).updateReportStatus(report['id'], 'resolved');
                      },
                      child: const Text('Confirm Resolution'),
                    ),
                  )
                ],
              ),
            ),

        ],
      ),
    );
  }
}
