import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/report_provider.dart';
import '../theme/app_theme.dart';
import 'package:timeago/timeago.dart' as timeago;

class AdminHistoryScreen extends StatelessWidget {
  const AdminHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('History Reports'),
        backgroundColor: AppTheme.primaryBlue,
      ),
      body: Consumer<ReportProvider>(
        builder: (context, provider, child) {
          final historyReports = provider.allReports
              .where((r) => r['status'] == 'resolved' || r['status'] == 'rejected' || r['status'] == 'pending_confirmation')
              .toList();

          if (historyReports.isEmpty) {
            return const Center(child: Text('No historical reports found.'));
          }

          return ListView.builder(
            itemCount: historyReports.length,
            itemBuilder: (context, index) {
              final r = historyReports[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: r['status'] == 'resolved' ? AppTheme.statusResolved : 
                                  (r['status'] == 'pending_confirmation' ? Colors.orange : Colors.red),
                  child: Icon(
                    r['status'] == 'resolved' ? Icons.check : 
                    (r['status'] == 'pending_confirmation' ? Icons.hourglass_bottom : Icons.close),
                    color: Colors.white,
                  ),
                ),
                title: Text(r['title'] ?? 'No Title', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Status: ${(r['status'] ?? '').toUpperCase()}\n${timeago.format(DateTime.parse(r['created_at']))}'),
                isThreeLine: true,
              );
            },
          );
        },
      ),
    );
  }
}
