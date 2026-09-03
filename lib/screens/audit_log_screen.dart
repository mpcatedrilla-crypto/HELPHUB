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
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(Icons.history, color: Colors.grey),
                    title: Text(log['action'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('By: ${log['profiles']?['full_name'] ?? log['actor_id'].toString().substring(0,8)}'),
                        Text('Target: ${log['target_table']} (${log['target_id'].toString().substring(0,8)})'),
                        Text(log['changes'].toString(), style: const TextStyle(fontSize: 10, fontFamily: 'monospace')),
                      ],
                    ),
                    trailing: Text(timeago.format(DateTime.parse(log['created_at'])), style: const TextStyle(fontSize: 10)),
                  ),
                ).animate().fade().slideX();
              },
            ),
          );
        },
      ),
    );
  }
}
