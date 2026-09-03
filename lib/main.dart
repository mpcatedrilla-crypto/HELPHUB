import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/resident_dashboard.dart';
import 'screens/emergency_sos_screen.dart';
import 'screens/concern_reporting_form.dart';
import 'screens/report_tracking.dart';
import 'screens/admin_priority_queue.dart';

import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/report_provider.dart';
import 'screens/login_screen.dart';
import 'screens/profile_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'env.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: Env.supabaseUrl,
    anonKey: Env.supabaseAnonKey,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ReportProvider()),
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
        '/': (context) => const LoginScreen(),
        '/resident_home': (context) => const ResidentDashboard(),
        '/emergency_sos': (context) => const EmergencySOSScreen(),
        '/report_concern': (context) => const ConcernReportingForm(),
        '/report_tracking': (context) => const ReportTracking(),
        '/admin_queue': (context) => const AdminPriorityQueue(),
        '/profile': (context) => ProfileScreen(),
      },
    );
  }
}
