import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/report_provider.dart';
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
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('HelpHub'),
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
      body: Consumer<ReportProvider>(
        builder: (context, provider, child) {
          return RefreshIndicator(
            onRefresh: provider.fetchMyReports,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome back,\n${auth.userName ?? "Resident"}',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                  ),
                  const SizedBox(height: 24),
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
                        badgeCount: 2,
                        onTap: () {},
                      ),
                    ],
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
                  ),
                  const SizedBox(height: 12),
                  
                  if (provider.isLoading && provider.myReports.isEmpty)
                    const Center(child: CircularProgressIndicator())
                  else if (provider.myReports.isEmpty)
                    const Text('No recent reports.')
                  else
                    ...provider.myReports.take(3).map((report) {
                      Color statusColor = AppTheme.statusMedium;
                      if (report['status'] == 'submitted') statusColor = Colors.orange;
                      if (report['status'] == 'resolved') statusColor = AppTheme.statusResolved;
                      
                      return _buildReportListTile(
                        report['title'] ?? 'No Title',
                        report['concern_types'] != null ? report['concern_types']['category_name'] : 'Other',
                        report['status'] ?? 'Unknown',
                        statusColor,
                      );
                    }),
                  
                  // Temporary admin link
                  if (auth.role == UserRole.admin)
                    Padding(
                      padding: const EdgeInsets.only(top: 32),
                      child: Center(
                        child: TextButton(
                          onPressed: () => Navigator.pushNamed(context, '/admin_queue'),
                          child: const Text('Go to Admin Dashboard'),
                        ),
                      ),
                    ),
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
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportListTile(String title, String subtitle, String status, Color statusColor) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.report, color: AppTheme.primaryBlue),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            status.toUpperCase(),
            style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 10),
          ),
        ),
      ),
    );
  }
}
