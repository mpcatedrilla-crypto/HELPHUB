import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/report_provider.dart';
import '../models/report_status.dart';
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
              .where(
                (r) =>
                    ReportStatus.fromDatabase(r['status']).isCompleted ||
                    ReportStatus.fromDatabase(r['status']) ==
                        ReportStatus.archived,
              )
              .toList();

          if (historyReports.isEmpty) {
            return const Center(child: Text('No historical reports found.'));
          }

          return ListView.builder(
            itemCount: historyReports.length,
            itemBuilder: (context, index) {
              final r = historyReports[index];
              final status = ReportStatus.fromDatabase(r['status']);
              final statusColor = switch (status) {
                ReportStatus.resolved => AppTheme.statusResolved,
                ReportStatus.referred => AppTheme.statusReferred,
                ReportStatus.falseAlarm => AppTheme.statusHigh,
                ReportStatus.closed ||
                ReportStatus.archived => AppTheme.textSecondary,
                _ => AppTheme.statusMedium,
              };
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: statusColor,
                  child: Icon(
                    status == ReportStatus.archived
                        ? Icons.archive_rounded
                        : status == ReportStatus.resolved
                        ? Icons.check
                        : Icons.close,
                    color: Colors.white,
                  ),
                ),
                title: Text(
                  r['title'] ?? 'No Title',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'Status: ${status.label}\n${timeago.format(DateTime.parse(r['created_at']))}',
                ),
                isThreeLine: true,
              );
            },
          );
        },
      ),
    );
  }
}
