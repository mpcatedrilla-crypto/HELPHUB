import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/admin_provider.dart';
import '../theme/app_theme.dart';
import 'package:timeago/timeago.dart' as timeago;

class ResidentAnnouncementsScreen extends StatefulWidget {
  const ResidentAnnouncementsScreen({super.key});

  @override
  State<ResidentAnnouncementsScreen> createState() => _ResidentAnnouncementsScreenState();
}

class _ResidentAnnouncementsScreenState extends State<ResidentAnnouncementsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AdminProvider>(context, listen: false).fetchAnnouncements();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Announcements')),
      body: Consumer<AdminProvider>(
        builder: (context, provider, child) {
          if (provider.announcements.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.campaign_outlined, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  const Text('No active announcements', style: TextStyle(color: Colors.grey, fontSize: 18)),
                ],
              )
            );
          }

          return RefreshIndicator(
            onRefresh: provider.fetchAnnouncements,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: provider.announcements.length,
              itemBuilder: (context, index) {
                final ann = provider.announcements[index];
                
                Color iconColor = AppTheme.primaryBlue;
                if (ann['severity'] == 'warning') iconColor = Colors.orange;
                if (ann['severity'] == 'critical') iconColor = AppTheme.sosRed;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: iconColor.withOpacity(0.3))),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: iconColor.withOpacity(0.1), shape: BoxShape.circle),
                              child: Icon(Icons.campaign, color: iconColor),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(ann['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  Text(timeago.format(DateTime.parse(ann['created_at'])), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                ],
                              )
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(ann['message'], style: const TextStyle(fontSize: 14)),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text('By: ${ann['profiles']?['full_name'] ?? 'Admin'}', style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                        )
                      ],
                    ),
                  ),
                ).animate().fade(duration: 400.ms).slideY(begin: 0.1, delay: (index * 50).ms);
              },
            ),
          );
        },
      ),
    );
  }
}
