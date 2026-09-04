import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:audioplayers/audioplayers.dart';

class AdminProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client;
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final AudioPlayer _audioPlayer = AudioPlayer();
  RealtimeChannel? _reportsSubscription;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  AdminProvider() {
    _initNotifications();
  }

  Future<void> _initNotifications() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const initSettings = InitializationSettings(android: androidSettings);
    await _notificationsPlugin.initialize(settings: initSettings);

    // Create a high-importance notification channel explicitly (Android 8+)
    const channel = AndroidNotificationChannel(
      'emergency_sos_v3',
      'SOS Emergency Alerts',
      description: 'Critical alerts for incoming SOS emergencies',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    // Request notification permissions for Android 13+
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }

  void startListeningForEmergencies(VoidCallback onNewEmergency) {
    if (_reportsSubscription != null) return;

    _reportsSubscription = _supabase
        .channel('public:reports')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'reports',
          callback: (payload) {
            final newReport = payload.newRecord;
            if (newReport['is_critical_override'] == true) {
              _triggerSirenAlert(
                newReport['title'] ?? 'Emergency SOS',
                newReport['profiles']?['full_name'] ?? 'A resident',
              );
              onNewEmergency();
            }
          },
        )
        .subscribe();
  }

  void stopListeningForEmergencies() {
    _reportsSubscription?.unsubscribe();
    _reportsSubscription = null;
  }

  Future<void> _triggerSirenAlert(String title, String reporterName) async {
    // 1. Play siren sound using audioplayers
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource('sounds/siren.wav'));
    } catch (_) {}

    // 2. Show heads-up notification
    final androidDetails = AndroidNotificationDetails(
      'emergency_sos_v3',
      'SOS Emergency Alerts',
      channelDescription: 'Critical alerts for incoming SOS emergencies',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
      vibrationPattern: Int64List.fromList([0, 500, 200, 500, 200, 500]),
    );
    final details = NotificationDetails(android: androidDetails);

    await _notificationsPlugin.show(
      id: 0,
      title: '🚨 CRITICAL SOS ALERT',
      body: '$reporterName has reported an emergency: $title',
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

  Future<bool> reviewResident(String profileId, String status) async {
    try {
      final response = await _supabase
          .from('profiles')
          .update({'status': status})
          .eq('id', profileId)
          .select();

      if (response.isEmpty) {
        throw Exception(
          'Database blocked the update. Did you run the SQL script?',
        );
      }

      // Log audit
      try {
        await _supabase.from('audit_events').insert({
          'actor_id': _supabase.auth.currentUser!.id,
          'action': 'REVIEW_RESIDENT',
          'target_table': 'profiles',
          'target_id': profileId,
          'changes': {'new_status': status},
        });
      } catch (_) {}

      await fetchPendingResidents();
      return true;
    } catch (e) {
      debugPrint('Error reviewing resident: $e');
      return false;
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

  Future<void> assignReportDestination(
    String reportId,
    String destinationId,
  ) async {
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
        'changes': {'routing_destination_id': destinationId},
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

  Future<bool> createAnnouncement(
    String title,
    String message,
    String severity,
  ) async {
    try {
      final insertedAnnouncement = await _supabase
          .from('announcements')
          .insert({
            'title': title,
            'message': message,
            'severity': severity,
            'created_by': _supabase.auth.currentUser!.id,
          })
          .select('id')
          .single();
      final announcementId = insertedAnnouncement['id'] as String;

      try {
        await _supabase.from('audit_events').insert({
          'actor_id': _supabase.auth.currentUser!.id,
          'action': 'CREATE_ANNOUNCEMENT',
          'target_table': 'announcements',
          'target_id': announcementId,
          'changes': {'title': title, 'severity': severity},
        });
      } catch (e) {
        debugPrint('Announcement created, but audit logging failed: $e');
      }

      await fetchAnnouncements();
      return true;
    } catch (e) {
      debugPrint('Error creating announcement: $e');
      return false;
    }
  }

  Future<bool> deleteAnnouncement(String id) async {
    try {
      await _supabase.from('announcements').delete().eq('id', id);
      await fetchAnnouncements();
      return true;
    } catch (e) {
      debugPrint('Error deleting announcement: $e');
      return false;
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
