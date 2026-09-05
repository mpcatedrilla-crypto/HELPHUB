import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:audioplayers/audioplayers.dart';

class AdminProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client;
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final AudioPlayer _audioPlayer = AudioPlayer();
  RealtimeChannel? _reportsSubscription;
  StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;
  StreamSubscription<RemoteMessage>? _openedMessageSubscription;
  StreamSubscription<String>? _tokenRefreshSubscription;
  VoidCallback? _onNewEmergency;
  bool _isAdminSessionActive = false;
  bool _notificationsInitialized = false;
  bool _remotePushInitialized = false;
  final Map<String, DateTime> _recentAlertIds = {};

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  AdminProvider();

  void setAdminSessionActive(bool isActive) {
    if (_isAdminSessionActive == isActive) return;
    _isAdminSessionActive = isActive;

    if (isActive) {
      _initNotifications();
      _initRemotePush();
      _ensureEmergencySubscription();
    } else {
      _onNewEmergency = null;
      _cancelEmergencySubscription();
      _disposeRemotePushListeners();
      _audioPlayer.stop();
    }
  }

  Future<void> _initNotifications() async {
    if (_notificationsInitialized) return;
    _notificationsInitialized = true;
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const initSettings = InitializationSettings(android: androidSettings);
    await _notificationsPlugin.initialize(settings: initSettings);

    // Create a high-importance notification channel explicitly (Android 8+)
    const channel = AndroidNotificationChannel(
      'emergency_sos_v4',
      'SOS Emergency Alerts',
      description: 'Critical alerts for incoming SOS emergencies',
      importance: Importance.max,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('siren'),
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

  Future<void> _initRemotePush() async {
    if (_remotePushInitialized) return;
    _remotePushInitialized = true;

    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.setAutoInitEnabled(true);
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        criticalAlert: true,
      );

      final token = await messaging.getToken();
      if (token != null) await _savePushToken(token);

      _tokenRefreshSubscription = messaging.onTokenRefresh.listen(
        _savePushToken,
      );
      _foregroundMessageSubscription = FirebaseMessaging.onMessage.listen(
        _handleRemoteEmergency,
      );
      _openedMessageSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
        (_) => _onNewEmergency?.call(),
      );

      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) _onNewEmergency?.call();
    } catch (error) {
      debugPrint('Unable to initialize emergency push notifications: $error');
      _remotePushInitialized = false;
    }
  }

  Future<void> _savePushToken(String token) async {
    final user = _supabase.auth.currentUser;
    if (!_isAdminSessionActive || user == null) return;

    try {
      await _supabase.from('admin_push_tokens').upsert({
        'token': token,
        'user_id': user.id,
        'platform': 'android',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'token');
    } catch (error) {
      debugPrint('Unable to register this device for SOS alerts: $error');
    }
  }

  void _handleRemoteEmergency(RemoteMessage message) {
    if (!_isAdminSessionActive) return;
    final type = message.data['type']?.toString();
    if (type != null && type != 'critical_sos') return;

    final reportId = message.data['report_id']?.toString();
    final title =
        message.data['report_title']?.toString() ??
        message.notification?.body ??
        'Emergency SOS';
    final reporter = message.data['reporter_name']?.toString() ?? 'A resident';
    _triggerSirenAlert(title, reporter, alertId: reportId);
    _onNewEmergency?.call();
  }

  void _disposeRemotePushListeners() {
    _foregroundMessageSubscription?.cancel();
    _openedMessageSubscription?.cancel();
    _tokenRefreshSubscription?.cancel();
    _foregroundMessageSubscription = null;
    _openedMessageSubscription = null;
    _tokenRefreshSubscription = null;
    _remotePushInitialized = false;
  }

  void startListeningForEmergencies(VoidCallback onNewEmergency) {
    _onNewEmergency = onNewEmergency;
    _ensureEmergencySubscription();
  }

  void _ensureEmergencySubscription() {
    if (!_isAdminSessionActive || _reportsSubscription != null) return;
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
                alertId: newReport['id']?.toString(),
              );
              _onNewEmergency?.call();
            }
          },
        )
        .subscribe();
  }

  void stopListeningForEmergencies() {
    _onNewEmergency = null;
    if (!_isAdminSessionActive) {
      _cancelEmergencySubscription();
    }
  }

  void _cancelEmergencySubscription() {
    _reportsSubscription?.unsubscribe();
    _reportsSubscription = null;
  }

  @override
  void dispose() {
    _cancelEmergencySubscription();
    _disposeRemotePushListeners();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _triggerSirenAlert(
    String title,
    String reporterName, {
    String? alertId,
  }) async {
    if (alertId != null) {
      final now = DateTime.now();
      _recentAlertIds.removeWhere(
        (_, timestamp) =>
            now.difference(timestamp) > const Duration(minutes: 2),
      );
      if (_recentAlertIds.containsKey(alertId)) return;
      _recentAlertIds[alertId] = now;
    }

    // 1. Play siren sound using audioplayers
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource('sounds/siren.wav'));
    } catch (_) {}

    // 2. Show heads-up notification
    final androidDetails = AndroidNotificationDetails(
      'emergency_sos_v4',
      'SOS Emergency Alerts',
      channelDescription: 'Critical alerts for incoming SOS emergencies',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      sound: const RawResourceAndroidNotificationSound('siren'),
      enableVibration: true,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
      vibrationPattern: Int64List.fromList([0, 500, 200, 500, 200, 500]),
    );
    final details = NotificationDetails(android: androidDetails);

    await _notificationsPlugin.show(
      id:
          alertId?.hashCode ??
          DateTime.now().millisecondsSinceEpoch.remainder(1 << 31),
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
