import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'theme/app_theme.dart';
import 'screens/modern_resident_dashboard.dart';
import 'screens/modern_emergency_sos.dart';
import 'screens/modern_concern_reporting_form.dart';
import 'screens/modern_report_tracking.dart';
import 'screens/admin_priority_queue.dart';
import 'screens/admin_verification_screen.dart';
import 'screens/admin_announcements_screen.dart';
import 'screens/audit_log_screen.dart';
import 'screens/admin_profile_screen.dart';

import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'providers/report_provider.dart';
import 'providers/admin_provider.dart';
import 'providers/profile_provider.dart';
import 'screens/modern_login_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/password_recovery_screen.dart';
import 'widgets/verified_resident_gate.dart';

import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import 'env.dart';
import 'firebase_options.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Future.wait([
    Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform),
    supabase.Supabase.initialize(
      url: Env.supabaseUrl,
      publishableKey: Env.supabaseAnonKey,
    ),
  ]);
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ReportProvider()),
        ChangeNotifierProvider(create: (_) => ProfileProvider()),
        ChangeNotifierProxyProvider<AuthProvider, AdminProvider>(
          create: (_) => AdminProvider(),
          update: (_, auth, admin) {
            final provider = admin ?? AdminProvider();
            provider.setAdminSessionActive(
              auth.state == AuthState.authenticated &&
                  auth.role == UserRole.admin,
            );
            return provider;
          },
        ),
      ],
      child: const HelpHubApp(),
    ),
  );
}

class HelpHubApp extends StatefulWidget {
  const HelpHubApp({super.key});

  @override
  State<HelpHubApp> createState() => _HelpHubAppState();
}

class _HelpHubAppState extends State<HelpHubApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<supabase.AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _authSubscription = supabase.Supabase.instance.client.auth.onAuthStateChange
        .listen((authState) {
          if (authState.event != supabase.AuthChangeEvent.passwordRecovery) {
            return;
          }
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _navigatorKey.currentState?.pushAndRemoveUntil(
              MaterialPageRoute<void>(
                builder: (_) => const ResetPasswordScreen(),
              ),
              (_) => false,
            );
          });
        });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'HelpHub',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (context) => const ModernLoginScreen(),
        '/login': (context) => const ModernLoginScreen(),
        '/forgot-password': (context) => const ForgotPasswordScreen(),
        '/resident_home': (context) => const ModernResidentDashboard(),
        '/emergency_sos': (context) => const VerifiedResidentGate(
          featureName: 'Emergency SOS',
          child: ModernEmergencySos(),
        ),
        '/report_concern': (context) => const VerifiedResidentGate(
          featureName: 'Report Concern',
          child: ModernConcernReportingForm(),
        ),
        '/report_tracking': (context) => const VerifiedResidentGate(
          featureName: 'My Reports',
          child: ModernReportTracking(),
        ),
        '/admin_queue': (context) => const AdminPriorityQueue(),
        '/admin_profile': (context) => const AdminProfileScreen(),
        '/profile': (context) => ProfileScreen(),
        '/admin_verification': (context) => const AdminVerificationScreen(),
        '/admin_announcements': (context) => const AdminAnnouncementsScreen(),
        '/admin_audit_logs': (context) => const AuditLogScreen(),
      },
    );
  }
}
