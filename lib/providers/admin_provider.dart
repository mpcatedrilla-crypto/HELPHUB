import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class AdminProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client;
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  RealtimeChannel? _reportsSubscription;
  
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  AdminProvider() {
    _initNotifications();
  }

  Future<void> _initNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _notificationsPlugin.initialize(settings: initSettings);

    // Request notification permissions for Android 13+
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  void startListeningForEmergencies(VoidCallback onNewEmergency) {
    if (_reportsSubscription != null) return;

    _reportsSubscription = _supabase.channel('public:reports').onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'reports',
      callback: (payload) {
        final newReport = payload.newRecord;
        if (newReport['is_critical_override'] == true) {
          _triggerSirenAlert(newReport['title'] ?? 'Emergency SOS');
          onNewEmergency();
        }
      },
    ).subscribe();
  }

  void stopListeningForEmergencies() {
    _reportsSubscription?.unsubscribe();
    _reportsSubscription = null;
  }

  Future<void> _triggerSirenAlert(String title) async {
    const androidDetails = AndroidNotificationDetails(
      'emergency_sos_channel_v2', // Changed ID to bypass Android channel caching
      'Critical Emergency Alerts',
      channelDescription: 'Loud alerts for incoming SOS emergencies',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      fullScreenIntent: true,
    );
    const details = NotificationDetails(android: androidDetails);
    
    await _notificationsPlugin.show(
      id: 0,
      title: 'CRITICAL SOS ALERT',
      body: 'An emergency was just reported: $title',
      notificationDetails: details,
    );
  }
  List<Map<String, dynamic>> _pendingResidents = [];
  List<Map<String, dynamic>> get pendingResidents => _pendingResidents;

  List<Map<String, dynamic>> _announcements = [];
  List<Map<String, dynamic>> get announcements => _announcements;

  List<Map<String, dynamic>> _routingDestinations = [];
  List<Map<String, dynamic>> get routingDestinations => _routingDestinations;

  List<Map<String, dynamic>> _auditLogs = [];
  List<Map<String, dynamic>> get auditLogs => _auditLogs;

  Future<void> fetchPendingResidents() async {
    _isLoading = true;
    notifyListeners();
    try {
      final res = await _supabase
          .from('profiles')
          .select()
          .eq('status', 'pending');
      _pendingResidents = List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('Error fetching residents: $e');
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> reviewResident(String profileId, String status) async {
    try {
      await _supabase
          .from('profiles')
          .update({'status': status})
          .eq('id', profileId);
      
      // Log audit
      await _supabase.from('audit_events').insert({
        'actor_id': _supabase.auth.currentUser!.id,
        'action': 'REVIEW_RESIDENT',
        'target_table': 'profiles',
        'target_id': profileId,
        'changes': {'new_status': status}
      });
      
      await fetchPendingResidents();
    } catch (e) {
      debugPrint('Error reviewing resident: $e');
    }
  }

  Future<void> fetchRoutingDestinations() async {
    try {
      final res = await _supabase.from('routing_destinations').select();
      _routingDestinations = List<Map<String, dynamic>>.from(res);
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching destinations: $e');
    }
  }

  Future<void> assignReportDestination(String reportId, String destinationId) async {
    try {
      await _supabase
          .from('reports')
          .update({'routing_destination_id': destinationId})
          .eq('id', reportId);
          
      await _supabase.from('audit_events').insert({
        'actor_id': _supabase.auth.currentUser!.id,
        'action': 'DISPATCH_REPORT',
        'target_table': 'reports',
        'target_id': reportId,
        'changes': {'routing_destination_id': destinationId}
      });
    } catch (e) {
      debugPrint('Error dispatching: $e');
    }
  }

  Future<void> fetchAnnouncements() async {
    try {
      final res = await _supabase
          .from('announcements')
          .select('*, profiles(full_name)')
          .order('created_at', ascending: false);
      _announcements = List<Map<String, dynamic>>.from(res);
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching announcements: $e');
    }
  }

  Future<void> createAnnouncement(String title, String message, String severity) async {
    try {
      await _supabase.from('announcements').insert({
        'title': title,
        'message': message,
        'severity': severity,
        'created_by': _supabase.auth.currentUser!.id
      });
      await fetchAnnouncements();
    } catch (e) {
      debugPrint('Error creating announcement: $e');
    }
  }

  Future<void> fetchAuditLogs() async {
    _isLoading = true;
    notifyListeners();
    try {
      final res = await _supabase
          .from('audit_events')
          .select('*, profiles(full_name)')
          .order('created_at', ascending: false)
          .limit(50);
      _auditLogs = List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('Error fetching audits: $e');
    }
    _isLoading = false;
    notifyListeners();
  }
}
