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
    bool isLoading = false;

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
                decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: messageCtrl,
                decoration: const InputDecoration(labelText: 'Message', border: OutlineInputBorder()),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: severity,
                decoration: const InputDecoration(labelText: 'Severity', border: OutlineInputBorder()),
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
            TextButton(onPressed: isLoading ? null : () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: isLoading ? null : () async {
                if (titleCtrl.text.isNotEmpty && messageCtrl.text.isNotEmpty) {
                  setState(() => isLoading = true);
                  final success = await provider.createAnnouncement(titleCtrl.text, messageCtrl.text, severity);
                  if (context.mounted) {
                    Navigator.pop(ctx);
                    if (success) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Broadcast sent!')));
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to broadcast. Did you run the SQL script?')));
                    }
                  }
                }
              },
              child: isLoading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                : const Text('Broadcast'),
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
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.campaign, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  const Text('No active broadcasts', style: TextStyle(color: Colors.grey, fontSize: 18)),
                  const SizedBox(height: 8),
                  const Text('Create one to notify all residents.', style: TextStyle(color: Colors.grey, fontSize: 14)),
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
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.grey),
                              onPressed: () async {
                                final success = await provider.deleteAnnouncement(ann['id'].toString());
                                if (success && context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Broadcast removed')));
                                }
                              },
                            )
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
