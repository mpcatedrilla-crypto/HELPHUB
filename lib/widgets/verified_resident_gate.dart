import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/profile_provider.dart';
import '../screens/modern_resident_announcements.dart';

class VerifiedResidentGate extends StatefulWidget {
  const VerifiedResidentGate({
    super.key,
    required this.featureName,
    required this.child,
  });

  final String featureName;
  final Widget child;

  @override
  State<VerifiedResidentGate> createState() => _VerifiedResidentGateState();
}

class _VerifiedResidentGateState extends State<VerifiedResidentGate> {
  bool _requestedProfile = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final profile = context.read<ProfileProvider>();
    if (!_requestedProfile && !profile.hasLoadedCurrentUser) {
      _requestedProfile = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.read<ProfileProvider>().loadProfile();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>();
    if (!profile.hasLoadedCurrentUser || profile.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (profile.isVerified) return widget.child;

    return _VerificationRequired(featureName: widget.featureName);
  }
}

class _VerificationRequired extends StatelessWidget {
  const _VerificationRequired({required this.featureName});

  final String featureName;

  static const _blue = Color(0xFF075EB8);
  static const _cyan = Color(0xFF55D8DD);
  static const _purple = Color(0xFF2400B8);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(featureName),
        foregroundColor: Colors.white,
        backgroundColor: _blue,
      ),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE9FBFC), Colors.white, Color(0xFFEAF3FF)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(24, 30, 24, 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: _purple.withValues(alpha: .18)),
                    boxShadow: [
                      BoxShadow(
                        color: _blue.withValues(alpha: .12),
                        blurRadius: 28,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 76,
                        height: 76,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(colors: [_cyan, _blue]),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.verified_user_outlined,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Account verification required',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '$featureName is available only to verified residents. '
                        'Open your profile to submit or check your verification request.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          height: 1.45,
                          fontSize: 14,
                          color: Color(0xFF5E6675),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () =>
                              Navigator.pushNamed(context, '/profile'),
                          style: FilledButton.styleFrom(
                            backgroundColor: _purple,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          icon: const Icon(Icons.person_outline_rounded),
                          label: const Text('View My Profile'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const ModernResidentAnnouncements(),
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _purple,
                            side: const BorderSide(color: _purple),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          icon: const Icon(Icons.campaign_outlined),
                          label: const Text('View Announcements'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
