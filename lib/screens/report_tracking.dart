import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/report_provider.dart';
import '../theme/app_theme.dart';

class ReportTracking extends StatelessWidget {
  const ReportTracking({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Reports'),
      ),
      body: Consumer<ReportProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.myReports.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (provider.myReports.isEmpty) {
            return const Center(child: Text('You have not submitted any reports yet.'));
          }
          
          return RefreshIndicator(
            onRefresh: provider.fetchMyReports,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: provider.myReports.length,
              itemBuilder: (context, index) {
                final report = provider.myReports[index];
                
                Color statusColor = AppTheme.statusMedium;
                if (report['status'] == 'submitted') statusColor = Colors.orange;
                if (report['status'] == 'resolved') statusColor = AppTheme.statusResolved;
                
                final categoryName = report['concern_types'] != null ? report['concern_types']['category_name'] : 'Unknown';
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    onTap: () => _showReportDetails(context, report, statusColor, categoryName),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  report['title'] ?? 'No Title',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  (report['status'] ?? 'Unknown').toString().toUpperCase(),
                                  style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 10),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(categoryName, style: const TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _showReportDetails(BuildContext context, Map<String, dynamic> report, Color statusColor, String categoryName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(report['title'] ?? 'No Title', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(categoryName, style: const TextStyle(color: Colors.grey)),
                  const Divider(height: 32),
                  const Text('Description', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(report['description'] ?? 'No description provided.'),
                  const Divider(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _DetailItem(label: 'Score', value: '${report['priority_score']}', isHighlight: true),
                      _DetailItem(label: 'Status', value: report['status']?.toString().toUpperCase() ?? 'N/A', color: statusColor),
                      _DetailItem(label: 'Urgency', value: '${report['resident_declared_urgency']}/5'),
                    ],
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _DetailItem extends StatelessWidget {
  final String label;
  final String value;
  final bool isHighlight;
  final Color? color;

  const _DetailItem({required this.label, required this.value, this.isHighlight = false, this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color ?? (isHighlight ? AppTheme.primaryBlue : Colors.black87),
          ),
        ),
      ],
    );
  }
}
