import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/admin_provider.dart';
import 'admin_drawer.dart';
import 'package:timeago/timeago.dart' as timeago;

class AuditLogScreen extends StatefulWidget {
  const AuditLogScreen({super.key});

  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AdminProvider>(context, listen: false).fetchAuditLogs();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Audit Logs (Immutable)')),
      drawer: const AdminDrawer(),
      body: Consumer<AdminProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.auditLogs.isEmpty) {
            return const Center(child: Text('No audit events found.'));
          }

        return RefreshIndicator(
          onRefresh: provider.fetchAuditLogs,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.auditLogs.length,
            itemBuilder: (context, index) {
              final log = provider.auditLogs[index];
              final action = log['action'].toString();
              
              IconData icon = Icons.history;
              Color iconColor = Colors.grey;
              
              if (action.contains('RESOLVE') || action.contains('ACKNOWLEDGE') || action.contains('STATUS')) {
                icon = Icons.check_circle;
                iconColor = Colors.green;
              } else if (action.contains('REVIEW')) {
                icon = Icons.verified_user;
                iconColor = Colors.blue;
              } else if (action.contains('CREATE') || action.contains('INSERT')) {
                icon = Icons.add_circle;
                iconColor = Colors.orange;
              }

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: iconColor.withOpacity(0.1), shape: BoxShape.circle),
                        child: Icon(icon, color: iconColor),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(action.replaceAll('_', ' '), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                Text(timeago.format(DateTime.parse(log['created_at'])), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text('By: ${log['profiles']?['full_name'] ?? 'System'}', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                            Text('Target: ${log['target_table']} (ID: ${log['target_id'].toString().substring(0,8)})', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(4)),
                              child: Text(log['changes'].toString(), style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Colors.black87)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ).animate().fade().slideX(begin: 0.1, delay: (index * 20).ms);
            },
          ),
        );
        },
      ),
    );
  }
}
