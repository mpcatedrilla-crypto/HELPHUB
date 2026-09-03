import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/admin_provider.dart';
import '../theme/app_theme.dart';
import 'admin_drawer.dart';
import 'package:timeago/timeago.dart' as timeago;

class AdminAnnouncementsScreen extends StatefulWidget {
  const AdminAnnouncementsScreen({super.key});

  @override
  State<AdminAnnouncementsScreen> createState() => _AdminAnnouncementsScreenState();
}

class _AdminAnnouncementsScreenState extends State<AdminAnnouncementsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AdminProvider>(context, listen: false).fetchAnnouncements();
    });
  }

  void _showCreateDialog(BuildContext context, AdminProvider provider) {
    final titleCtrl = TextEditingController();
    final messageCtrl = TextEditingController();
    String severity = 'info';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('New Broadcast'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: messageCtrl,
                decoration: const InputDecoration(labelText: 'Message'),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: severity,
                decoration: const InputDecoration(labelText: 'Severity'),
                items: const [
                  DropdownMenuItem(value: 'info', child: Text('Info (Blue)')),
                  DropdownMenuItem(value: 'warning', child: Text('Warning (Orange)')),
                  DropdownMenuItem(value: 'critical', child: Text('Critical (Red)')),
                ],
                onChanged: (val) => setState(() => severity = val!),
              )
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (titleCtrl.text.isNotEmpty && messageCtrl.text.isNotEmpty) {
                  provider.createAnnouncement(titleCtrl.text, messageCtrl.text, severity);
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Broadcast'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Broadcast Alerts')),
      drawer: const AdminDrawer(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateDialog(context, Provider.of<AdminProvider>(context, listen: false)),
        icon: const Icon(Icons.campaign, color: Colors.white),
        label: const Text('New Broadcast', style: TextStyle(color: Colors.white)),
        backgroundColor: AppTheme.primaryBlue,
      ),
      body: Consumer<AdminProvider>(
        builder: (context, provider, child) {
          if (provider.announcements.isEmpty) {
            return const Center(child: Text('No announcements yet.'));
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
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.campaign, color: iconColor),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(ann['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            ),
                            Text(timeago.format(DateTime.parse(ann['created_at'])), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(ann['message']),
                        const SizedBox(height: 8),
                        Text('By: ${ann['profiles']?['full_name'] ?? 'Admin'}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
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
