import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/admin_provider.dart';
import '../theme/app_theme.dart';
import 'admin_drawer.dart';

class AdminVerificationScreen extends StatefulWidget {
  const AdminVerificationScreen({super.key});

  @override
  State<AdminVerificationScreen> createState() => _AdminVerificationScreenState();
}

class _AdminVerificationScreenState extends State<AdminVerificationScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AdminProvider>(context, listen: false).fetchPendingResidents();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pending Verifications')),
      drawer: const AdminDrawer(),
      body: Consumer<AdminProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.pendingResidents.isEmpty) {
            return const Center(
              child: Text('No pending verifications!', style: TextStyle(color: Colors.grey, fontSize: 16)),
            ).animate().fade().scale();
          }

          return RefreshIndicator(
            onRefresh: provider.fetchPendingResidents,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: provider.pendingResidents.length,
              itemBuilder: (context, index) {
                final resident = provider.pendingResidents[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: AppTheme.primaryBlue,
                      child: Icon(Icons.person, color: Colors.white),
                    ),
                    title: Text(resident['full_name'] ?? 'Unknown Resident', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('ID: ${resident['id'].toString().substring(0, 8)}...'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.check_circle, color: AppTheme.statusResolved),
                          onPressed: () => _confirmAction(context, provider, resident['id'], 'approved'),
                        ),
                        IconButton(
                          icon: const Icon(Icons.cancel, color: AppTheme.sosRed),
                          onPressed: () => _confirmAction(context, provider, resident['id'], 'rejected'),
                        ),
                      ],
                    ),
                  ),
                ).animate().fade(duration: 300.ms).slideX(begin: 0.1, delay: (index * 50).ms);
              },
            ),
          );
        },
      ),
    );
  }

  void _confirmAction(BuildContext context, AdminProvider provider, String id, String status) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Confirm ${status.toUpperCase()}'),
        content: Text('Are you sure you want to $status this account?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: status == 'approved' ? AppTheme.statusResolved : AppTheme.sosRed),
            onPressed: () {
              provider.reviewResident(id, status);
              Navigator.pop(ctx);
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }
}
