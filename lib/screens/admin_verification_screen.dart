import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../providers/admin_provider.dart';
import '../theme/app_theme.dart';
import 'admin_drawer.dart';

class AdminVerificationScreen extends StatefulWidget {
  const AdminVerificationScreen({super.key});

  @override
  State<AdminVerificationScreen> createState() =>
      _AdminVerificationScreenState();
}

class _AdminVerificationScreenState extends State<AdminVerificationScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AdminProvider>(
        context,
        listen: false,
      ).fetchPendingResidents();
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
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Text(
                  provider.verificationError ?? 'No pending verifications!',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey, fontSize: 16),
                ),
              ),
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
                        onTap: () async {
                          final id = _text(resident['id']);
                          final latest = id.isEmpty
                              ? null
                              : await provider.fetchResidentDetails(id);
                          if (!context.mounted) return;
                          _showResidentDetails(
                            context,
                            provider,
                            latest ?? resident,
                          );
                        },
                        leading: _ResidentAvatar(
                          avatarUrl: _text(resident['avatar_url']),
                          radius: 22,
                        ),
                        title: Text(
                          resident['full_name'] ?? 'Unknown Resident',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          _text(resident['address']).isEmpty
                              ? 'Tap to review profile information'
                              : _text(resident['address']),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                      ),
                    )
                    .animate()
                    .fade(duration: 300.ms)
                    .slideX(begin: 0.1, delay: (index * 50).ms);
              },
            ),
          );
        },
      ),
    );
  }

  String _text(dynamic value) => value?.toString().trim() ?? '';

  Future<void> _showResidentDetails(
    BuildContext context,
    AdminProvider provider,
    Map<String, dynamic> resident,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _ResidentReviewSheet(
        resident: resident,
        onApprove: () {
          Navigator.pop(sheetContext);
          _confirmAction(
            context,
            provider,
            resident['id'].toString(),
            'approved',
          );
        },
        onReject: () {
          Navigator.pop(sheetContext);
          _confirmAction(
            context,
            provider,
            resident['id'].toString(),
            'rejected',
          );
        },
      ),
    );
  }

  void _confirmAction(
    BuildContext context,
    AdminProvider provider,
    String id,
    String status,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Confirm ${status.toUpperCase()}'),
        content: Text('Are you sure you want to $status this account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: status == 'approved'
                  ? AppTheme.statusResolved
                  : AppTheme.sosRed,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await provider.reviewResident(id, status);
              if (context.mounted) {
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Resident $status successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Failed to update. Did you run the SQL script?',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }
}

class _ResidentReviewSheet extends StatelessWidget {
  const _ResidentReviewSheet({
    required this.resident,
    required this.onApprove,
    required this.onReject,
  });

  final Map<String, dynamic> resident;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  String _text(dynamic value, [String fallback = 'Not provided']) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  String _date(dynamic value) {
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) return 'Not provided';
    final parsed = DateTime.tryParse(raw)?.toLocal();
    if (parsed == null) return raw;
    final month = parsed.month.toString().padLeft(2, '0');
    final day = parsed.day.toString().padLeft(2, '0');
    return '${parsed.year}-$month-$day';
  }

  @override
  Widget build(BuildContext context) {
    final name = _text(resident['full_name'], 'Unnamed resident');
    final avatar = _text(resident['avatar_url'], '');
    final nameParts = name.split(RegExp(r'\s+'));
    final derivedFirstName = nameParts.isEmpty ? '' : nameParts.first;
    final derivedLastName = nameParts.length < 2 ? '' : nameParts.last;
    final derivedMiddleName = nameParts.length < 3
        ? ''
        : nameParts.sublist(1, nameParts.length - 1).join(' ');
    return DraggableScrollableSheet(
      initialChildSize: .9,
      minChildSize: .65,
      maxChildSize: .97,
      expand: false,
      builder: (context, controller) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF5F8FC),
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                children: [
                  const Text(
                    'Verification Application',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Review the resident’s submitted information before deciding.',
                    style: TextStyle(color: Colors.black54, fontSize: 13),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2400B8), Color(0xFF075EB8)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        _ResidentAvatar(avatarUrl: avatar, radius: 34),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 5),
                              const Text(
                                'Resident • Pending verification',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _ReviewSection(
                    title: 'Personal Information',
                    icon: Icons.badge_outlined,
                    rows: [
                      (
                        'First name',
                        _text(resident['first_name'], derivedFirstName),
                      ),
                      (
                        'Middle name',
                        _text(resident['middle_name'], derivedMiddleName),
                      ),
                      (
                        'Last name',
                        _text(resident['last_name'], derivedLastName),
                      ),
                      ('Age', _text(resident['age'])),
                      ('Birthday', _date(resident['birthday'])),
                      ('Gender', _text(resident['gender'])),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _ReviewSection(
                    title: 'Contact Information',
                    icon: Icons.contact_phone_outlined,
                    rows: [
                      ('Email', _text(resident['email'])),
                      ('Phone', _text(resident['phone'])),
                      ('Address', _text(resident['address'])),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _ReviewSection(
                    title: 'Application Information',
                    icon: Icons.fact_check_outlined,
                    rows: [
                      (
                        'Status',
                        _text(resident['status'], 'pending').toUpperCase(),
                      ),
                      (
                        'Submitted',
                        _date(
                          resident['verification_requested_at'] ??
                              resident['created_at'],
                        ),
                      ),
                      ('Resident ID', _text(resident['id'])),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x18000000),
                    blurRadius: 18,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onReject,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.sosRed,
                        side: const BorderSide(color: AppTheme.sosRed),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onApprove,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.statusResolved,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Approve'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResidentAvatar extends StatelessWidget {
  const _ResidentAvatar({required this.avatarUrl, required this.radius});

  final String avatarUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: Container(
        width: radius * 2,
        height: radius * 2,
        color: const Color(0xFFE7E9EF),
        child: avatarUrl.isEmpty
            ? Image.asset(
                'assets/images/default_resident_avatar.png',
                fit: BoxFit.cover,
              )
            : Image.network(
                avatarUrl,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) => progress == null
                    ? child
                    : const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                errorBuilder: (_, _, _) => Image.asset(
                  'assets/images/default_resident_avatar.png',
                  fit: BoxFit.cover,
                ),
              ),
      ),
    );
  }
}

class _ReviewSection extends StatelessWidget {
  const _ReviewSection({
    required this.title,
    required this.icon,
    required this.rows,
  });

  final String title;
  final IconData icon;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFDDE5EF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF075EB8), size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          ...rows.map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 100,
                    child: Text(
                      row.$1,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      row.$2,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
