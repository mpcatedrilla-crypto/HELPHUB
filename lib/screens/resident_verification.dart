import 'package:flutter/material.dart';

class ResidentVerification extends StatefulWidget {
  const ResidentVerification({super.key});

  @override
  State<ResidentVerification> createState() => _ResidentVerificationState();
}

class _ResidentVerificationState extends State<ResidentVerification> {
  // Flow 2: Resident Verification & Approval
  bool _isLoading = false;

  void _submitDecision(String name, bool isApproved) async {
    setState(() => _isLoading = true);
    // Simulate Backend System: Process Verification Decision
    await Future.delayed(const Duration(seconds: 1));
    setState(() => _isLoading = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Account Access State updated: ${isApproved ? 'Approved' : 'Denied'} for $name')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verification Queue')),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildVerificationCard('Maria Santos', 'Brgy. ID Valid'),
            _buildVerificationCard('Roberto Lim', 'Utility Bill attached'),
          ],
        ),
    );
  }

  Widget _buildVerificationCard(String name, String docs) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(docs),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.check_circle, color: Colors.green),
              onPressed: () => _submitDecision(name, true),
            ),
            IconButton(
              icon: const Icon(Icons.cancel, color: Colors.red),
              onPressed: () => _submitDecision(name, false),
            ),
          ],
        ),
      ),
    );
  }
}
