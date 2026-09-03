import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';

class AdminDrawer extends StatelessWidget {
  const AdminDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(color: AppTheme.primaryBlue),
            accountName: const Text('Administrator', style: TextStyle(fontWeight: FontWeight.bold)),
            accountEmail: Text(Provider.of<AuthProvider>(context, listen: false).userName ?? 'admin@helphub.com'),
            currentAccountPicture: const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.admin_panel_settings, color: AppTheme.primaryBlue, size: 36),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.local_police, color: AppTheme.primaryBlue),
            title: const Text('Priority Queue'),
            onTap: () => Navigator.pushReplacementNamed(context, '/admin_queue'),
          ),
          ListTile(
            leading: const Icon(Icons.how_to_reg, color: AppTheme.primaryBlue),
            title: const Text('Resident Verification'),
            onTap: () => Navigator.pushReplacementNamed(context, '/admin_verification'),
          ),
          ListTile(
            leading: const Icon(Icons.campaign, color: AppTheme.primaryBlue),
            title: const Text('Broadcast Alerts'),
            onTap: () => Navigator.pushReplacementNamed(context, '/admin_announcements'),
          ),
          ListTile(
            leading: const Icon(Icons.history, color: AppTheme.primaryBlue),
            title: const Text('Audit Logs'),
            onTap: () => Navigator.pushReplacementNamed(context, '/admin_audit_logs'),
          ),
          const Spacer(),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Logout', style: TextStyle(color: Colors.red)),
            onTap: () {
              Provider.of<AuthProvider>(context, listen: false).logout();
              Navigator.pushReplacementNamed(context, '/');
            },
          ),
        ],
      ),
    );
  }
}
