import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'theme/app_theme.dart';
import 'screens/resident_dashboard.dart';
import 'screens/emergency_sos_screen.dart';
import 'screens/concern_reporting_form.dart';
import 'screens/report_tracking.dart';
import 'screens/admin_priority_queue.dart';
import 'screens/admin_verification_screen.dart';
import 'screens/admin_announcements_screen.dart';
import 'screens/audit_log_screen.dart';

import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'providers/report_provider.dart';
import 'providers/admin_provider.dart';
import 'screens/modern_login_screen.dart';
import 'screens/landing_screen.dart';
import 'screens/profile_screen.dart';

import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import 'env.dart';
import 'firebase_options.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await Supabase.initialize(
    url: Env.supabaseUrl,
    publishableKey: Env.supabaseAnonKey,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ReportProvider()),
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

class HelpHubApp extends StatelessWidget {
  const HelpHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HelpHub',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (context) => const LandingScreen(),
        '/login': (context) => const ModernLoginScreen(),
        '/resident_home': (context) => const ResidentDashboard(),
        '/emergency_sos': (context) => const EmergencySOSScreen(),
        '/report_concern': (context) => const ConcernReportingForm(),
        '/report_tracking': (context) => const ReportTracking(),
        '/admin_queue': (context) => const AdminPriorityQueue(),
        '/profile': (context) => ProfileScreen(),
        '/admin_verification': (context) => const AdminVerificationScreen(),
        '/admin_announcements': (context) => const AdminAnnouncementsScreen(),
        '/admin_audit_logs': (context) => const AuditLogScreen(),
      },
    );
  }
}
